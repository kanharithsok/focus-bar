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
    var commitMode: Bool
    var blockApps: Bool
    var blockWebsites: Bool
    var blockDuringScatterfocus: Bool
    var appBlockingAction: AppBlockingAction
    var presets: [BlocklistPreset]
    var selectedPresetID: UUID?
    var notificationsEnabled: Bool

    init(
        commitMode: Bool,
        blockApps: Bool,
        blockWebsites: Bool,
        blockDuringScatterfocus: Bool,
        appBlockingAction: AppBlockingAction,
        presets: [BlocklistPreset],
        selectedPresetID: UUID?,
        notificationsEnabled: Bool
    ) {
        self.commitMode = commitMode
        self.blockApps = blockApps
        self.blockWebsites = blockWebsites
        self.blockDuringScatterfocus = blockDuringScatterfocus
        self.appBlockingAction = appBlockingAction
        self.presets = presets
        self.selectedPresetID = selectedPresetID
        self.notificationsEnabled = notificationsEnabled
    }

    static func defaults() -> AppSettings {
        let preset = BlocklistPreset.socialMediaDefault()
        return AppSettings(
            commitMode: false,
            blockApps: true,
            blockWebsites: true,
            blockDuringScatterfocus: true,
            appBlockingAction: .hide,
            presets: [preset],
            selectedPresetID: preset.id,
            notificationsEnabled: true
        )
    }

    enum CodingKeys: String, CodingKey {
        case commitMode
        case blockApps
        case blockWebsites
        case blockDuringScatterfocus
        case appBlockingAction
        case presets
        case selectedPresetID
        case notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.defaults()

        commitMode = try container.decodeIfPresent(Bool.self, forKey: .commitMode) ?? fallback.commitMode
        blockApps = try container.decodeIfPresent(Bool.self, forKey: .blockApps) ?? fallback.blockApps
        blockWebsites = try container.decodeIfPresent(Bool.self, forKey: .blockWebsites) ?? fallback.blockWebsites
        blockDuringScatterfocus = try container.decodeIfPresent(Bool.self, forKey: .blockDuringScatterfocus) ?? fallback.blockDuringScatterfocus
        appBlockingAction = try container.decodeIfPresent(AppBlockingAction.self, forKey: .appBlockingAction) ?? fallback.appBlockingAction
        presets = try container.decodeIfPresent([BlocklistPreset].self, forKey: .presets) ?? fallback.presets
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? fallback.notificationsEnabled

        if let storedID = try container.decodeIfPresent(UUID.self, forKey: .selectedPresetID),
           presets.contains(where: { $0.id == storedID }) {
            selectedPresetID = storedID
        } else {
            selectedPresetID = presets.first?.id
        }
    }
}
