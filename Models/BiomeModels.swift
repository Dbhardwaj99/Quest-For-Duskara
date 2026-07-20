import Foundation

enum BiomeKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case forest
    case mountain
    case plains
    case river

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forest: "Forest"
        case .mountain: "Mountain"
        case .plains: "Plains"
        case .river: "River"
        }
    }
}

enum BiomeSide: String, CaseIterable, Identifiable, Codable, Hashable {
    case top
    case right
    case bottom
    case left

    var id: String { rawValue }
}

struct TownBiomeLayout: Codable, Equatable {
    var sides: [BiomeSide: BiomeKind]

    init(sides: [BiomeSide: BiomeKind]) {
        self.sides = sides
    }

    func biome(on side: BiomeSide) -> BiomeKind? {
        sides[side]
    }
}

struct GridCoordinate: Codable, Hashable, Identifiable {
    var x: Int
    var y: Int

    var id: String { "\(x)-\(y)" }
}

struct GridSize: Codable, Equatable {
    var columns: Int
    var rows: Int

    func contains(_ coordinate: GridCoordinate) -> Bool {
        coordinate.x >= 0 && coordinate.x < columns && coordinate.y >= 0 && coordinate.y < rows
    }
}
