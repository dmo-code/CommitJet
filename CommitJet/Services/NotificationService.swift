import Foundation
import UserNotifications

enum NotificationService {
    static func notifyCommitMessageReady(repositoryName: String, message: String, language: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        let isAuthorized: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            do {
                isAuthorized = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return
            }
        case .denied:
            return
        @unknown default:
            return
        }

        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = AppLanguage.text("Commit message ready", "Commit-Nachricht bereit", language: language)
        content.subtitle = repositoryName
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
