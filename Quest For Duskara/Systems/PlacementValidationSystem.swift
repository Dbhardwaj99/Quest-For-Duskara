import Foundation

struct PlacementValidationSystem {
    private let biomeSystem = BiomeSystem()
    private let townSystem = TownSystem()

    func canPlace(_ kind: BuildingKind, on coordinate: GridCoordinate, in town: Town, balance: GameBalance) -> BuildingSystem.BuildFailure? {
        guard balance.gridSize.contains(coordinate) else { return .outOfBounds }
        guard town.buildings.contains(where: { $0.coordinate == coordinate }) == false else { return .occupied }
        guard let definition = balance.buildingDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.cost(for: 1)) else { return .insufficientResources }
        guard townSystem.freePeople(in: town, balance: balance) >= definition.peopleRequired else { return .insufficientPeople }

        for rule in definition.placementRules where rule != .none {
            guard satisfies(rule, at: coordinate, in: town, gridSize: balance.gridSize) else { return .placementRule }
        }
        return nil
    }

    func validCoordinates(for kind: BuildingKind, in town: Town, balance: GameBalance) -> Set<GridCoordinate> {
        var coordinates: Set<GridCoordinate> = []
        for y in 0..<balance.gridSize.rows {
            for x in 0..<balance.gridSize.columns {
                let coordinate = GridCoordinate(x: x, y: y)
                if canPlace(kind, on: coordinate, in: town, balance: balance) == nil {
                    coordinates.insert(coordinate)
                }
            }
        }
        return coordinates
    }

    private func satisfies(_ rule: PlacementRule, at coordinate: GridCoordinate, in town: Town, gridSize: GridSize) -> Bool {
        switch rule {
        case .none:
            return true
        case .adjacentToBiome(let biome):
            return biomeSystem.isAdjacent(to: biome, from: coordinate, in: town, gridSize: gridSize)
        }
    }
}
