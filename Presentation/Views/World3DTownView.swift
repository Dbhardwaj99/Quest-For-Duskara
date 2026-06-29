import SwiftUI
import AppKit

struct World3DTownView: NSViewControllerRepresentable {
    let sourceViewModel: GameViewModel

    func makeNSViewController(context: Context) -> World3DTownViewController {
        World3DTownViewController(sourceViewModel: sourceViewModel)
    }

    func updateNSViewController(_ nsViewController: World3DTownViewController, context: Context) {
        nsViewController.syncFromGameState()
    }
}
