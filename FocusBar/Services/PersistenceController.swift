import Foundation
import os

/// Actor-backed JSON persistence. Versioned envelopes + atomic writes.
actor PersistenceController {
    struct Versioned<Payload: Codable>: Codable {
        var schemaVersion: Int
        var payload: Payload
    }

    static let schemaVersion = 1
    static let folderName = "FocusBar"

    let directory: URL
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.kanharithsok.FocusBar", category: "persistence")
    private var loadIssues: [String] = []

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support", isDirectory: true)
            self.directory = base.appendingPathComponent(Self.folderName, isDirectory: true)
        }
    }

    func load<T: Codable>(_ type: T.Type, from filename: String) -> T? {
        let url = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return nil }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let envelope = try? decoder.decode(Versioned<T>.self, from: data) {
                guard envelope.schemaVersion <= Self.schemaVersion else {
                    let issue = "\(filename) was created by a newer version of FocusBar. It was left untouched."
                    logger.error("\(issue, privacy: .public)")
                    loadIssues.append(issue)
                    return nil
                }
                return envelope.payload
            }

            // Tolerate an unversioned payload from early development builds.
            if let raw = try? decoder.decode(T.self, from: data) {
                return raw
            }

            throw CocoaError(.fileReadCorruptFile)
        } catch {
            logger.error("Failed to load \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
            quarantine(url, filename: filename)
            loadIssues.append("Couldn't read \(filename). A preserved copy was moved aside.")
            return nil
        }
    }

    func save<T: Codable>(_ value: T, to filename: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let envelope = Versioned(schemaVersion: Self.schemaVersion, payload: value)
        let data = try encoder.encode(envelope)
        try data.write(to: directory.appendingPathComponent(filename), options: .atomic)
    }

    func remove(_ filename: String) throws {
        let url = directory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func consumeLoadIssues() -> [String] {
        let issues = loadIssues
        loadIssues.removeAll()
        return issues
    }

    private func quarantine(_ url: URL, filename: String) {
        let stamp = Int(Date().timeIntervalSince1970)
        var destination = url.appendingPathExtension("corrupt-\(stamp)")
        var suffix = 1
        while fileManager.fileExists(atPath: destination.path) {
            destination = url.appendingPathExtension("corrupt-\(stamp)-\(suffix)")
            suffix += 1
        }
        do {
            try fileManager.moveItem(at: url, to: destination)
            logger.error("Quarantined corrupt file \(filename, privacy: .public) at \(destination.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Could not quarantine \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
