import Foundation

struct CombatSystem {
    func effectiveDefenseStrength(
        for town: Town,
        in state: GameState,
        balance: GameBalance
    ) -> Int {
        let garrison = town.armyStrength
        var bonus = Int((Double(garrison) * balance.garrisonDefenseBonusRate).rounded())

        if town.isDuskara {
            bonus += balance.duskaraDefenseBonus
        } else if isImportantCity(town) {
            bonus += balance.importantCityDefenseBonus
        }

        if let duskaraID = state.towns.first(where: \.isDuskara)?.id {
            let distances = graphDistances(from: duskaraID, connections: state.connections)
            let distance = distances[town.id] ?? 0
            let maxDistance = max(distances.values.max() ?? 1, 1)
            let stepsFromEdge = max(0, maxDistance - distance)
            bonus += stepsFromEdge * balance.defenseBonusPerStepFromDuskara
        }

        return garrison + bonus
    }

    func winnerSurvivors(
        attackStrength: Int,
        effectiveDefense: Int,
        balance: GameBalance
    ) -> Int {
        let rawSurvivors = attackStrength - effectiveDefense
        guard rawSurvivors > 0 else { return 0 }
        let casualties = max(1, Int((Double(rawSurvivors) * balance.combatWinnerCasualtyRate).rounded()))
        return max(1, rawSurvivors - casualties)
    }

    private func isImportantCity(_ town: Town) -> Bool {
        town.isDuskara || town.faction == .enemy
    }

    private func graphDistances(from sourceID: UUID, connections: [TownConnection]) -> [UUID: Int] {
        var distances: [UUID: Int] = [sourceID: 0]
        var queue = [sourceID]
        var cursor = 0

        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            let nextDistance = (distances[current] ?? 0) + 1
            for connection in connections where connection.contains(current) {
                let next = connection.from == current ? connection.to : connection.from
                guard distances[next] == nil else { continue }
                distances[next] = nextDistance
                queue.append(next)
            }
        }
        return distances
    }
}
