import AppKit
import Foundation
import Observation

/// Clears Zen/Firefox's browser-internal DNS, page, and connection caches by
/// asking a running Mozilla browser to quit and reopening it. This is opt-in:
/// quitting a browser is disruptive and FocusBar only sends a normal quit
/// request. It never force-terminates.
@MainActor
@Observable
final class MozillaBrowserRestarter {
    private static let bundleIDs = [
        "app.zen-browser.zen",
        "org.mozilla.firefox"
    ]

    private(set) var lastError: String?
    private(set) var lastAction: String?

    @ObservationIgnored private var waitTask: Task<Void, Never>?

    func restartWhenBlockStateChanges(expectedBlocked: Bool) {
        waitTask?.cancel()
        lastError = nil
        lastAction = nil

        waitTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(8)

            while !Task.isCancelled && Date() < deadline {
                if let blocked = Self.hostsIsBlocked(), blocked == expectedBlocked {
                    break
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            guard !Task.isCancelled,
                  let blocked = Self.hostsIsBlocked(),
                  blocked == expectedBlocked
            else {
                return
            }

            await self?.restartRunningBrowsers()
        }
    }

    func restartNow() {
        waitTask?.cancel()
        lastError = nil
        lastAction = nil
        waitTask = Task { [weak self] in
            await self?.restartRunningBrowsers()
        }
    }

    func clearError() {
        lastError = nil
    }

    private func restartRunningBrowsers() async {
        var restarted: [String] = []

        for bundleID in Self.bundleIDs {
            guard let app = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .first
            else {
                continue
            }

            let displayName = app.localizedName ?? bundleID
            guard let url = app.bundleURL
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else {
                lastError = "Couldn't find \(displayName) to reopen it."
                continue
            }

            guard app.terminate() else {
                lastError = "Couldn't ask \(displayName) to quit. Quit it manually to clear the browser cache."
                continue
            }

            if await waitForTermination(app) {
                await launch(url: url)
                restarted.append(displayName)
            } else {
                lastError = "\(displayName) didn't quit in time. Quit it manually to clear the browser cache."
            }
        }

        if !restarted.isEmpty {
            lastAction = "Restarted \(restarted.joined(separator: " and "))."
        }
    }

    private func waitForTermination(_ app: NSRunningApplication) async -> Bool {
        for _ in 0..<50 {
            if app.isTerminated {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return app.isTerminated
    }

    private func launch(url: URL) async {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration
            ) { [weak self] _, error in
                if let error {
                    Task { @MainActor in
                        self?.lastError = "Couldn't reopen the browser: \(error.localizedDescription)"
                    }
                }
                continuation.resume()
            }
        }
    }

    private static func hostsIsBlocked() -> Bool? {
        let url = URL(fileURLWithPath: "/private/etc/hosts")
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return HostsFileBlocks.containsBlock(content)
    }
}
