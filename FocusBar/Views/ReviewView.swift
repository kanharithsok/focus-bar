import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var app

    private var record: SessionRecord? {
        app.sessionManager.pendingReview
    }

    var body: some View {
        if let record {
            VStack(alignment: .leading, spacing: 14) {
                Label("Session complete", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)

                Text(record.focusObject)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    StatusPill(text: record.status.displayName)
                    Text("\(SessionTimer.roundedMinutes(record.actualDuration)) min")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Button("Done") {
                    Task { await app.sessionManager.skipReview() }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        } else {
            Text("Nothing to review")
                .foregroundStyle(.secondary)
        }
    }
}
