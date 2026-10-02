import AppKit

/// Placeholder effects from the macOS system sounds, so the game isn't silent
/// while it has no audio assets of its own.
// ponytail: system sounds; swap in bundled effects when the game has them.
enum GameSound {
    case build
    case train
    case trade
    case capture
    case failure
    case battleLand, battleHit, battleGateBreak, battleVictory, battleDefeat

    private var name: String {
        switch self {
        case .build, .battleLand: "Pop"
        case .train, .battleHit: "Tink"
        case .trade: "Glass"
        case .capture, .battleVictory: "Hero"
        case .failure, .battleDefeat: "Basso"
        case .battleGateBreak: "Funk"
        }
    }

    static let mutedKey = "isSoundMuted"

    func play() {
        guard UserDefaults.standard.bool(forKey: Self.mutedKey) == false else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
