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

struct World3DGameView: UIViewControllerRepresentable {
    let sourceViewModel: GameViewModel

    func makeUIViewController(context: Context) -> World3DGameViewController {
        World3DGameViewController(sourceViewModel: sourceViewModel)
    }

    func updateUIViewController(_ uiViewController: World3DGameViewController, context: Context) {
        uiViewController.syncFromGameState()
    }
}
