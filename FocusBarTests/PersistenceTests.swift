import XCTest
@testable import FocusBar

final class PersistenceTests: XCTestCase {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FocusBarPersistence-\(UUID().uuidString)", isDirectory: true)
    }

    func testRoundTripVersionedPayload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceController(directory: directory)
        let record = makeRecord(startDate: Date(timeIntervalSince1970: 1_700_000_000), rating: 4)

        try await persistence.save([record], to: "sessions.json")
        let loaded = await persistence.load([SessionRecord].self, from: "sessions.json")

        XCTAssertEqual(loaded, [record])

        let data = try Data(contentsOf: directory.appendingPathComponent("sessions.json"))
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"schemaVersion\""))
        XCTAssertTrue(json.contains("\"payload\""))
    }

    func testMissingFileReturnsNil() async {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceController(directory: directory)
        let loaded = await persistence.load([SessionRecord].self, from: "missing.json")
        XCTAssertNil(loaded)
    }

    func testCorruptFileIsQuarantined() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("sessions.json"))

        let persistence = PersistenceController(directory: directory)
        let loaded = await persistence.load([SessionRecord].self, from: "sessions.json")

        XCTAssertNil(loaded)
        let issues = await persistence.consumeLoadIssues()
        XCTAssertFalse(issues.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("sessions.json").path))

        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.contains("sessions.json.corrupt-") })
    }

    func testNewerSchemaIsRejectedWithoutDeletingFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let json = #"{"schemaVersion":99,"payload":[]}"#
        let url = directory.appendingPathComponent("sessions.json")
        try Data(json.utf8).write(to: url)

        let persistence = PersistenceController(directory: directory)
        let loaded = await persistence.load([SessionRecord].self, from: "sessions.json")

        XCTAssertNil(loaded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let issues = await persistence.consumeLoadIssues()
        XCTAssertTrue(issues.first?.contains("newer version") == true)
    }

    func testAtomicSaveReplacesExistingContent() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let persistence = PersistenceController(directory: directory)
        try await persistence.save(["first"], to: "test.json")
        try await persistence.save(["second", "third"], to: "test.json")

        let loaded = await persistence.load([String].self, from: "test.json")
        XCTAssertEqual(loaded, ["second", "third"])
    }

    func testLegacyUnversionedPayloadIsAccepted() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([makeRecord(startDate: Date(timeIntervalSince1970: 1_700_000_000))])
        try data.write(to: directory.appendingPathComponent("sessions.json"))

        let persistence = PersistenceController(directory: directory)
        let loaded = await persistence.load([SessionRecord].self, from: "sessions.json")
        XCTAssertEqual(loaded?.count, 1)
    }
}
