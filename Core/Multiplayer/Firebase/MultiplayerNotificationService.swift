import AppKit
import FirebaseAuth
import FirebaseFunctions
import FirebaseMessaging
import UserNotifications

@MainActor
final class MultiplayerNotificationService: NSObject, MessagingDelegate, UNUserNotificationCenterDelegate {
    static let shared = MultiplayerNotificationService()
    private var started = false

    func start() async {
        guard !started else { return }
        started = true
        UNUserNotificationCenter.current().delegate = self
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        Messaging.messaging().delegate = self
        NSApplication.shared.registerForRemoteNotifications()
        if let token = Messaging.messaging().fcmToken { await register(token) }
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { await register(fcmToken) }
    }

    func setAPNSToken(_ token: Data) { Messaging.messaging().apnsToken = token }

    private func register(_ token: String) async {
        guard Auth.auth().currentUser != nil else { return }
        _ = try? await Functions.functions().httpsCallable("registerNotificationToken").call([
            "token": token,
            "platform": "macOS"
        ])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions { [.banner, .sound] }
}
