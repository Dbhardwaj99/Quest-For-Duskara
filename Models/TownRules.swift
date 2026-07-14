import Foundation

enum GameRules {
    enum BuildFailure: String {
        case occupied = "That plot is already occupied."
        case outOfBounds = "That plot is outside the town grid."
        case insufficientResources = "Not enough resources."
        case insufficientPeople = "Not enough free people."
        case placementRule = "This building must be placed on the town's edge, by the water."
        case duplicatePier = "This town already has a Pier."
        case maxLevel = "This building is already fully upgraded."
        case missingDefinition = "Missing building definition."
    }

    enum TrainingFailure: String {
        case noBarracks = "Build a barracks before training soldiers."
        case insufficientResources = "Not enough resources to train that soldier."
        case insufficientPeople = "Not enough free people to train that soldier."
        case militaryCapReached = "Army size is at the population cap for this town."
        case missingDefinition = "Missing soldier definition."
    }

    static func populationCapacity(_ town: Town, balance: GameBalance) -> Int {
        town.buildings.reduce(0) { total, building in
            total + (balance.buildingDefinitions[building.kind]?.populationCapacity(for: building.level) ?? 0)
        }
    }

    static func freePeople(_ town: Town, balance: GameBalance) -> Int {
        let workers = town.buildings.reduce(0) {
            $0 + (balance.buildingDefinitions[$1.kind]?.peopleRequired ?? 0)
        }
        return max(0, town.resources[.people] - workers)
    }

    static func income(_ town: Town, balance: GameBalance) -> [ResourceKind: Int] {
        town.buildings.reduce(into: [:]) { total, building in
            for (kind, amount) in production(building, in: town, balance: balance) {
                total[kind, default: 0] += amount
            }
        }
    }

    static func production(_ building: BuildingInstance, in town: Town, balance: GameBalance) -> [ResourceKind: Int] {
        balance.buildingDefinitions[building.kind]?.production(for: building.level) ?? [:]
    }

    static func placementFailure(
        for kind: BuildingKind,
        at coordinate: GridCoordinate,
        in town: Town,
        balance: GameBalance
    ) -> BuildFailure? {
        guard balance.gridSize.contains(coordinate) else { return .outOfBounds }
        guard town.buildings.contains(where: { $0.coordinate == coordinate }) == false else { return .occupied }
        if kind == .pier, town.buildings.contains(where: { $0.kind == .pier }) { return .duplicatePier }
        guard let definition = balance.buildingDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.cost(for: 1)) else { return .insufficientResources }
        guard freePeople(town, balance: balance) >= definition.peopleRequired else { return .insufficientPeople }
        if definition.placementRules.contains(.onTownEdge) {
            let isEdge = coordinate.x == 0 || coordinate.y == 0
                || coordinate.x == balance.gridSize.columns - 1
                || coordinate.y == balance.gridSize.rows - 1
            guard isEdge else { return .placementRule }
        }
        return nil
    }

    static func validCoordinates(for kind: BuildingKind, in town: Town, balance: GameBalance) -> Set<GridCoordinate> {
        Set((0..<balance.gridSize.rows).flatMap { y in
            (0..<balance.gridSize.columns).compactMap { x in
                let coordinate = GridCoordinate(x: x, y: y)
                return placementFailure(for: kind, at: coordinate, in: town, balance: balance) == nil ? coordinate : nil
            }
        })
    }

    static func build(_ kind: BuildingKind, at coordinate: GridCoordinate, in town: inout Town, balance: GameBalance) -> BuildFailure? {
        if let failure = placementFailure(for: kind, at: coordinate, in: town, balance: balance) { return failure }
        guard let definition = balance.buildingDefinitions[kind] else { return .missingDefinition }
        _ = town.resources.spend(definition.cost(for: 1))
        town.buildings.append(BuildingInstance(kind: kind, coordinate: coordinate))
        town.resources.add(.people, amount: definition.peopleOnBuild)
        return nil
    }

    static func upgrade(_ buildingID: UUID, in town: inout Town, balance: GameBalance) -> BuildFailure? {
        guard let index = town.buildings.firstIndex(where: { $0.id == buildingID }),
              let definition = balance.buildingDefinitions[town.buildings[index].kind] else { return .missingDefinition }
        guard town.buildings[index].level < definition.maxLevel else { return .maxLevel }
        let cost = definition.cost(for: town.buildings[index].level + 1)
        guard town.resources.spend(cost) else { return .insufficientResources }
        town.buildings[index].level += 1
        town.resources.add(.people, amount: definition.peopleOnBuild(for: town.buildings[index].level))
        return nil
    }

    static func trainingFailure(for kind: SoldierKind, in town: Town, balance: GameBalance) -> TrainingFailure? {
        guard town.buildings.contains(where: { $0.kind == .barracks }) else { return .noBarracks }
        guard let definition = balance.soldierDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.trainingCost) else { return .insufficientResources }
        guard freePeople(town, balance: balance) >= definition.peopleRequired else { return .insufficientPeople }
        let committed = town.soldierRoster.manpowerCommitted(using: balance.soldierDefinitions)
        guard committed + definition.peopleRequired <= max(1, populationCapacity(town, balance: balance)) else {
            return .militaryCapReached
        }
        return nil
    }

    static func train(_ kind: SoldierKind, in town: inout Town, balance: GameBalance) -> TrainingFailure? {
        if let failure = trainingFailure(for: kind, in: town, balance: balance) { return failure }
        guard let definition = balance.soldierDefinitions[kind] else { return .missingDefinition }
        _ = town.resources.spend(definition.trainingCost)
        town.resources.add(.people, amount: -definition.peopleRequired)
        town.soldierRoster.add(kind, count: 1)
        syncArmy(&town, balance: balance)
        return nil
    }

    static func syncArmy(_ town: inout Town, balance: GameBalance) {
        let strength = town.soldierRoster.armyStrength(using: balance.soldierDefinitions)
        if strength > 0 { town.armyStrength = strength }
        town.resources[.soldiers] = town.armyStrength
    }

    static func dailyFood(_ town: Town, balance: GameBalance) -> Int {
        let rosterFood = town.soldierRoster.counts.reduce(0) {
            $0 + $1.value * (balance.soldierDefinitions[$1.key]?.dailyFoodUpkeep ?? 0)
        }
        if rosterFood > 0 { return rosterFood }
        guard town.armyStrength > 0 else { return 0 }
        let upkeep = balance.soldierDefinitions[.archer]?.dailyFoodUpkeep ?? 2
        let power = balance.soldierDefinitions[.archer]?.power ?? 10
        return max(1, Int(ceil(Double(town.armyStrength) / Double(power)))) * upkeep
    }

    static func applyUpkeep(to town: inout Town, balance: GameBalance) {
        var shortfall = dailyFood(town, balance: balance)
        if town.resources[.food] >= shortfall {
            town.resources.add(.food, amount: -shortfall)
            return
        }
        town.resources[.food] = 0
        while shortfall > 0, town.armyStrength > 0 {
            if let kind = town.soldierRoster.removeHighestUpkeepUnit(using: balance.soldierDefinitions) {
                let soldier = balance.soldierDefinitions[kind]
                town.armyStrength = max(0, town.armyStrength - (soldier?.power ?? 0))
                town.resources.add(.people, amount: soldier?.peopleRequired ?? 0)
                shortfall -= soldier?.dailyFoodUpkeep ?? 0
            } else {
                town.armyStrength = max(0, town.armyStrength - (balance.soldierDefinitions[.archer]?.power ?? 10))
                shortfall -= balance.soldierDefinitions[.archer]?.dailyFoodUpkeep ?? 2
            }
        }
        town.resources[.soldiers] = town.armyStrength
    }

    static func hasStableEconomy(_ town: Town, balance: GameBalance) -> Bool {
        let foodSurplus = income(town, balance: balance)[.food, default: 0] - dailyFood(town, balance: balance)
        return town.resources[.food] >= balance.aiMinimumFoodReserve
            && town.resources[.gold] >= balance.aiMinimumGoldReserve
            && foodSurplus > 0
    }
}
