import AppKit

/// Placeholder effects from the macOS system sounds, so the game isn't silent
/// while it has no audio assets of its own.
// ponytail: system sounds; swap in bundled effects when the game has them.
enum GameSound: String {
    case build = "Pop"
    case train = "Tink"
    case trade = "Glass"
    case capture = "Hero"
    case failure = "Basso"

    static let mutedKey = "isSoundMuted"

    func play() {
        guard UserDefaults.standard.bool(forKey: Self.mutedKey) == false else { return }
        NSSound(named: NSSound.Name(rawValue))?.play()
    }
}
