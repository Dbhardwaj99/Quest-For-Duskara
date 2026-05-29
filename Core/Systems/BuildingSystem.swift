import Foundation

struct BuildingSystem {
    enum BuildFailure: String, Identifiable {
        case occupied = "That plot is already occupied."
        case outOfBounds = "That plot is outside the town grid."
        case insufficientResources = "Not enough resources."
        case insufficientPeople = "Not enough free people."
        case placementRule = "This building must touch the right biome border."
        case maxLevel = "This building is already fully upgraded."
        case missingDefinition = "Missing building definition."

        var id: String { rawValue }
    }

    func income(for town: Town, balance: GameBalance) -> [ResourceKind: Int] {
        var total: [ResourceKind: Int] = [:]
        for building in town.buildings {
            guard let definition = balance.buildingDefinitions[building.kind] else { continue }
            for (kind, amount) in definition.production(for: building.level) {
                total[kind, default: 0] += amount
            }
        }
        return total
    }

    func canBuild(_ kind: BuildingKind, at coordinate: GridCoordinate, in town: Town, balance: GameBalance) -> BuildFailure? {
        PlacementValidationSystem().canPlace(kind, on: coordinate, in: town, balance: balance)
    }

    func build(_ kind: BuildingKind, at coordinate: GridCoordinate, in town: inout Town, balance: GameBalance) -> BuildFailure? {
        if let failure = canBuild(kind, at: coordinate, in: town, balance: balance) {
            return failure
        }
        guard let definition = balance.buildingDefinitions[kind] else { return .missingDefinition }
        _ = town.resources.spend(definition.cost(for: 1))
        town.buildings.append(BuildingInstance(kind: kind, coordinate: coordinate))
        if definition.peopleOnBuild > 0 {
            town.resources.add(.people, amount: definition.peopleOnBuild)
        }
        return nil
    }

    func upgrade(_ buildingID: UUID, in town: inout Town, balance: GameBalance) -> BuildFailure? {
        guard let index = town.buildings.firstIndex(where: { $0.id == buildingID }) else { return .missingDefinition }
        let building = town.buildings[index]
        guard let definition = balance.buildingDefinitions[building.kind] else { return .missingDefinition }
        guard building.level < definition.maxLevel else { return .maxLevel }
        let cost = definition.cost(for: building.level + 1)
        guard town.resources.canAfford(cost) else { return .insufficientResources }
        _ = town.resources.spend(cost)
        town.buildings[index].level += 1
        if definition.peopleOnBuild > 0 {
            town.resources.add(.people, amount: definition.peopleOnBuild(for: town.buildings[index].level))
        }
        return nil
    }

}
