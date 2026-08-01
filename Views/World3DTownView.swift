import SwiftUI
import AppKit

struct World3DTownView: NSViewControllerRepresentable {
    let sourceViewModel: GameViewModel
    var isCameraOrbiting = false
    /// Debug size overrides. Stored here rather than read from `BuildingScale`
    /// directly so that a slider change makes this value differ, which is what
    /// gets SwiftUI to re-run the update and push the new scales into the scene.
    var buildingScales: [BuildingKind: Float] = [:]

    func makeNSViewController(context: Context) -> World3DTownViewController {
        World3DTownViewController(sourceViewModel: sourceViewModel)
    }

    func updateNSViewController(_ nsViewController: World3DTownViewController, context: Context) {
        nsViewController.setCameraOrbiting(isCameraOrbiting)
        nsViewController.syncFromGameState()
        // After the sync: a rebuilt tile already carries the current scale, and
        // syncFromGameState bails out mid-gesture while this must still apply.
        nsViewController.applyBuildingScales()
    }
}
