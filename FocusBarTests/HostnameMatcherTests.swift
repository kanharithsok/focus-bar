import XCTest
@testable import FocusBar

final class HostnameMatcherTests: XCTestCase {
    func testExactAndSubdomainMatches() {
        let blocked = ["x.com", "youtube.com"]
        XCTAssertTrue(HostnameMatcher.matches(host: "x.com", blockedDomains: blocked))
        XCTAssertTrue(HostnameMatcher.matches(host: "mobile.x.com", blockedDomains: blocked))
        XCTAssertTrue(HostnameMatcher.matches(host: "WWW.X.COM", blockedDomains: blocked))
        XCTAssertTrue(HostnameMatcher.matches(host: "www.youtube.com", blockedDomains: blocked))
        XCTAssertTrue(HostnameMatcher.matches(host: "x.com.", blockedDomains: blocked))
    }

    func testUnrelatedDomainsDoNotMatch() {
        let blocked = ["x.com"]
        XCTAssertFalse(HostnameMatcher.matches(host: "notx.com", blockedDomains: blocked))
        XCTAssertFalse(HostnameMatcher.matches(host: "x.com.evil.com", blockedDomains: blocked))
        XCTAssertFalse(HostnameMatcher.matches(host: "example.com", blockedDomains: blocked))
        XCTAssertFalse(HostnameMatcher.matches(host: "", blockedDomains: blocked))
    }

    func testHostnameExtraction() {
        XCTAssertEqual(HostnameMatcher.hostname(from: "https://www.x.com/home?q=1#top"), "x.com")
        XCTAssertEqual(HostnameMatcher.hostname(from: "http://mobile.threads.net:443/path"), "mobile.threads.net")
        XCTAssertEqual(HostnameMatcher.hostname(from: "x.com/path"), "x.com")
        XCTAssertEqual(HostnameMatcher.hostname(from: "  https://REDDIT.com.  "), "reddit.com")
        XCTAssertNil(HostnameMatcher.hostname(from: ""))
        XCTAssertNil(HostnameMatcher.hostname(from: "file:///tmp/blocked.html"))
        XCTAssertNil(HostnameMatcher.hostname(from: "about:blank"))
    }

    func testSanitizedDomain() {
        XCTAssertEqual(HostnameMatcher.sanitizedDomain("https://www.example.com/path?q=1"), "example.com")
        XCTAssertEqual(HostnameMatcher.sanitizedDomain(" Example.COM. "), "example.com")
        XCTAssertNil(HostnameMatcher.sanitizedDomain("not a domain"))
        XCTAssertNil(HostnameMatcher.sanitizedDomain(""))
        XCTAssertNil(HostnameMatcher.sanitizedDomain("https://"))
        XCTAssertNil(HostnameMatcher.sanitizedDomain(".com"))
    }
}

final class BlockedAttemptDeduplicatorTests: XCTestCase {
    func testSameValueIsSuppressedWithinCooldown() {
        var dedup = BlockedAttemptDeduplicator(cooldown: 30)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "x.com", at: now))
        XCTAssertFalse(dedup.shouldRecord(key: "safari", value: "x.com", at: now.addingTimeInterval(1)))
        XCTAssertFalse(dedup.shouldRecord(key: "safari", value: "x.com", at: now.addingTimeInterval(29)))
        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "x.com", at: now.addingTimeInterval(30)))
    }

    func testDifferentValueOrKeyRecordsImmediately() {
        var dedup = BlockedAttemptDeduplicator(cooldown: 30)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "x.com", at: now))
        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "reddit.com", at: now.addingTimeInterval(1)))
        XCTAssertTrue(dedup.shouldRecord(key: "chrome", value: "x.com", at: now.addingTimeInterval(1)))
    }

    func testResetAllowsImmediateRecord() {
        var dedup = BlockedAttemptDeduplicator(cooldown: 30)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "x.com", at: now))
        dedup.reset(key: "safari")
        XCTAssertTrue(dedup.shouldRecord(key: "safari", value: "x.com", at: now.addingTimeInterval(1)))
    }
}
