import Foundation

struct ArmyUpkeepSystem {
    private let townSystem = TownSystem()

    func dailyFoodRequirement(for town: Town, balance: GameBalance) -> Int {
        let rosterNeed = town.soldierRoster.counts.reduce(0) { partial, entry in
            let upkeep = balance.soldierDefinitions[entry.key]?.dailyFoodUpkeep ?? 0
            return partial + entry.value * upkeep
        }
        if rosterNeed > 0 {
            return rosterNeed
        }
        guard town.armyStrength > 0 else { return 0 }
        let archerUpkeep = balance.soldierDefinitions[.archer]?.dailyFoodUpkeep ?? 2
        let archerPower = balance.soldierDefinitions[.archer]?.power ?? 10
        let estimatedUnits = max(1, Int(ceil(Double(town.armyStrength) / Double(archerPower))))
        return estimatedUnits * archerUpkeep
    }

    func applyDailyUpkeep(to town: inout Town, balance: GameBalance) {
        guard town.armyStrength > 0 else { return }
        let required = dailyFoodRequirement(for: town, balance: balance)
        guard required > 0 else { return }

        if town.resources[.food] >= required {
            town.resources.add(.food, amount: -required)
            return
        }

        town.resources[.food] = 0
        var shortfall = required
        while shortfall > 0, town.armyStrength > 0 {
            if let removedKind = town.soldierRoster.removeHighestUpkeepUnit(using: balance.soldierDefinitions) {
                let definition = balance.soldierDefinitions[removedKind]
                town.armyStrength = max(0, town.armyStrength - (definition?.power ?? 0))
                town.resources.add(.people, amount: definition?.peopleRequired ?? 0)
                shortfall -= definition?.dailyFoodUpkeep ?? 0
            } else {
                let archerPower = balance.soldierDefinitions[.archer]?.power ?? 10
                let archerUpkeep = balance.soldierDefinitions[.archer]?.dailyFoodUpkeep ?? 2
                let archerPeople = balance.soldierDefinitions[.archer]?.peopleRequired ?? 1
                town.armyStrength = max(0, town.armyStrength - archerPower)
                town.resources.add(.people, amount: archerPeople)
                shortfall -= archerUpkeep
            }
        }
        town.resources[.soldiers] = town.armyStrength
    }

    func projectedDailyFoodSurplus(for town: Town, balance: GameBalance) -> Int {
        let buildingSystem = BuildingSystem()
        let income = buildingSystem.income(for: town, balance: balance)
        return income[.food, default: 0] - dailyFoodRequirement(for: town, balance: balance)
    }

    func hasStableEconomy(for town: Town, balance: GameBalance) -> Bool {
        town.resources[.food] >= balance.aiMinimumFoodReserve
            && town.resources[.gold] >= balance.aiMinimumGoldReserve
            && projectedDailyFoodSurplus(for: town, balance: balance) > 0
    }
}
