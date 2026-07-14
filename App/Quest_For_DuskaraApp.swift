import SwiftUI
import AppKit

@main
struct Quest_For_DuskaraApp: App {
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
