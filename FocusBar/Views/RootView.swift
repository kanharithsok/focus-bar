import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openSettings) private var openSettings

    @State private var showHistory = false
    @State private var contentHeight: CGFloat = 0

    private static let maxContentHeight: CGFloat = 640
    private static let fallbackContentHeight: CGFloat = 480

    private var scrollHeight: CGFloat {
        guard contentHeight > 0 else { return Self.fallbackContentHeight }
        return min(contentHeight, Self.maxContentHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = app.combinedError {
                        ErrorBanner(message: error, onDismiss: app.dismissError)
                    }

                    switch app.sessionManager.phase {
                    case .idle:
                        IdleView()
                    case .hyperfocus:
                        HyperfocusView()
                    case .scatterfocus:
                        ScatterfocusView()
                    case .review:
                        ReviewView()
                    }
                }
                .padding(16)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                )
            }
            .frame(height: scrollHeight)
            .scrollBounceBehavior(.basedOnSize)

            Divider()

            HStack(spacing: 12) {
                Text("Local-only")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("History") {
                    showHistory = true
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Button("Settings") {
                    // The app runs as an accessory, so opening Settings has to
                    // explicitly activate it before the window is shown.
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(width: 380)
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
        .sheet(isPresented: $showHistory) {
            StatsView()
                .environment(app)
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
