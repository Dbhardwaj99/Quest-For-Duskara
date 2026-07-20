import AppKit

enum WorldTheme: String, CaseIterable {
    case village
    case desert
    case mountains
    case forest

    // Written from ThemeManager (main actor) only; read during main-thread rendering.
    nonisolated(unsafe) static var current: WorldTheme = .village

    var displayName: String {
        switch self {
        case .village: "Village"
        case .desert: "Desert"
        case .mountains: "Mountains"
        case .forest: "Forest"
        }
    }

    var next: WorldTheme {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var palette: WorldPalette {
        switch self {
        case .village: .village
        case .desert: .desert
        case .mountains: .mountains
        case .forest: .forest
        }
    }
}
