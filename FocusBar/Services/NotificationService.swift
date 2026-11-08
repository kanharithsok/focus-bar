import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private var didRequestAuthorization = false

    func requestAuthorizationIfNeeded(enabled: Bool) {
        guard enabled, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            // Denial is handled silently; blocking still works without notifications.
        }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
