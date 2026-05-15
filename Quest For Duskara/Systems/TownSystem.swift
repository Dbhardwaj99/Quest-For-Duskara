import Foundation

struct TownSystem {
    func populationCapacity(for town: Town, balance: GameBalance) -> Int {
        town.buildings.reduce(0) { total, building in
            guard let definition = balance.buildingDefinitions[building.kind] else { return total }
            return total + definition.populationCapacity(for: building.level)
        }
    }

    func usedWorkers(in town: Town, balance: GameBalance) -> Int {
        town.buildings.reduce(0) { total, building in
            total + (balance.buildingDefinitions[building.kind]?.peopleRequired ?? 0)
        }
    }

    func freePeople(in town: Town, balance: GameBalance) -> Int {
        max(0, town.resources[.people] - usedWorkers(in: town, balance: balance))
    }

    func ownedTowns(in state: GameState) -> [Town] {
        state.towns.filter(\.isPlayerControlled)
    }
}
