import SwiftUI
import AppKit

struct World3DTownView: NSViewControllerRepresentable {
    let sourceViewModel: GameViewModel
    var isCameraOrbiting = false

    func makeNSViewController(context: Context) -> World3DTownViewController {
        World3DTownViewController(sourceViewModel: sourceViewModel)
    }

    func updateNSViewController(_ nsViewController: World3DTownViewController, context: Context) {
        nsViewController.setCameraOrbiting(isCameraOrbiting)
        nsViewController.syncFromGameState()
    }
}
