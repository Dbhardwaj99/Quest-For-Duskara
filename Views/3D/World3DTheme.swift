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

    // Palettes are built on demand so the contrast knob can retint them, but
    // `Palette` is read once per primitive during a rebuild — so the last one
    // is kept. One entry is enough: only one theme is current at a time.
    nonisolated(unsafe) private static var cached: (theme: WorldTheme, contrast: Double, palette: WorldPalette)?

    var palette: WorldPalette {
        if let cached = Self.cached, cached.theme == self, cached.contrast == WorldContrast.level {
            return cached.palette
        }
        let built: WorldPalette = switch self {
        case .village: .village
        case .desert: .desert
        case .mountains: .mountains
        case .forest: .forest
        }
        Self.cached = (self, WorldContrast.level, built)
        return built
    }
}
