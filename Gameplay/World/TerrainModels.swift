import Foundation

enum TerrainKind: String, Codable, Equatable, Hashable, CaseIterable {
    case plains
    case forest
    case mountains
    case desert
    case coast

    var title: String {
        switch self {
        case .plains: return "Plains"
        case .forest: return "Forest"
        case .mountains: return "Mountains"
        case .desert: return "Desert"
        case .coast: return "Coast"
        }
    }
}

struct TerrainTile: Identifiable, Codable, Equatable {
    var cell: MapCell
    var terrain: TerrainKind

    var id: String {
        cell.id
    }
}
