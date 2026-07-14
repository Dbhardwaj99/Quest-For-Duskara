import Observation

@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()
    private(set) var theme: WorldTheme = .village

    private init() {}

    func cycle() {
        theme = theme.next
        WorldTheme.current = theme
    }
}
