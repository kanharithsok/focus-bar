import Foundation

enum AppBlockingAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case hide
    case requestTerminate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hide: return "Hide the app"
        case .requestTerminate: return "Request the app quit"
        }
    }

    var explanation: String {
        switch self {
        case .hide:
            return "Non-destructive. The app keeps running and can be shown again."
        case .requestTerminate:
            return "Sends a normal quit request. The app may refuse; FocusBar never force-quits."
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    static let earlyEndDelayOptions = [0, 5, 10, 15, 20, 30]

    var commitMode: Bool
    var blockApps: Bool
    var blockWebsites: Bool
    var systemWideWebsiteBlockingEnabled: Bool
    var restartMozillaBrowsersOnSessionChange: Bool
    var blockDuringScatterfocus: Bool
    var appBlockingAction: AppBlockingAction
    var presets: [BlocklistPreset]
    var selectedPresetID: UUID?
    var notificationsEnabled: Bool
    var earlyEndDelaySeconds: Int

    // Optional multi-Mac sync configuration. These are device-local and are
    // never written to the shared folder.
    var syncEnabled: Bool
    var syncFolderPath: String?
    var syncFolderBookmark: Data?
    /// Timestamp of the last change to a shared setting. Device-specific
    /// settings (system helper, browser restart, sync configuration) do not
    /// update this value.
    var sharedSettingsUpdatedAt: Date?

    init(
        commitMode: Bool,
        blockApps: Bool,
        blockWebsites: Bool,
        systemWideWebsiteBlockingEnabled: Bool,
        restartMozillaBrowsersOnSessionChange: Bool,
        blockDuringScatterfocus: Bool,
        appBlockingAction: AppBlockingAction,
        presets: [BlocklistPreset],
        selectedPresetID: UUID?,
        notificationsEnabled: Bool,
        earlyEndDelaySeconds: Int,
        syncEnabled: Bool = false,
        syncFolderPath: String? = nil,
        syncFolderBookmark: Data? = nil,
        sharedSettingsUpdatedAt: Date? = nil
    ) {
        self.commitMode = commitMode
        self.blockApps = blockApps
        self.blockWebsites = blockWebsites
        self.systemWideWebsiteBlockingEnabled = systemWideWebsiteBlockingEnabled
        self.restartMozillaBrowsersOnSessionChange = restartMozillaBrowsersOnSessionChange
        self.blockDuringScatterfocus = blockDuringScatterfocus
        self.appBlockingAction = appBlockingAction
        self.presets = presets
        self.selectedPresetID = selectedPresetID
        self.notificationsEnabled = notificationsEnabled
        self.earlyEndDelaySeconds = earlyEndDelaySeconds
        self.syncEnabled = syncEnabled
        self.syncFolderPath = syncFolderPath
        self.syncFolderBookmark = syncFolderBookmark
        self.sharedSettingsUpdatedAt = sharedSettingsUpdatedAt
    }

    static func defaults() -> AppSettings {
        let preset = BlocklistPreset.socialMediaDefault()
        return AppSettings(
            commitMode: false,
            blockApps: true,
            blockWebsites: true,
            systemWideWebsiteBlockingEnabled: false,
            restartMozillaBrowsersOnSessionChange: false,
            blockDuringScatterfocus: true,
            appBlockingAction: .hide,
            presets: [preset],
            selectedPresetID: preset.id,
            notificationsEnabled: true,
            earlyEndDelaySeconds: 0,
            syncEnabled: false,
            syncFolderPath: nil,
            syncFolderBookmark: nil,
            sharedSettingsUpdatedAt: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case commitMode
        case blockApps
        case blockWebsites
        case systemWideWebsiteBlockingEnabled
        case restartMozillaBrowsersOnSessionChange
        case blockDuringScatterfocus
        case appBlockingAction
        case presets
        case selectedPresetID
        case notificationsEnabled
        case earlyEndDelaySeconds
        case syncEnabled
        case syncFolderPath
        case syncFolderBookmark
        case sharedSettingsUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.defaults()

        commitMode = try container.decodeIfPresent(Bool.self, forKey: .commitMode) ?? fallback.commitMode
        blockApps = try container.decodeIfPresent(Bool.self, forKey: .blockApps) ?? fallback.blockApps
        blockWebsites = try container.decodeIfPresent(Bool.self, forKey: .blockWebsites) ?? fallback.blockWebsites
        systemWideWebsiteBlockingEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .systemWideWebsiteBlockingEnabled
        ) ?? fallback.systemWideWebsiteBlockingEnabled
        restartMozillaBrowsersOnSessionChange = try container.decodeIfPresent(
            Bool.self,
            forKey: .restartMozillaBrowsersOnSessionChange
        ) ?? fallback.restartMozillaBrowsersOnSessionChange
        blockDuringScatterfocus = try container.decodeIfPresent(Bool.self, forKey: .blockDuringScatterfocus) ?? fallback.blockDuringScatterfocus
        appBlockingAction = try container.decodeIfPresent(AppBlockingAction.self, forKey: .appBlockingAction) ?? fallback.appBlockingAction
        presets = try container.decodeIfPresent([BlocklistPreset].self, forKey: .presets) ?? fallback.presets
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled
        earlyEndDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .earlyEndDelaySeconds) ?? fallback.earlyEndDelaySeconds
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? fallback.syncEnabled
        syncFolderPath = try container.decodeIfPresent(String.self, forKey: .syncFolderPath)
        syncFolderBookmark = try container.decodeIfPresent(Data.self, forKey: .syncFolderBookmark)
        sharedSettingsUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .sharedSettingsUpdatedAt)

        if let storedID = try container.decodeIfPresent(UUID.self, forKey: .selectedPresetID),
           presets.contains(where: { $0.id == storedID }) {
            selectedPresetID = storedID
        } else {
            selectedPresetID = presets.first?.id
        }
    }
}
