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

    func militaryManpower(in town: Town, balance: GameBalance) -> Int {
        town.soldierRoster.manpowerCommitted(using: balance.soldierDefinitions)
    }

    func totalPopulation(in town: Town, balance: GameBalance) -> Int {
        town.resources[.people] + militaryManpower(in: town, balance: balance)
    }

    func canAddMilitary(peopleRequired: Int, in town: Town, balance: GameBalance) -> Bool {
        let capacity = max(1, populationCapacity(for: town, balance: balance))
        return militaryManpower(in: town, balance: balance) + peopleRequired <= capacity
    }

    func ownedTowns(in state: GameState, by playerID: String) -> [Town] {
        state.towns(ownedBy: playerID)
    }
}
