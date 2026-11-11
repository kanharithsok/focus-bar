import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettings = .defaults()
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController
    @ObservationIgnored private let dateProvider: () -> Date
    @ObservationIgnored var onLocalChange: (() -> Void)?

    init(
        persistence: PersistenceController,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.persistence = persistence
        self.dateProvider = dateProvider
    }

    func load() async {
        if let loaded = await persistence.load(AppSettings.self, from: "settings.json") {
            settings = normalize(loaded)
        } else {
            settings = .defaults()
            await save()
        }
    }

    func update(_ mutation: (inout AppSettings) -> Void) async {
        var candidate = settings
        mutation(&candidate)
        candidate = normalize(candidate)

        let before = SharedSettingsSnapshot(settings: settings, updatedAt: .distantPast)
        let after = SharedSettingsSnapshot(settings: candidate, updatedAt: .distantPast)
        if before != after {
            candidate.sharedSettingsUpdatedAt = dateProvider()
        }

        settings = candidate
        await save()
    }

    func save(notify: Bool = true) async {
        do {
            try await persistence.save(settings, to: "settings.json")
            lastError = nil
            if notify {
                onLocalChange?()
            }
        } catch {
            lastError = "Couldn't save settings: \(error.localizedDescription)"
        }
    }

    var sharedSettingsSnapshot: SharedSettingsSnapshot {
        SharedSettingsSnapshot(settings: settings)
    }

    /// Ensures the first sync exports a timestamped local settings snapshot.
    func ensureSharedSettingsTimestamp() async {
        guard settings.sharedSettingsUpdatedAt == nil else { return }
        settings.sharedSettingsUpdatedAt = dateProvider()
        await save(notify: false)
    }

    /// Applies settings from another Mac only when they are newer. Device-local
    /// fields (helper, browser restart, sync configuration) are preserved.
    func applySharedSettings(_ snapshot: SharedSettingsSnapshot) async {
        guard snapshot.updatedAt > (settings.sharedSettingsUpdatedAt ?? .distantPast) else { return }
        snapshot.apply(to: &settings)
        settings = normalize(settings)
        await save(notify: false)
    }

    func preset(id: UUID?) -> BlocklistPreset? {
        guard let id else { return nil }
        return settings.presets.first { $0.id == id }
    }

    var selectedPreset: BlocklistPreset? {
        preset(id: settings.selectedPresetID) ?? settings.presets.first
    }

    func upsertPreset(_ preset: BlocklistPreset) async {
        if let index = settings.presets.firstIndex(where: { $0.id == preset.id }) {
            settings.presets[index] = preset
        } else {
            settings.presets.append(preset)
        }
        if settings.selectedPresetID == nil {
            settings.selectedPresetID = preset.id
        }
        await save()
    }

    func addPreset(name: String = "New preset") async -> BlocklistPreset {
        let preset = BlocklistPreset(name: name)
        settings.presets.append(preset)
        if settings.selectedPresetID == nil {
            settings.selectedPresetID = preset.id
        }
        await save()
        return preset
    }

    func deletePreset(id: UUID) async {
        guard let preset = preset(id: id), !preset.isBuiltIn else { return }
        settings.presets.removeAll { $0.id == id }
        if settings.selectedPresetID == id {
            settings.selectedPresetID = settings.presets.first?.id
        }
        await save()
    }

    func selectPreset(id: UUID?) async {
        guard id == nil || preset(id: id) != nil else { return }
        settings.selectedPresetID = id
        await save()
    }

    func clearError() {
        lastError = nil
    }

    private func normalize(_ value: AppSettings) -> AppSettings {
        var normalized = value
        if !AppSettings.earlyEndDelayOptions.contains(normalized.earlyEndDelaySeconds) {
            normalized.earlyEndDelaySeconds = 0
        }
        if normalized.presets.isEmpty {
            let preset = BlocklistPreset.socialMediaDefault()
            normalized.presets = [preset]
            normalized.selectedPresetID = preset.id
        } else if let selected = normalized.selectedPresetID,
                  !normalized.presets.contains(where: { $0.id == selected }) {
            normalized.selectedPresetID = normalized.presets.first?.id
        } else if normalized.selectedPresetID == nil {
            normalized.selectedPresetID = normalized.presets.first?.id
        }
        return normalized
    }
}
