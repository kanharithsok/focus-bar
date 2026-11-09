import Foundation
import Observation
import ServiceManagement

/// Registration and authorization state for the M6 privileged helper.
@MainActor
@Observable
final class SystemBlockingService {
    private(set) var helperStatus: SMAppService.Status = .notRegistered
    private(set) var lastError: String?

    /// Ad-hoc Xcode builds cannot satisfy the helper's code-signing check.
    /// Detect this up front so the UI explains the setup instead of showing a
    /// generic XPC failure.
    let isAdHocSigned: Bool = CodeSigningInfo.teamIdentifier() == nil

    var isInstalled: Bool {
        helperStatus == .enabled || helperStatus == .requiresApproval
    }

    var requiresApproval: Bool {
        helperStatus == .requiresApproval
    }

    var isReady: Bool {
        helperStatus == .enabled
    }

    private var service: SMAppService {
        SMAppService.daemon(plistName: SystemBlockingConstants.plistName)
    }

    func refresh() {
        helperStatus = service.status
    }

    func installIfNeeded() {
        lastError = nil
        refresh()
        guard helperStatus != .enabled && helperStatus != .requiresApproval else {
            return
        }

        var registrationError: Error?
        do {
            try service.register()
        } catch {
            // On current macOS versions register() can throw EPERM even when
            // the daemon was recorded successfully. Always trust the refreshed
            // status over the thrown error.
            registrationError = error
        }
        refresh()
        guard helperStatus == .notFound || helperStatus == .notRegistered else {
            return
        }

        // smd updates the background-task record asynchronously.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            self.refresh()
            if self.helperStatus == .notFound || self.helperStatus == .notRegistered {
                self.lastError = "Couldn't install the system helper: \(registrationError?.localizedDescription ?? "The helper did not register.")"
            }
        }
    }

    func uninstall() {
        lastError = nil
        refresh()
        guard helperStatus != .notRegistered && helperStatus != .notFound else {
            return
        }

        var removalError: Error?
        do {
            try service.unregister()
        } catch {
            removalError = error
        }
        refresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            self.refresh()
            if self.helperStatus == .enabled || self.helperStatus == .requiresApproval {
                self.lastError = "Couldn't remove the system helper: \(removalError?.localizedDescription ?? "The helper is still registered.")"
            }
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func clearError() {
        lastError = nil
    }
}
