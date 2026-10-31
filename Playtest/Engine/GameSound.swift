/// Stands in for the app's GameSound (ViewModels/GameSound.swift), which plays
/// macOS system sounds through AppKit. A headless campaign makes no noise.
enum GameSound {
    case build
    case train
    case trade
    case capture
    case failure
    case battleLand, battleHit, battleGateBreak, battleVictory, battleDefeat

    func play() {}
}
