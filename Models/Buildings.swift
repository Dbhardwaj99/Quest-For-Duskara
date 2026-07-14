import Foundation

enum TilePlacementState: Equatable {
    case normal
    case valid
    case invalid
}

enum BuildingKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case house
    case pier
    case farm
    case factory
    case barracks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .house: "House"
        case .pier: "Pier"
        case .farm: "Farm"
        case .factory: "Factory"
        case .barracks: "Barracks"
        }
    }
}

enum PlacementRule: Codable, Equatable, Hashable {
    case none
    /// Only tiles on the town board's outer ring qualify. Every town is an
    /// island, so the board's edge is its shoreline.
    case onTownEdge
}

struct BuildingDefinition: Identifiable, Codable, Equatable {
    var id: BuildingKind { kind }
    var kind: BuildingKind
    var summary: String
    var baseCost: [ResourceKind: Int]
    var baseProduction: [ResourceKind: Int]
    var peopleRequired: Int
    var peopleOnBuild: Int
    var populationCapacity: Int
    var maxLevel: Int
    var placementRules: [PlacementRule]

    func cost(for level: Int) -> [ResourceKind: Int] {
        let multiplier = max(1, level)
        return baseCost.mapValues { $0 * multiplier }
    }

    func production(for level: Int) -> [ResourceKind: Int] {
        let multiplier = max(1, level)
        return baseProduction.mapValues { $0 * multiplier }
    }

    func populationCapacity(for level: Int) -> Int {
        populationCapacity * max(1, level)
    }

    func peopleOnBuild(for level: Int) -> Int {
        peopleOnBuild * max(1, level)
    }
}

struct BuildingInstance: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var kind: BuildingKind
    var coordinate: GridCoordinate
    var level: Int

    init(id: UUID = UUID(), kind: BuildingKind, coordinate: GridCoordinate, level: Int = 1) {
        self.id = id
        self.kind = kind
        self.coordinate = coordinate
        self.level = level
    }
}
