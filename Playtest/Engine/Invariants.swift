import Foundation

extension PlaytestSession {
    /// States the rules should never reach (violations), and states they allow
    /// but that look wrong (anomalies). Each names the island and the numbers.
    func ruleChecks() -> (violations: [String], anomalies: [String]) {
        var violations: [String] = []
        var anomalies: [String] = []
        let state = game.state
        let balance = game.balance
        let definitions = balance.soldierDefinitions
        let grid = balance.gridSize

        if game.phase == .town {
            if state.towns.contains(where: \.isPlayerControlled) == false {
                violations.append("You hold no island, but the campaign hasn't ended.")
            } else if state.town(id: state.activeTownID)?.isPlayerControlled != true {
                violations.append("The active island isn't yours.")
            }
        }
        if game.phase == .victory, state.towns.first(where: \.isDuskara)?.isPlayerControlled != true {
            violations.append("The campaign was won, but Duskara isn't yours.")
        }

        for town in state.towns {
            let name = town.name
            for (kind, amount) in town.resources.amounts where amount < 0 {
                violations.append("\(name) has \(amount) \(kind.rawValue).")
            }
            for (kind, count) in town.soldierRoster.counts where count < 0 {
                violations.append("\(name) has \(count) \(kind.rawValue)s.")
            }
            let unitPower = town.soldierRoster.armyStrength(using: definitions)
            if town.resources[.soldiers] != town.armyStrength {
                violations.append("\(name) shows \(town.resources[.soldiers]) soldiers but has \(town.armyStrength) army strength.")
            }
            if town.armyStrength < unitPower {
                violations.append("\(name)'s army strength \(town.armyStrength) is below its units' power \(unitPower).")
            } else if town.armyStrength > unitPower {
                anomalies.append("\(name) has \(town.armyStrength) army strength but its units add up to \(unitPower): the rest is no soldier at all, and a lane battle rounds it up into whole units.")
            }

            var plots = Set<GridCoordinate>()
            for building in town.buildings {
                let place = "\(building.kind.title) at \(building.coordinate.x),\(building.coordinate.y)"
                if grid.contains(building.coordinate) == false { violations.append("\(name): \(place) is off the board.") }
                if plots.insert(building.coordinate).inserted == false { violations.append("\(name): two buildings share plot \(building.coordinate.x),\(building.coordinate.y).") }
                let maxLevel = balance.buildingDefinitions[building.kind]?.maxLevel ?? 1
                if (1...maxLevel).contains(building.level) == false {
                    violations.append("\(name): \(place) is level \(building.level) (allowed 1–\(maxLevel)).")
                }
            }
            if town.buildings.filter({ $0.kind == .pier }).count > 1 { violations.append("\(name) has more than one Pier.") }

            let capacity = GameRules.populationCapacity(town, balance: balance)
            let housed = town.resources[.people] + town.soldierRoster.manpowerCommitted(using: definitions)
            if housed > capacity {
                anomalies.append("\(name) houses \(housed) (people plus soldiers) in room for \(capacity).")
            }
            let workers = town.buildings.reduce(0) { $0 + (balance.buildingDefinitions[$1.kind]?.peopleRequired ?? 0) }
            if town.isPlayerControlled, town.resources[.people] < workers {
                anomalies.append("\(name)'s buildings need \(workers) workers but only \(town.resources[.people]) people live there; they keep producing anyway.")
            }
        }
        return (violations, anomalies)
    }
}
