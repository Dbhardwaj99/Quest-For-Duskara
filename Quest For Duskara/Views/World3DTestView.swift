import SwiftUI
import UIKit

struct World3DTestView: UIViewControllerRepresentable {
    let sourceViewModel: GameViewModel

    func makeUIViewController(context: Context) -> World3DTestViewController {
        World3DTestViewController(sourceViewModel: sourceViewModel)
    }

    func updateUIViewController(_ uiViewController: World3DTestViewController, context: Context) { }
}
