import AppKit

@MainActor
final class BrowserBlocker: Blocker {
    let id = "browser"
    let displayName = "Browser tab guard"

    private(set) var isRunning = false
    private(set) var permission: BrowserAutomationPermission = .unknown

    private var configuration: BlockerConfiguration?
    private var observers: [NSObjectProtocol] = []
    private var pollTask: Task<Void, Never>?
    private var isChecking = false
    private var dedup = BlockedAttemptDeduplicator(cooldown: 60)
    private var lastHostByBrowser: [String: String] = [:]
    private let runner = AppleScriptRunner()

    var onBlocked: ((BlockedEvent) -> Void)?
    var onPermissionChanged: ((BrowserAutomationPermission) -> Void)?
    var onRedirectFailure: ((String) -> Void)?

    func start(configuration: BlockerConfiguration) {
        stop()
        guard !configuration.websiteDomains.isEmpty, configuration.blockedPageURL != nil else {
            return
        }

        self.configuration = configuration
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleActivation()
            }
        }
        observers.append(observer)
        isRunning = true
        handleActivation()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
        stopPolling()
        configuration = nil
        isRunning = false
        lastHostByBrowser.removeAll()
        dedup.resetAll()
    }

    func retryPermissionCheck() {
        updatePermission(.unknown)

        if let browser = runningSupportedBrowser() {
            // An explicit probe can show the macOS Automation prompt even when
            // the browser isn't frontmost. Give the user time to respond.
            Task { [weak self] in
                await self?.probePermission(for: browser)
            }
        } else {
            handleActivation()
        }
    }

    private func runningSupportedBrowser() -> BrowserDefinition? {
        SupportedBrowsers.all.first { browser in
            NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == browser.bundleID
            }
        }
    }

    private func probePermission(for browser: BrowserDefinition) async {
        let result = await runner.run(script: browser.urlScript, timeout: 30)

        switch result {
        case .success:
            updatePermission(.granted)
        case .failure(.permissionDenied):
            updatePermission(.denied)
        case .failure(.timedOut):
            updatePermission(.timedOut)
        case .failure:
            updatePermission(.unknown)
        }

        if isRunning,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier == browser.bundleID {
            startPolling()
        }
    }

    private func handleActivation() {
        guard isRunning else { return }
        guard SupportedBrowsers.browser(for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) != nil else {
            stopPolling()
            return
        }
        startPolling()
    }

    private func startPolling() {
        guard pollTask == nil else { return }

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                await self.checkActiveTab()
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func checkActiveTab() async {
        guard isRunning, !isChecking, let configuration else { return }
        guard let browser = SupportedBrowsers.browser(
            for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        ) else {
            stopPolling()
            return
        }

        isChecking = true
        defer { isChecking = false }

        let result = await runner.run(script: browser.urlScript, timeout: 2.5)

        // The session may have ended while the Apple Event was in flight.
        guard isRunning else { return }

        switch result {
        case .success(let output):
            updatePermission(.granted)

            guard !output.isEmpty,
                  let host = HostnameMatcher.hostname(from: output)
            else {
                lastHostByBrowser[browser.id] = nil
                dedup.reset(key: browser.id)
                return
            }

            if lastHostByBrowser[browser.id] != host {
                dedup.reset(key: browser.id)
            }
            lastHostByBrowser[browser.id] = host

            guard HostnameMatcher.matches(host: host, blockedDomains: configuration.websiteDomains) else {
                return
            }
            guard dedup.shouldRecord(key: browser.id, value: host, at: Date()) else {
                return
            }

            onBlocked?(
                BlockedEvent(
                    kind: .website,
                    identifier: host,
                    displayName: host,
                    browserName: browser.displayName,
                    detail: "Active tab matched the blocklist. Redirecting to the local blocked page."
                )
            )

            await redirect(browser: browser, configuration: configuration)

        case .failure(let error):
            switch error {
            case .permissionDenied:
                updatePermission(.denied)
                stopPolling()
            case .timedOut:
                updatePermission(.timedOut)
                stopPolling()
            case .executionFailed, .launchFailed:
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != browser.bundleID {
                    stopPolling()
                }
            }
        }
    }

    private func redirect(
        browser: BrowserDefinition,
        configuration: BlockerConfiguration
    ) async {
        guard let blockedPageURL = configuration.blockedPageURL else { return }

        let result = await runner.run(
            script: browser.redirectScript,
            arguments: [blockedPageURL.absoluteString],
            timeout: 2.5
        )

        switch result {
        case .success(let output):
            if output != "ok" {
                onRedirectFailure?(
                    "FocusBar couldn't redirect the \(browser.displayName) tab to its local blocked page. The tab was left open."
                )
            }
        case .failure(.permissionDenied):
            updatePermission(.denied)
            stopPolling()
            onRedirectFailure?(
                "FocusBar doesn't have Automation permission for \(browser.displayName). Enable it in System Settings > Privacy & Security > Automation. The tab was left open."
            )
        case .failure:
            onRedirectFailure?(
                "FocusBar couldn't redirect the \(browser.displayName) tab to its local blocked page. The tab was left open."
            )
        }
    }

    private func updatePermission(_ newValue: BrowserAutomationPermission) {
        guard permission != newValue else { return }
        permission = newValue
        onPermissionChanged?(newValue)
    }
}
