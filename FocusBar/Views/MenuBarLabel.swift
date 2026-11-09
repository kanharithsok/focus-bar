import SwiftUI

struct MenuBarLabel: View {
    let sessionManager: SessionManager

    var body: some View {
        Group {
            switch sessionManager.phase {
            case .idle:
                Image(systemName: "circle.dashed")
                    .accessibilityLabel("FocusBar idle")
            case .hyperfocus:
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text(sessionManager.remainingText)
                        .monospacedDigit()
                }
                .accessibilityLabel("Hyperfocus, \(sessionManager.remainingText) remaining")
            case .scatterfocus:
                HStack(spacing: 4) {
                    Image(systemName: "leaf")
                    Text(sessionManager.remainingText)
                        .monospacedDigit()
                }
                .accessibilityLabel("Scatterfocus, \(sessionManager.remainingText) remaining")
            case .review:
                Image(systemName: "checkmark.circle")
                    .accessibilityLabel("Session ready to review")
            }
        }
        .accessibilityIdentifier("focusBarMenuBarItem")
    }
}
