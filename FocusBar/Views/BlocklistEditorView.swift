import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct BlocklistEditorView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    let preset: BlocklistPreset

    @State private var draft: BlocklistPreset
    @State private var customDomainsText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(preset: BlocklistPreset) {
        self.preset = preset
        _draft = State(initialValue: preset)
        let customDomains = preset.websiteDomains.filter { !ServiceCatalog.allDomains.contains($0) }
        _customDomainsText = State(initialValue: customDomains.joined(separator: ", "))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit blocklist")
                        .font(.title3.weight(.semibold))
                    Text("Apps and websites are blocked only when this preset is selected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: "Name")
                        TextField("Preset name", text: $draft.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        SectionLabel(text: "Social services")
                        ForEach(ServiceCatalog.services) { service in
                            Toggle(isOn: serviceBinding(service)) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(service.name)
                                    Text(service.domains.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        Text("YouTube is present but off by default.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        SectionLabel(text: "Custom websites")
                        TextField("example.com, news.example.org", text: $customDomainsText)
                            .textFieldStyle(.roundedBorder)
                        Text("Comma- or newline-separated. Domains match subdomains; paths are ignored.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            SectionLabel(text: "Applications")
                            Spacer()
                            Button("Add Application…") { chooseApplication() }
                                .font(.caption)
                        }

                        if draft.apps.isEmpty {
                            Text("No applications selected. Use Add Application to resolve an installed app's bundle identifier.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(draft.apps) { blockedApp in
                                HStack(spacing: 8) {
                                    Image(systemName: "app")
                                        .foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(blockedApp.name)
                                            .font(.caption)
                                        Text(blockedApp.bundleID)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Spacer()
                                    Button {
                                        draft.apps.removeAll { $0.bundleID == blockedApp.bundleID }
                                    } label: {
                                        Image(systemName: "xmark")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Remove \(blockedApp.name)")
                                }
                            }
                        }

                        Text("FocusBar hides apps by default. It never force-quits. A quit request is a normal request the app can refuse.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
            }

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(isSaving ? "Saving…" : "Save Preset") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 540, height: 600)
    }

    private func serviceBinding(_ service: ServiceCatalogEntry) -> Binding<Bool> {
        Binding(
            get: {
                service.domains.allSatisfy { draft.websiteDomains.contains($0) }
            },
            set: { enabled in
                var domains = Set(draft.websiteDomains)
                if enabled {
                    service.domains.forEach { domains.insert($0) }
                } else {
                    service.domains.forEach { domains.remove($0) }
                }
                draft.websiteDomains = Array(domains)
            }
        )
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to block"
        panel.prompt = "Choose"
        panel.allowedContentTypes = [.application]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            errorMessage = "That application doesn't expose a bundle identifier, so it can't be blocked safely."
            return
        }
        guard !draft.apps.contains(where: { $0.bundleID == bundleID }) else { return }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        draft.apps.append(BlockedApp(bundleID: bundleID, name: displayName))
        errorMessage = nil
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Give this preset a name."
            return
        }

        var customDomains: [String] = []
        let tokens = customDomainsText.split(whereSeparator: { $0 == "," || $0 == "\n" })
        for token in tokens {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let domain = HostnameMatcher.sanitizedDomain(trimmed) else {
                errorMessage = "“\(trimmed)” isn't a valid domain."
                return
            }
            customDomains.append(domain)
        }

        let serviceDomains = draft.websiteDomains.filter { ServiceCatalog.allDomains.contains($0) }
        draft.name = name
        draft.websiteDomains = Array(Set(serviceDomains + customDomains)).sorted()
        draft.apps = Array(
            Dictionary(grouping: draft.apps, by: \.bundleID)
                .compactMap { $0.value.first }
        ).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        isSaving = true
        errorMessage = nil

        Task {
            defer { isSaving = false }
            await app.settings.upsertPreset(draft)
            if let settingsError = app.settings.lastError {
                errorMessage = settingsError
            } else {
                dismiss()
            }
        }
    }
}
