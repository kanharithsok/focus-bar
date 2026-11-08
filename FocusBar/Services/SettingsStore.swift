import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettings = .defaults()
    private(set) var lastError: String?

    @ObservationIgnored private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
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
        mutation(&settings)
        settings = normalize(settings)
        await save()
    }

    func save() async {
        do {
            try await persistence.save(settings, to: "settings.json")
            lastError = nil
        } catch {
            lastError = "Couldn't save settings: \(error.localizedDescription)"
        }
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

    private func normalize(_ value: AppSettings) -> AppSettings {
        var normalized = value
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
