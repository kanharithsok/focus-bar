import XCTest
@testable import FocusBar

final class HostsHostnameValidatorTests: XCTestCase {
    func testAcceptsNormalHostnames() {
        XCTAssertEqual(HostsHostnameValidator.sanitize("example.com"), "example.com")
        XCTAssertEqual(HostsHostnameValidator.sanitize("Sub.Example.COM."), "sub.example.com")
        XCTAssertEqual(HostsHostnameValidator.sanitize("xn--bcher-kva.example"), "xn--bcher-kva.example")
    }

    func testRejectsUnsafeOrInvalidHostnames() {
        let invalid = [
            "",
            "localhost",
            "example",
            "-example.com",
            "example-.com",
            "exa mple.com",
            "https://example.com",
            "*.example.com",
            "127.0.0.1",
            "::1",
            "a..example.com",
            "example.com/path",
            "user@example.com",
            "example.com:443"
        ]
        for hostname in invalid {
            XCTAssertNil(HostsHostnameValidator.sanitize(hostname), "Expected \(hostname) to be rejected")
        }
    }

    func testValidatedHostnamesDeduplicatesAndSorts() throws {
        let result = try HostsHostnameValidator.validatedHostnames([
            "www.example.com",
            "example.com",
            "www.example.com"
        ])
        XCTAssertEqual(result, ["example.com", "www.example.com"])
    }

    func testValidatedHostnamesRejectsEmptyList() {
        XCTAssertThrowsError(try HostsHostnameValidator.validatedHostnames([])) { error in
            XCTAssertEqual(error as? HostsBlockingError, .noHostnames)
        }
    }
}

final class HostsBlocklistExpanderTests: XCTestCase {
    func testExpandsCommonAndServiceSpecificSubdomains() {
        let hosts = HostsBlocklistExpander.expand(domains: ["youtube.com", "x.com"])

        XCTAssertTrue(hosts.contains("youtube.com"))
        XCTAssertTrue(hosts.contains("www.youtube.com"))
        XCTAssertTrue(hosts.contains("m.youtube.com"))
        XCTAssertTrue(hosts.contains("youtu.be"))
        XCTAssertTrue(hosts.contains("x.com"))
        XCTAssertTrue(hosts.contains("www.x.com"))
        XCTAssertTrue(hosts.contains("mobile.x.com"))
        XCTAssertEqual(hosts, hosts.sorted())
        XCTAssertEqual(Set(hosts).count, hosts.count)
    }

    func testIgnoresInvalidDomains() {
        let hosts = HostsBlocklistExpander.expand(domains: ["example.com", "not a domain", "*.bad.com"])
        XCTAssertTrue(hosts.contains("example.com"))
        XCTAssertFalse(hosts.contains("not a domain"))
        XCTAssertFalse(hosts.contains("*.bad.com"))
    }
}

final class HostsFileBlocksTests: XCTestCase {
    private let sessionID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testApplyPreservesExistingContentAndWritesBothAddressFamilies() throws {
        let original = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"
        let updated = try HostsFileBlocks.apply(
            to: original,
            hostnames: ["example.com", "www.example.com"],
            sessionID: sessionID
        )

        XCTAssertTrue(updated.hasPrefix(original))
        XCTAssertTrue(updated.contains(HostsFileBlocks.beginMarker))
        XCTAssertTrue(updated.contains(HostsFileBlocks.endMarker))
        XCTAssertTrue(updated.contains("# Session: \(sessionID.uuidString)"))
        XCTAssertTrue(updated.contains("127.0.0.1 example.com"))
        XCTAssertTrue(updated.contains("127.0.0.1 www.example.com"))
        XCTAssertTrue(updated.contains("::1 example.com"))
        XCTAssertTrue(updated.contains("::1 www.example.com"))
    }

    func testApplyReplacesAnExistingFocusBarBlock() throws {
        let first = try HostsFileBlocks.apply(
            to: "127.0.0.1 localhost\n",
            hostnames: ["old.com"],
            sessionID: sessionID
        )
        let second = try HostsFileBlocks.apply(
            to: first,
            hostnames: ["new.com"],
            sessionID: UUID()
        )

        XCTAssertEqual(
            second.components(separatedBy: HostsFileBlocks.beginMarker).count - 1,
            1
        )
        XCTAssertFalse(second.contains("old.com"))
        XCTAssertTrue(second.contains("new.com"))
        XCTAssertTrue(second.hasPrefix("127.0.0.1 localhost\n"))
    }

    func testRemoveRestoresOriginalContent() throws {
        let original = "127.0.0.1 localhost\n255.255.255.255 broadcasthost\n"
        let updated = try HostsFileBlocks.apply(
            to: original,
            hostnames: ["example.com"],
            sessionID: sessionID
        )
        XCTAssertTrue(HostsFileBlocks.containsBlock(updated))
        XCTAssertEqual(try HostsFileBlocks.remove(from: updated), original)
        XCTAssertFalse(HostsFileBlocks.containsBlock(try HostsFileBlocks.remove(from: original)))
    }

    func testMalformedBlocksAreRejected() {
        XCTAssertThrowsError(
            try HostsFileBlocks.remove(from: "\(HostsFileBlocks.beginMarker)\nno end\n")
        ) { error in
            XCTAssertEqual(error as? HostsBlockingError, .malformedExistingBlock)
        }
        XCTAssertThrowsError(
            try HostsFileBlocks.remove(from: "\(HostsFileBlocks.endMarker)\n")
        ) { error in
            XCTAssertEqual(error as? HostsBlockingError, .malformedExistingBlock)
        }
    }

    func testInvalidHostnamesDoNotWriteAPartialBlock() {
        let original = "127.0.0.1 localhost\n"
        XCTAssertThrowsError(
            try HostsFileBlocks.apply(
                to: original,
                hostnames: ["example.com", "not a domain"],
                sessionID: sessionID
            )
        ) { error in
            XCTAssertEqual(error as? HostsBlockingError, .invalidHostname("not a domain"))
        }
    }
}

final class HostsBlockFileManagerTests: XCTestCase {
    private var directory: URL!
    private var hostsURL: URL!
    private var flushCount = 0

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarHostsTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        hostsURL = directory.appendingPathComponent("hosts")
        try Data("127.0.0.1 localhost\n".utf8).write(to: hostsURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hostsURL.path)
        flushCount = 0
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeManager() -> HostsBlockFileManager {
        HostsBlockFileManager(hostsURL: hostsURL) { [weak self] in
            self?.flushCount += 1
        }
    }

    func testApplyAndRemoveRoundTrip() throws {
        let manager = makeManager()
        XCTAssertFalse(try manager.isBlockPresent())
        try manager.apply(hostnames: ["example.com"], sessionID: UUID())

        let updated = try String(contentsOf: hostsURL, encoding: .utf8)
        XCTAssertTrue(HostsFileBlocks.containsBlock(updated))
        XCTAssertTrue(updated.contains("127.0.0.1 example.com"))
        XCTAssertTrue(try manager.isBlockPresent())
        XCTAssertEqual(flushCount, 1)

        let attributes = try FileManager.default.attributesOfItem(atPath: hostsURL.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o644)

        try manager.removeBlock()
        let restored = try String(contentsOf: hostsURL, encoding: .utf8)
        XCTAssertEqual(restored, "127.0.0.1 localhost\n")
        XCTAssertFalse(try manager.isBlockPresent())
        XCTAssertEqual(flushCount, 2)

        try manager.removeBlock()
        XCTAssertEqual(flushCount, 2)
    }

    func testMalformedBlockIsNotOverwritten() throws {
        let malformed = "127.0.0.1 localhost\n\(HostsFileBlocks.beginMarker)\n"
        try Data(malformed.utf8).write(to: hostsURL)

        let manager = makeManager()
        XCTAssertThrowsError(
            try manager.apply(hostnames: ["example.com"], sessionID: UUID())
        ) { error in
            XCTAssertEqual(error as? HostsBlockingError, .malformedExistingBlock)
        }
        XCTAssertEqual(try String(contentsOf: hostsURL, encoding: .utf8), malformed)
        XCTAssertEqual(flushCount, 0)
    }
}
