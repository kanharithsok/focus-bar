import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class LoginItemManager {
    private(set) var status: SMAppService.Status = SMAppService.mainApp.status
    private(set) var lastError: String?

    /// True when the app is registered, including the case where macOS is
    /// waiting for the user to approve the login item.
    var isEnabled: Bool {
        status == .enabled || status == .requiresApproval
    }

    var requiresApproval: Bool {
        status == .requiresApproval
    }

    var isUnavailable: Bool {
        status == .notFound
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil

        do {
            if enabled {
                if status != .enabled && status != .requiresApproval {
                    try SMAppService.mainApp.register()
                }
            } else if status != .notRegistered && status != .notFound {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "Couldn't update the login item: \(error.localizedDescription)"
        }

        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
