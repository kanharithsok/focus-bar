import Darwin
import Foundation
import os

enum HostsBlockingError: LocalizedError, Equatable {
    case noHostnames
    case tooManyHostnames(Int)
    case invalidHostname(String)
    case invalidSessionID
    case invalidLeaseID
    case malformedExistingBlock
    case unreadableHostsFile(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noHostnames:
            return "No website hostnames were provided."
        case .tooManyHostnames(let count):
            return "Too many hostnames for system-wide blocking (\(count))."
        case .invalidHostname(let hostname):
            return "Invalid hostname: \(hostname)"
        case .invalidSessionID:
            return "Invalid focus session identifier."
        case .invalidLeaseID:
            return "Invalid system-block lease identifier."
        case .malformedExistingBlock:
            return "The FocusBar section in /etc/hosts is malformed and was left untouched."
        case .unreadableHostsFile(let message):
            return "Couldn't read /etc/hosts: \(message)"
        case .writeFailed(let message):
            return "Couldn't update /etc/hosts: \(message)"
        }
    }
}

enum HostsHostnameValidator {
    /// Normalizes and validates a hostname that is safe to place in /etc/hosts.
    /// Only ASCII labels, no whitespace, no paths, no wildcards, no IP literals.
    static func sanitize(_ input: String) -> String? {
        var value = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        while value.hasSuffix(".") {
            value.removeLast()
        }

        guard !value.isEmpty, value.count <= 253, value.contains(".") else {
            return nil
        }
        guard value != "localhost", !value.hasSuffix(".local") else {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-.")
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return nil
        }

        let labels = value.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return nil }
        for label in labels {
            guard !label.isEmpty,
                  label.count <= 63,
                  label.first != "-",
                  label.last != "-"
            else {
                return nil
            }
        }

        var ipv4 = in_addr()
        if inet_pton(AF_INET, value, &ipv4) == 1 { return nil }
        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, value, &ipv6) == 1 { return nil }

        return value
    }

    static func validatedHostnames(_ inputs: [String]) throws -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for input in inputs {
            guard let sanitized = sanitize(input) else {
                throw HostsBlockingError.invalidHostname(input)
            }
            if seen.insert(sanitized).inserted {
                result.append(sanitized)
            }
        }

        guard !result.isEmpty else { throw HostsBlockingError.noHostnames }
        guard result.count <= SystemBlockingConstants.maximumHostnames else {
            throw HostsBlockingError.tooManyHostnames(result.count)
        }
        return result.sorted()
    }
}

/// Expands the base domains stored in a preset into the exact hostnames that
/// /etc/hosts can express. Hosts files have no wildcard syntax, so common
/// subdomains are listed explicitly. Unknown custom subdomains can still slip
/// through; the UI describes this as best effort.
enum HostsBlocklistExpander {
    static func expand(domains: [String]) -> [String] {
        var result = Set<String>()

        for domain in domains {
            guard let base = HostsHostnameValidator.sanitize(domain) else { continue }

            for prefix in ["", "www.", "m.", "mobile."] {
                if let host = HostsHostnameValidator.sanitize(prefix + base) {
                    result.insert(host)
                }
            }

            for extra in specialHostnames[base] ?? [] {
                if let host = HostsHostnameValidator.sanitize(extra) {
                    result.insert(host)
                }
            }
        }

        return result.sorted()
    }

    private static let specialHostnames: [String: [String]] = [
        "youtube.com": [
            "m.youtube.com",
            "music.youtube.com",
            "youtube-nocookie.com",
            "www.youtube-nocookie.com",
            "youtu.be",
            "www.youtu.be"
        ],
        "youtu.be": ["www.youtu.be"],
        "reddit.com": [
            "old.reddit.com",
            "new.reddit.com",
            "i.reddit.com",
            "np.reddit.com",
            "sh.reddit.com"
        ],
        "facebook.com": [
            "web.facebook.com",
            "mbasic.facebook.com"
        ],
        "twitter.com": ["mobile.twitter.com"],
        "x.com": ["mobile.x.com"],
        "tiktok.com": ["vm.tiktok.com"],
        "snapchat.com": ["web.snapchat.com"]
    ]
}

enum HostsFileBlocks {
    static let beginMarker = "# >>> FocusBar managed block >>>"
    static let endMarker = "# <<< FocusBar managed block <<<"
    static let header = "# Managed by FocusBar. This section is removed when the focus session ends."

    static func apply(to content: String, hostnames: [String], sessionID: UUID) throws -> String {
        let cleaned = try remove(from: content)
        let hosts = try HostsHostnameValidator.validatedHostnames(hostnames)

        var lines = [
            beginMarker,
            header,
            "# Session: \(sessionID.uuidString)"
        ]
        lines.append(contentsOf: hosts.map { "127.0.0.1 \($0)" })
        lines.append(contentsOf: hosts.map { "::1 \($0)" })
        lines.append(endMarker)

        var result = cleaned
        if !result.isEmpty && !result.hasSuffix("\n") {
            result += "\n"
        }
        result += lines.joined(separator: "\n")
        result += "\n"
        return result
    }

    static func remove(from content: String) throws -> String {
        let lines = content.components(separatedBy: "\n")
        var output: [String] = []
        var inside = false
        var removed = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == beginMarker {
                guard !inside else { throw HostsBlockingError.malformedExistingBlock }
                inside = true
                removed = true
                continue
            }
            if trimmed == endMarker {
                guard inside else { throw HostsBlockingError.malformedExistingBlock }
                inside = false
                continue
            }
            if !inside {
                output.append(line)
            }
        }

        guard !inside else { throw HostsBlockingError.malformedExistingBlock }
        guard removed else { return content }

        var result = output.joined(separator: "\n")
        while result.hasSuffix("\n\n") {
            result.removeLast()
        }
        if !result.isEmpty && !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }

    static func containsBlock(_ content: String) -> Bool {
        content.components(separatedBy: "\n").contains {
            $0.trimmingCharacters(in: .whitespaces) == beginMarker
        }
    }
}

/// Reads, atomically replaces, and restores /etc/hosts. The manager never
/// replaces user content: it only removes and appends its own marked section.
final class HostsBlockFileManager {
    private let hostsURL: URL
    private let fileManager: FileManager
    private let flushDNS: () -> Void
    private let logger = Logger(
        subsystem: SystemBlockingConstants.machServiceName,
        category: "hosts"
    )

    init(
        hostsURL: URL = URL(fileURLWithPath: "/private/etc/hosts"),
        fileManager: FileManager = .default,
        flushDNS: @escaping () -> Void = HostsBlockFileManager.flushSystemDNS
    ) {
        self.hostsURL = hostsURL.resolvingSymlinksInPath()
        self.fileManager = fileManager
        self.flushDNS = flushDNS
    }

    func apply(hostnames: [String], sessionID: UUID) throws {
        let content = try read()
        let updated = try HostsFileBlocks.apply(
            to: content,
            hostnames: hostnames,
            sessionID: sessionID
        )
        try write(updated)
        flushDNS()
    }

    func removeBlock() throws {
        let content = try read()
        let updated = try HostsFileBlocks.remove(from: content)
        guard updated != content else { return }
        try write(updated)
        flushDNS()
    }

    func isBlockPresent() throws -> Bool {
        try HostsFileBlocks.containsBlock(read())
    }

    private func read() throws -> String {
        guard fileManager.fileExists(atPath: hostsURL.path) else {
            return ""
        }
        do {
            return try String(contentsOf: hostsURL, encoding: .utf8)
        } catch {
            throw HostsBlockingError.unreadableHostsFile(error.localizedDescription)
        }
    }

    private func write(_ content: String) throws {
        let directory = hostsURL.deletingLastPathComponent()
        let attributes = try? fileManager.attributesOfItem(atPath: hostsURL.path)
        let originalMode = (attributes?[.posixPermissions] as? NSNumber)?.intValue ?? 0o644
        let tempURL = directory.appendingPathComponent(".focusbar-hosts-\(UUID().uuidString)")

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(content.utf8).write(to: tempURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: originalMode],
                ofItemAtPath: tempURL.path
            )

            let handle = try FileHandle(forWritingTo: tempURL)
            try handle.synchronize()
            try handle.close()

            let renamed = tempURL.path.withCString { source in
                hostsURL.path.withCString { destination in
                    rename(source, destination)
                }
            }
            guard renamed == 0 else {
                throw HostsBlockingError.writeFailed(String(cString: strerror(errno)))
            }

            let directoryFD = open(directory.path, O_RDONLY)
            if directoryFD >= 0 {
                fsync(directoryFD)
                close(directoryFD)
            }
        } catch let error as HostsBlockingError {
            try? fileManager.removeItem(at: tempURL)
            throw error
        } catch {
            try? fileManager.removeItem(at: tempURL)
            logger.error("Couldn't write hosts file: \(error.localizedDescription, privacy: .public)")
            throw HostsBlockingError.writeFailed(error.localizedDescription)
        }
    }

    static func flushSystemDNS() {
        run("/usr/bin/dscacheutil", arguments: ["-flushcache"])
        run("/usr/bin/killall", arguments: ["-HUP", "mDNSResponder"])
    }

    private static func run(_ executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            finished.signal()
        }

        do {
            try process.run()
            if finished.wait(timeout: .now() + 5) == .timedOut {
                process.terminate()
                dnsLogger.error("Timed out running \(executable, privacy: .public)")
            }
        } catch {
            dnsLogger.error("Couldn't run \(executable, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private static let dnsLogger = Logger(
        subsystem: SystemBlockingConstants.machServiceName,
        category: "dns"
    )
}
