import AppKit
import Observation

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

/// One flat bag of colors per theme. Village is the baseline; the other
/// themes override the environmental subset and inherit shared prop colors.
struct WorldPalette {
    // Meadow & foliage
    var grassLight = c(0.55, 0.68, 0.40)
    var grassShadow = c(0.40, 0.55, 0.34)
    var forestMoss = c(0.33, 0.52, 0.38)
    var forestDeep = c(0.22, 0.40, 0.31)
    var leafHighlight = c(0.52, 0.67, 0.38)
    var bark = c(0.42, 0.30, 0.22)
    var rootSoil = c(0.44, 0.38, 0.28)
    var frond = c(0.48, 0.64, 0.36)
    var cactus = c(0.42, 0.62, 0.42)

    // Stone
    var warmStone = c(0.70, 0.66, 0.58)
    var deepStone = c(0.48, 0.52, 0.55)
    var paleStone = c(0.80, 0.77, 0.69)
    var smokeStone = c(0.56, 0.58, 0.60)
    var stoneDust = c(0.60, 0.60, 0.55)
    var peakCap = c(0.90, 0.89, 0.84)
    var crackShadow = c(0.30, 0.33, 0.33)

    // Ground
    var walkedDirt = c(0.58, 0.48, 0.36)
    var fieldDirt = c(0.50, 0.42, 0.30)
    var plinthStone = c(0.62, 0.58, 0.50)

    // Architecture
    var plaster = c(0.93, 0.87, 0.75)
    var terracotta = c(0.79, 0.45, 0.36)
    var terracottaDark = c(0.64, 0.34, 0.27)
    var roofHighlight = c(0.88, 0.56, 0.45)
    var sideShed = c(0.72, 0.58, 0.43)
    var warmWindow = c(1.00, 0.80, 0.47)
    var doorWood = c(0.44, 0.31, 0.22)
    var barnWood = c(0.64, 0.45, 0.32)
    var strawRoof = c(0.86, 0.73, 0.48)
    var strawShadow = c(0.70, 0.58, 0.37)
    var timber = c(0.56, 0.42, 0.29)
    var darkTimber = c(0.38, 0.29, 0.21)
    var cutWood = c(0.73, 0.56, 0.38)
    var sawPlatform = c(0.48, 0.38, 0.27)
    var railWood = c(0.42, 0.36, 0.29)
    var fortifiedClay = c(0.72, 0.48, 0.41)
    var slateRoof = c(0.44, 0.50, 0.54)

    // Crops & props
    var cropGold = c(0.88, 0.75, 0.44)
    var cropGreen = c(0.55, 0.67, 0.38)
    var mushroomCap = c(0.82, 0.42, 0.35)
    var sackCloth = c(0.76, 0.64, 0.46)
    var lanternGlow = c(1.00, 0.72, 0.36)
    var bannerRed = c(0.78, 0.38, 0.32)
    var warmGold = c(0.88, 0.72, 0.42)

    // Mine & lab
    var coalDust = c(0.28, 0.29, 0.31)
    var coalChunk = c(0.16, 0.17, 0.19)
    var mineMouth = c(0.14, 0.15, 0.17)
    var tunnelShadow = c(0.07, 0.08, 0.09)
    var labStone = c(0.62, 0.74, 0.70)
    var labStoneDark = c(0.45, 0.58, 0.57)
    var glassGlow = c(0.62, 0.86, 0.82)
    var arcaneBlue = c(0.36, 0.62, 0.66)
    var cauldron = c(0.32, 0.40, 0.39)
    var potionPurple = c(0.62, 0.54, 0.78)

    // Water
    var waterSheen = NSColor(red: 0.72, green: 0.86, blue: 0.86, alpha: 0.45)
    var waterOpen = c(0.28, 0.56, 0.62)
    var waterShadow = c(0.20, 0.44, 0.52)
    var tileWater = c(0.24, 0.50, 0.58)

    // Environment
    var sky = c(0.55, 0.70, 0.80)
    var sun = c(1.00, 0.87, 0.66)
    var duskTint = c(0.50, 0.58, 0.68)
    // Sandy tropical coastline: the earth plate and skirt read as beach.
    var earth = c(0.87, 0.76, 0.53)
    var skirt = c(0.93, 0.83, 0.58)
    var cloud = c(0.93, 0.93, 0.90)
    var cloudShadow = c(0.76, 0.80, 0.84)

    // Terrain ring & backdrop
    var terrainForestDark = c(0.20, 0.38, 0.30)
    var terrainForestLight = c(0.38, 0.52, 0.32)
    var terrainMountain = c(0.62, 0.60, 0.54)
    var terrainPlains = c(0.55, 0.64, 0.38)
    var terrainRiver = c(0.46, 0.68, 0.72)
    var baseForest = c(0.24, 0.42, 0.32)
    var baseMountain = c(0.55, 0.56, 0.54)
    var basePlains = c(0.48, 0.60, 0.36)
    var baseRiver = c(0.22, 0.50, 0.58)
    var tileGround = c(0.47, 0.60, 0.36)

    static let village = WorldPalette()

    static let desert: WorldPalette = {
        var p = WorldPalette()
        p.grassLight = c(0.85, 0.75, 0.52)
        p.grassShadow = c(0.74, 0.62, 0.42)
        p.forestMoss = c(0.55, 0.66, 0.42)
        p.forestDeep = c(0.40, 0.54, 0.36)
        p.leafHighlight = c(0.68, 0.76, 0.46)
        p.bark = c(0.60, 0.46, 0.32)
        p.rootSoil = c(0.78, 0.65, 0.45)
        p.frond = c(0.50, 0.66, 0.40)
        p.cactus = c(0.45, 0.63, 0.42)
        p.warmStone = c(0.86, 0.70, 0.50)
        p.deepStone = c(0.70, 0.54, 0.40)
        p.paleStone = c(0.93, 0.82, 0.62)
        p.smokeStone = c(0.78, 0.62, 0.48)
        p.stoneDust = c(0.85, 0.74, 0.55)
        p.peakCap = c(0.96, 0.87, 0.68)
        p.crackShadow = c(0.52, 0.40, 0.30)
        p.walkedDirt = c(0.82, 0.70, 0.50)
        p.fieldDirt = c(0.74, 0.60, 0.42)
        p.plinthStone = c(0.80, 0.68, 0.50)
        p.plaster = c(0.94, 0.82, 0.64)
        p.terracotta = c(0.82, 0.54, 0.38)
        p.terracottaDark = c(0.68, 0.42, 0.30)
        p.roofHighlight = c(0.92, 0.66, 0.46)
        p.sideShed = c(0.84, 0.68, 0.48)
        p.barnWood = c(0.72, 0.54, 0.38)
        p.strawRoof = c(0.90, 0.78, 0.52)
        p.strawShadow = c(0.76, 0.64, 0.42)
        p.fortifiedClay = c(0.82, 0.58, 0.42)
        p.slateRoof = c(0.72, 0.52, 0.38)
        p.cropGold = c(0.90, 0.78, 0.46)
        p.cropGreen = c(0.62, 0.68, 0.40)
        p.mushroomCap = c(0.84, 0.56, 0.36)
        p.waterOpen = c(0.30, 0.62, 0.62)
        p.waterShadow = c(0.22, 0.50, 0.54)
        p.tileWater = c(0.28, 0.56, 0.60)
        p.sky = c(0.85, 0.76, 0.60)
        p.sun = c(1.00, 0.85, 0.58)
        p.duskTint = c(0.80, 0.70, 0.58)
        p.earth = c(0.88, 0.75, 0.50)
        p.skirt = c(0.94, 0.82, 0.55)
        p.cloud = c(0.96, 0.92, 0.84)
        p.cloudShadow = c(0.86, 0.78, 0.68)
        p.terrainForestDark = c(0.44, 0.56, 0.36)
        p.terrainForestLight = c(0.62, 0.66, 0.42)
        p.terrainMountain = c(0.85, 0.70, 0.50)
        p.terrainPlains = c(0.88, 0.78, 0.55)
        p.terrainRiver = c(0.48, 0.72, 0.72)
        p.baseForest = c(0.60, 0.62, 0.40)
        p.baseMountain = c(0.78, 0.62, 0.44)
        p.basePlains = c(0.86, 0.74, 0.52)
        p.baseRiver = c(0.28, 0.56, 0.60)
        p.tileGround = c(0.84, 0.73, 0.51)
        return p
    }()

    static let mountains: WorldPalette = {
        var p = WorldPalette()
        p.grassLight = c(0.55, 0.66, 0.48)
        p.grassShadow = c(0.42, 0.54, 0.42)
        p.forestMoss = c(0.28, 0.46, 0.42)
        p.forestDeep = c(0.18, 0.35, 0.33)
        p.leafHighlight = c(0.42, 0.58, 0.48)
        p.bark = c(0.38, 0.30, 0.26)
        p.rootSoil = c(0.46, 0.42, 0.36)
        p.frond = c(0.30, 0.48, 0.44)
        p.cactus = c(0.34, 0.52, 0.46)
        p.warmStone = c(0.66, 0.68, 0.72)
        p.deepStone = c(0.44, 0.48, 0.56)
        p.paleStone = c(0.85, 0.87, 0.90)
        p.smokeStone = c(0.56, 0.60, 0.66)
        p.stoneDust = c(0.64, 0.66, 0.68)
        p.peakCap = c(0.96, 0.97, 1.00)
        p.crackShadow = c(0.34, 0.38, 0.44)
        p.walkedDirt = c(0.56, 0.52, 0.46)
        p.fieldDirt = c(0.48, 0.46, 0.40)
        p.plinthStone = c(0.66, 0.66, 0.68)
        p.plaster = c(0.84, 0.84, 0.86)
        p.terracotta = c(0.46, 0.54, 0.64)
        p.terracottaDark = c(0.36, 0.44, 0.54)
        p.roofHighlight = c(0.58, 0.66, 0.76)
        p.sideShed = c(0.62, 0.60, 0.56)
        p.barnWood = c(0.55, 0.44, 0.34)
        p.strawRoof = c(0.72, 0.64, 0.48)
        p.strawShadow = c(0.58, 0.52, 0.38)
        p.fortifiedClay = c(0.60, 0.58, 0.58)
        p.slateRoof = c(0.38, 0.44, 0.54)
        p.waterOpen = c(0.30, 0.56, 0.66)
        p.waterShadow = c(0.22, 0.44, 0.56)
        p.tileWater = c(0.26, 0.48, 0.58)
        p.sky = c(0.66, 0.76, 0.86)
        p.sun = c(0.95, 0.92, 0.84)
        p.duskTint = c(0.62, 0.70, 0.80)
        p.earth = c(0.84, 0.75, 0.55)
        p.skirt = c(0.90, 0.81, 0.60)
        p.cloud = c(0.97, 0.97, 0.98)
        p.cloudShadow = c(0.80, 0.84, 0.90)
        p.terrainForestDark = c(0.20, 0.38, 0.35)
        p.terrainForestLight = c(0.36, 0.50, 0.42)
        p.terrainMountain = c(0.72, 0.74, 0.78)
        p.terrainPlains = c(0.52, 0.62, 0.46)
        p.terrainRiver = c(0.50, 0.70, 0.76)
        p.baseForest = c(0.22, 0.40, 0.36)
        p.baseMountain = c(0.64, 0.66, 0.70)
        p.basePlains = c(0.48, 0.58, 0.44)
        p.baseRiver = c(0.24, 0.48, 0.58)
        p.tileGround = c(0.50, 0.60, 0.45)
        return p
    }()

    static let forest: WorldPalette = {
        var p = WorldPalette()
        p.grassLight = c(0.38, 0.55, 0.33)
        p.grassShadow = c(0.26, 0.43, 0.29)
        p.forestMoss = c(0.20, 0.42, 0.30)
        p.forestDeep = c(0.12, 0.30, 0.24)
        p.leafHighlight = c(0.36, 0.54, 0.30)
        p.bark = c(0.34, 0.25, 0.19)
        p.rootSoil = c(0.32, 0.28, 0.21)
        p.frond = c(0.30, 0.50, 0.28)
        p.cactus = c(0.34, 0.55, 0.36)
        p.warmStone = c(0.56, 0.56, 0.48)
        p.deepStone = c(0.38, 0.42, 0.40)
        p.paleStone = c(0.66, 0.66, 0.56)
        p.smokeStone = c(0.44, 0.48, 0.46)
        p.stoneDust = c(0.46, 0.48, 0.42)
        p.peakCap = c(0.72, 0.74, 0.66)
        p.crackShadow = c(0.24, 0.28, 0.26)
        p.walkedDirt = c(0.44, 0.37, 0.28)
        p.fieldDirt = c(0.38, 0.32, 0.23)
        p.plinthStone = c(0.50, 0.48, 0.40)
        p.plaster = c(0.82, 0.74, 0.60)
        p.terracotta = c(0.42, 0.54, 0.34)
        p.terracottaDark = c(0.32, 0.44, 0.28)
        p.roofHighlight = c(0.54, 0.64, 0.40)
        p.sideShed = c(0.58, 0.46, 0.34)
        p.barnWood = c(0.50, 0.36, 0.26)
        p.strawRoof = c(0.68, 0.60, 0.38)
        p.strawShadow = c(0.54, 0.48, 0.30)
        p.fortifiedClay = c(0.54, 0.44, 0.36)
        p.slateRoof = c(0.34, 0.42, 0.38)
        p.cropGold = c(0.78, 0.68, 0.40)
        p.cropGreen = c(0.44, 0.58, 0.32)
        p.mushroomCap = c(0.85, 0.40, 0.33)
        p.waterOpen = c(0.22, 0.50, 0.52)
        p.waterShadow = c(0.16, 0.40, 0.44)
        p.tileWater = c(0.20, 0.42, 0.48)
        p.sky = c(0.52, 0.66, 0.62)
        p.sun = c(0.92, 0.90, 0.72)
        p.duskTint = c(0.42, 0.54, 0.52)
        p.earth = c(0.82, 0.72, 0.50)
        p.skirt = c(0.88, 0.78, 0.55)
        p.cloud = c(0.86, 0.90, 0.86)
        p.cloudShadow = c(0.68, 0.76, 0.74)
        p.terrainForestDark = c(0.12, 0.30, 0.24)
        p.terrainForestLight = c(0.28, 0.44, 0.26)
        p.terrainMountain = c(0.50, 0.52, 0.46)
        p.terrainPlains = c(0.36, 0.50, 0.30)
        p.terrainRiver = c(0.38, 0.60, 0.60)
        p.baseForest = c(0.15, 0.33, 0.25)
        p.baseMountain = c(0.44, 0.47, 0.42)
        p.basePlains = c(0.30, 0.45, 0.28)
        p.baseRiver = c(0.18, 0.42, 0.48)
        p.tileGround = c(0.32, 0.47, 0.28)
        return p
    }()
}

private func c(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(red: red, green: green, blue: blue, alpha: 1)
}
