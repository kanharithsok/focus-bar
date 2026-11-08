import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let error = app.combinedError {
                        ErrorBanner(message: error, onDismiss: app.dismissStartupWarning)
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
            }
            .frame(maxHeight: 640)

            Divider()

            HStack(spacing: 10) {
                Text("Local-only")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
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
    }
}
