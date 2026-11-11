import Foundation
import os

/// Reads and writes device snapshots inside a user-selected sync folder.
/// The engine never touches another device's file and never deletes user data.
actor FolderSyncEngine {
    enum SyncFileError: LocalizedError {
        case folderUnavailable
        case newerSchema(String)
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .folderUnavailable:
                return "The sync folder is missing or not writable."
            case .newerSchema(let name):
                return "\(name) was created by a newer version of FocusBar. Update FocusBar on this Mac before syncing."
            case .unreadable(let name):
                return "Couldn't read \(name) from the sync folder."
            }
        }
    }

    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.kanharithsok.FocusBar", category: "sync")
    private let maximumSnapshotBytes = 25_000_000

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func sync(local: SyncSnapshot, folderURL: URL) throws -> SyncOutcome {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              fileManager.isWritableFile(atPath: folderURL.path) else {
            throw SyncFileError.folderUnavailable
        }

        let devicesURL = folderURL.appendingPathComponent("devices", isDirectory: true)
        try fileManager.createDirectory(at: devicesURL, withIntermediateDirectories: true)

        let ownURL = devicesURL.appendingPathComponent(fileName(for: local.deviceID))
        let urls = try snapshotURLs(in: devicesURL)
        var remotes: [SyncSnapshot] = []
        var warnings: [String] = []
        var otherDeviceIDs = Set<UUID>()
        var ownSnapshot: SyncSnapshot?

        for url in urls {
            guard fileManager.fileExists(atPath: url.path) else {
                // iCloud may still be downloading an evicted snapshot. A later
                // periodic sync retries.
                continue
            }

            if fileManager.isUbiquitousItem(at: url) {
                // Ask iCloud for an evicted file; a later sync retries if the
                // download has not completed yet.
                try? fileManager.startDownloadingUbiquitousItem(at: url)
            }

            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size > maximumSnapshotBytes {
                warnings.append("Skipped \(url.lastPathComponent): it is unexpectedly large.")
                continue
            }

            do {
                let data = try coordinatedRead(at: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .millisecondsSince1970
                let snapshot = try decoder.decode(SyncSnapshot.self, from: data)

                guard snapshot.schemaVersion <= SyncSnapshot.schemaVersion else {
                    if url == ownURL {
                        throw SyncFileError.newerSchema(url.lastPathComponent)
                    }
                    warnings.append("Skipped \(url.lastPathComponent): it was created by a newer FocusBar version.")
                    continue
                }

                if snapshot.deviceID == local.deviceID {
                    ownSnapshot = snapshot
                } else {
                    otherDeviceIDs.insert(snapshot.deviceID)
                }
                remotes.append(snapshot)
            } catch let error as SyncFileError {
                throw error
            } catch {
                logger.error(
                    "Could not read sync file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                if url == ownURL {
                    warnings.append("Replaced an unreadable sync snapshot for this Mac.")
                } else {
                    warnings.append("Skipped an unreadable sync file: \(url.lastPathComponent).")
                }
            }
        }

        let merged = SyncMerge.merge(local: local, remotes: remotes)

        // Avoid uploading a new snapshot on every periodic check. The encoded
        // snapshot is deterministic when the data has not changed.
        if ownSnapshot != merged {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            // Milliseconds keep review/settings ordering precise enough; the
            // default ISO-8601 strategy rounds to whole seconds.
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let data = try encoder.encode(merged)
            try coordinatedWrite(data, to: ownURL)
        }

        return SyncOutcome(
            snapshot: merged,
            otherDeviceCount: otherDeviceIDs.count,
            warnings: warnings
        )
    }

    private func fileName(for deviceID: UUID) -> String {
        "device-\(deviceID.uuidString).json"
    }

    private func snapshotURLs(in directory: URL) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: []
        )

        let prefix = "device-"
        let suffix = ".json"
        let placeholderSuffix = ".icloud"
        var byName: [String: URL] = [:]

        for url in urls {
            let name = url.lastPathComponent
            let logicalName: String
            let isPlaceholder: Bool

            if name.hasPrefix(".") && name.hasSuffix(placeholderSuffix) {
                logicalName = String(
                    name.dropFirst().dropLast(placeholderSuffix.count)
                )
                isPlaceholder = true
            } else {
                logicalName = name
                isPlaceholder = false
            }

            guard logicalName.hasPrefix(prefix), logicalName.hasSuffix(suffix) else { continue }
            let idPart = String(
                logicalName.dropFirst(prefix.count).dropLast(suffix.count)
            )
            guard UUID(uuidString: idPart) != nil else { continue }

            let logicalURL = directory.appendingPathComponent(logicalName)
            byName[logicalName] = logicalURL

            if isPlaceholder {
                // Ask iCloud to materialize the logical file. Reading is
                // skipped until a later sync sees the downloaded file.
                try? fileManager.startDownloadingUbiquitousItem(at: logicalURL)
            }
        }

        return byName.values.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func coordinatedRead(at url: URL) throws -> Data {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var readError: Error?
        var data: Data?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { readURL in
            do {
                data = try Data(contentsOf: readURL)
            } catch {
                readError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let readError { throw readError }
        guard let data else { throw SyncFileError.unreadable(url.lastPathComponent) }
        return data
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { writeURL in
            do {
                try data.write(to: writeURL, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let coordinationError { throw coordinationError }
        if let writeError { throw writeError }
    }
}
