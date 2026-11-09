import SwiftUI
import AppKit
import Combine
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    @State private var editingPreset: BlocklistPreset?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("FocusBar Settings")
                        .font(.title2.weight(.semibold))
                    Text("Local-first attention management")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                generalSection
                sessionSection
                blockingSection
                systemBlockingSection
                presetsSection
                shortcutSection
                privacySection
                aboutSection
            }
            .padding(20)
        }
        .frame(width: 580, height: 660)
        .background(WindowFocusView())
        .onAppear {
            app.loginItem.refresh()
            app.systemBlockingService.refresh()
            app.systemBlockingClient.refreshHelperStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            app.loginItem.refresh()
            app.systemBlockingService.refresh()
            app.systemBlockingClient.refreshHelperStatus()
        }
        .sheet(item: $editingPreset) { preset in
            BlocklistEditorView(preset: preset)
                .environment(app)
        }
    }

    private var generalSection: some View {
        SettingsSection(title: "General") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Start FocusBar at login", isOn: loginItemBinding)

                if let error = app.loginItem.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if app.loginItem.requiresApproval {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("macOS needs your approval in System Settings > General > Login Items.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Open Login Items") {
                            app.loginItem.openLoginItemsSettings()
                        }
                        .font(.caption)
                    }
                } else if app.loginItem.isUnavailable {
                    Text("macOS couldn't find this build as a login item. Move FocusBar to Applications, then try again.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Stays in the menu bar after you log in and restores any active session.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var sessionSection: some View {
        SettingsSection(title: "Session") {
            VStack(alignment: .leading, spacing: 9) {
                Toggle("Commit mode", isOn: settingBinding(\.commitMode))
                Text("Hides the normal early-end action. An emergency stop remains available and is recorded as an emergency stop. FocusBar cannot prevent force quitting or restarting macOS.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                HStack {
                    Text("Early-end delay")
                    Spacer()
                    Picker("Early-end delay", selection: settingBinding(\.earlyEndDelaySeconds)) {
                        ForEach(AppSettings.earlyEndDelayOptions, id: \.self) { seconds in
                            Text(seconds == 0 ? "None" : "\(seconds) seconds").tag(seconds)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                Text("Optional pause before End Session unlocks after you enter a reason. Default is none.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Toggle("Session notifications", isOn: settingBinding(\.notificationsEnabled))
                Text("Requests notification permission the first time a session starts. Blocking still works if notifications are denied.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var blockingSection: some View {
        SettingsSection(title: "Blocking") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Block selected applications", isOn: settingBinding(\.blockApps))
                Picker("When a blocked app activates", selection: settingBinding(\.appBlockingAction)) {
                    ForEach(AppBlockingAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .pickerStyle(.menu)
                Text(app.settings.settings.appBlockingAction.explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()

                Toggle("Guard active Safari and Chrome tabs", isOn: settingBinding(\.blockWebsites))
                Text("Best effort: only the active tab is inspected, about once per second while a supported browser is foreground. Background tabs, fast navigations, and permission failures can be missed.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text("Automation permission")
                        .font(.caption)
                    StatusPill(
                        text: app.blockingEngine.status.browserPermission.displayName,
                        color: permissionColor
                    )
                    Spacer()
                    Button("Open Settings") { app.openAutomationSettings() }
                        .font(.caption)
                    Button("Retry") { app.blockingEngine.retryBrowserPermission() }
                        .font(.caption)
                }

                if app.blockingEngine.status.browserPermission == .denied {
                    Text("Enable FocusBar under Privacy & Security > Automation. FocusBar asks only when browser protection needs to inspect a tab.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if app.blockingEngine.status.browserPermission == .unknown {
                    Text("Open Safari or Chrome, then click Retry to trigger the macOS Automation prompt. FocusBar reads only the active tab's URL.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Toggle("Keep blocking during Scatterfocus breaks", isOn: settingBinding(\.blockDuringScatterfocus))
                Text("On by default so a break doesn't become a scrolling session. You can still suspend blocking for an individual break.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("FocusBar never force-quits apps, never closes browser tabs, and never claims guaranteed blocking.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var systemBlockingSection: some View {
        SettingsSection(title: "System-wide website blocking") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Block listed websites in all browsers", isOn: systemWideBinding)

                Text("Installs a signed background helper that adds a marked section to /etc/hosts while a focus session is active. It applies to Safari, Chrome, Firefox, and other apps, not just the active browser tab. The section is removed when the session ends or after a short lease if FocusBar stops.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(
                    "Restart Zen/Firefox at session start and end",
                    isOn: settingBinding(\.restartMozillaBrowsersOnSessionChange)
                )
                .disabled(!app.settings.settings.systemWideWebsiteBlockingEnabled)

                Text("Zen and Firefox can keep cached DNS, pages, and connections after /etc/hosts changes. This option asks running Zen/Firefox to quit and reopens them so the block applies immediately and clears the cached error page afterward. FocusBar only sends a normal quit request; save your work first.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Restart Zen/Firefox now") {
                    app.mozillaRestarter.restartNow()
                }
                .font(.caption)

                if app.systemBlockingService.isAdHocSigned {
                    Text("This development build is ad-hoc signed. The privileged helper only accepts signed FocusBar builds; use the signed app in /Applications or sign this build with your Apple Development team.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Text("System helper")
                        .font(.caption)
                    StatusPill(
                        text: helperStatusText,
                        color: helperStatusColor
                    )
                    Spacer()
                    if app.systemBlockingService.requiresApproval {
                        Button("Open Login Items") {
                            app.systemBlockingService.openLoginItemsSettings()
                        }
                        .font(.caption)
                    } else if !app.systemBlockingService.isInstalled {
                        Button("Install helper") {
                            app.systemBlockingService.installIfNeeded()
                        }
                        .font(.caption)
                        .disabled(app.systemBlockingService.isAdHocSigned)
                    } else {
                        Button("Remove helper") {
                            Task {
                                await app.settings.update {
                                    $0.systemWideWebsiteBlockingEnabled = false
                                }
                                app.systemBlockingClient.stop()
                                app.systemBlockingService.uninstall()
                                app.blockingEngine.settingsDidChange(app.settings.settings)
                            }
                        }
                        .font(.caption)
                    }
                }

                if app.systemBlockingService.requiresApproval {
                    Text("macOS needs your approval in System Settings > General > Login Items before the helper can run.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let error = app.systemBlockingService.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Before deleting FocusBar, choose Remove helper. If the app is already gone, remove FocusBar under System Settings > General > Login Items & Extensions. If FocusBar disappears during a session, its helper lease expires after 30 seconds and clears the marked hosts section.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Best effort: VPNs, encrypted DNS, cached DNS, IP-literal URLs, and apps that ignore the system hosts file can bypass this. /etc/hosts cannot express wildcards, so FocusBar includes common subdomains but can't cover every possible one.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var presetsSection: some View {
        SettingsSection(title: "Blocklist presets") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(app.settings.settings.presets) { preset in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.name)
                                .font(.callout.weight(.medium))
                            Text("\(preset.normalizedWebsiteDomains.count) sites · \(preset.apps.count) apps")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Edit") {
                            editingPreset = preset
                        }
                        .font(.caption)
                        if !preset.isBuiltIn {
                            Button {
                                Task {
                                    await app.settings.deletePreset(id: preset.id)
                                    app.blockingEngine.settingsDidChange(app.settings.settings)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Delete \(preset.name)")
                        }
                    }
                    if preset.id != app.settings.settings.presets.last?.id {
                        Divider()
                    }
                }

                Button("Add preset") {
                    Task {
                        let preset = await app.settings.addPreset()
                        editingPreset = preset
                    }
                }
                .font(.caption)

                Text("The default preset includes common social services. YouTube is included but disabled by default.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var shortcutSection: some View {
        SettingsSection(title: "Global shortcut") {
            VStack(alignment: .leading, spacing: 8) {
                KeyboardShortcuts.Recorder("Park a distraction:", name: .captureDistraction)
                Text("Default is ⌃⌥Space. The capture panel opens instantly and saves one line locally. No screen-recording or accessibility permission is used.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var privacySection: some View {
        SettingsSection(title: "Privacy and data") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Everything stays on this Mac. There are no accounts, analytics, telemetry, cloud sync, or network calls.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(app.dataDirectory.path)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Reveal") {
                        NSWorkspace.shared.open(app.dataDirectory)
                    }
                    .font(.caption)
                }
            }
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            VStack(alignment: .leading, spacing: 5) {
                Text("FocusBar 1.0 · macOS 14+")
                    .font(.caption)
                Text("Local-first attention management. Blocking is best effort; FocusBar never force-quits apps or closes browser tabs.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var permissionColor: Color {
        switch app.blockingEngine.status.browserPermission {
        case .granted: return .green
        case .denied, .timedOut: return .orange
        case .unknown: return .secondary
        }
    }

    private func settingBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { app.settings.settings[keyPath: keyPath] },
            set: { newValue in
                Task {
                    await app.settings.update { $0[keyPath: keyPath] = newValue }
                    app.blockingEngine.settingsDidChange(app.settings.settings)
                }
            }
        )
    }

    private var systemWideBinding: Binding<Bool> {
        Binding(
            get: { app.settings.settings.systemWideWebsiteBlockingEnabled },
            set: { newValue in
                Task {
                    await app.settings.update {
                        $0.systemWideWebsiteBlockingEnabled = newValue
                    }
                    if newValue {
                        if !app.systemBlockingService.isAdHocSigned {
                            app.systemBlockingService.installIfNeeded()
                        }
                    } else {
                        app.systemBlockingClient.stop()
                    }
                    app.blockingEngine.settingsDidChange(app.settings.settings)
                }
            }
        )
    }

    private var helperStatusText: String {
        switch app.systemBlockingService.helperStatus {
        case .enabled:
            return "Installed"
        case .requiresApproval:
            return "Needs approval"
        case .notRegistered, .notFound:
            return "Not installed"
        default:
            return "Unknown"
        }
    }

    private var helperStatusColor: Color {
        switch app.systemBlockingService.helperStatus {
        case .enabled:
            return .green
        case .requiresApproval:
            return .orange
        default:
            return .secondary
        }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { app.loginItem.isEnabled },
            set: { app.loginItem.setEnabled($0) }
        )
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionLabel(text: title)
            Card {
                content
            }
        }
    }
}

/// Brings the Settings window to the front and makes it key when it appears.
/// FocusBar is an accessory app, so a newly opened window does not become
/// active on its own.
private struct WindowFocusView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
