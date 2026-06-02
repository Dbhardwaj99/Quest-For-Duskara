import SwiftUI
import UIKit

struct World3DTownView: UIViewControllerRepresentable {
    let sourceViewModel: GameViewModel

    func makeUIViewController(context: Context) -> World3DTownViewController {
        World3DTownViewController(sourceViewModel: sourceViewModel)
    }

    func updateUIViewController(_ uiViewController: World3DTownViewController, context: Context) {
        uiViewController.syncFromGameState()
    }
}
