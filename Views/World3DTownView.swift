import SwiftUI
import AppKit

struct World3DTownView: NSViewControllerRepresentable {
    let sourceViewModel: GameViewModel
    /// False while something covers the town; the scene stops drawing.
    var isActive = true
    var isInputEnabled = true
    var worldMapProgress = 0.0
    var travelDuration = 1.8
    var startsAboveTown = false
    var isCameraOrbiting = false
    /// Debug size overrides. Stored here rather than read from `BuildingScale`
    /// directly so that a slider change makes this value differ, which is what
    /// gets SwiftUI to re-run the update and push the new scales into the scene.
    var buildingScales: [BuildingKind: Float] = [:]
    /// Same reason as `buildingScales`: held here rather than read off
    /// `WorldContrast` so a slider change differs and drives the update.
    var contrast: Double = WorldContrast.standard

    func makeNSViewController(context: Context) -> World3DTownViewController {
        World3DTownViewController(sourceViewModel: sourceViewModel, initialWorldMapProgress: startsAboveTown ? 1 : worldMapProgress)
    }

    func updateNSViewController(_ nsViewController: World3DTownViewController, context: Context) {
        nsViewController.setActive(isActive)
        nsViewController.setWorldMapProgress(worldMapProgress, duration: travelDuration)
        nsViewController.setInputEnabled(isInputEnabled)
        nsViewController.setCameraOrbiting(isCameraOrbiting)
        nsViewController.syncFromGameState()
        // After the sync: a rebuilt tile already carries the current scale, and
        // syncFromGameState bails out mid-gesture while this must still apply.
        nsViewController.applyBuildingScales(buildingScales)
    }
}
