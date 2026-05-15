import Foundation

enum BuildingKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case house
    case farm
    case woodMill
    case coalMine
    case lab
    case barracks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .house: "House"
        case .farm: "Farm"
        case .woodMill: "Wood Mill"
        case .coalMine: "Coal Mine"
        case .lab: "Lab"
        case .barracks: "Barracks"
        }
    }
}

enum PlacementRule: Codable, Equatable, Hashable {
    case none
    case adjacentToBiome(BiomeKind)
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
