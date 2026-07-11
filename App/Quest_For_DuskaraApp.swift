import SwiftUI
import AppKit
import FirebaseCore

final class NotificationAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in MultiplayerNotificationService.shared.setAPNSToken(deviceToken) }
    }
}

@main
struct Quest_For_DuskaraApp: App {
	@NSApplicationDelegateAdaptor(NotificationAppDelegate.self) private var notificationDelegate
	init() {
		FirebaseBootstrap.configureIfNeeded()
	}

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1024, minHeight: 640)
        }
        // Landscape-first: open at the full visible width of the screen.
        .defaultSize(
            width: NSScreen.main?.visibleFrame.width ?? 1440,
            height: NSScreen.main?.visibleFrame.height ?? 900
        )
    }
}
