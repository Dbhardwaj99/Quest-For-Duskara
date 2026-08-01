import Foundation

extension GameRules {
    static func defense(_ town: Town, in state: GameState, balance: GameBalance) -> Int {
        let garrison = town.armyStrength
        var bonus = Int((Double(garrison) * balance.garrisonDefenseBonusRate).rounded())
        if town.isDuskara { bonus += balance.duskaraDefenseBonus }
        if let duskara = state.towns.first(where: \.isDuskara)?.id {
            let distances = graphDistances(from: duskara, connections: state.connections)
            let maxDistance = max(distances.values.max() ?? 1, 1)
            bonus += max(0, maxDistance - (distances[town.id] ?? 0)) * balance.defenseBonusPerStepFromDuskara
        }
        return garrison + bonus
    }

    static func canAttack(_ targetID: UUID, from sourceID: UUID, in state: GameState, balance: GameBalance) -> Bool {
        guard let source = state.town(id: sourceID), source.isPlayerControlled,
              let target = state.town(id: targetID), target.isPlayerControlled == false else { return false }
        return source.armyStrength > defense(target, in: state, balance: balance)
    }

    static func attack(_ targetID: UUID, from sourceID: UUID, state: inout GameState, balance: GameBalance) -> Bool {
        guard canAttack(targetID, from: sourceID, in: state, balance: balance),
              let source = state.towns.firstIndex(where: { $0.id == sourceID }),
              let target = state.towns.firstIndex(where: { $0.id == targetID }) else { return false }
        return resolveAttack(source: source, target: target, faction: .player, realmID: state.towns[source].realmID,
                             strength: state.towns[source].armyStrength, state: &state, balance: balance)
    }

    static func resolveAttack(
        source: Int,
        target: Int,
        faction: TownFaction,
        realmID: UUID,
        strength: Int,
        state: inout GameState,
        balance: GameBalance
    ) -> Bool {
        guard source != target, state.towns.indices.contains(source), state.towns.indices.contains(target) else { return false }
        let definitions = balance.soldierDefinitions
        let sourceTown = state.towns[source]
        let requested = min(strength, sourceTown.armyStrength)
        let roster = sourceTown.soldierRoster.fitting(power: requested, using: definitions)
        let rosterPower = roster.armyStrength(using: definitions)
        let legacy = max(0, sourceTown.armyStrength - sourceTown.soldierRoster.armyStrength(using: definitions))
        let attackPower = rosterPower + min(requested - rosterPower, legacy)
        let targetTown = state.towns[target]
        let effectiveDefense = defense(targetTown, in: state, balance: balance)
        let rawSurvivors = attackPower - effectiveDefense
        let casualties = max(1, Int((Double(max(0, rawSurvivors)) * balance.combatWinnerCasualtyRate).rounded()))
        let survivors = rawSurvivors > 0 ? max(1, rawSurvivors - casualties) : 0

        state.towns[source].soldierRoster.subtract(roster)
        state.towns[source].armyStrength = max(0, sourceTown.armyStrength - attackPower)
        state.towns[source].resources[.soldiers] = state.towns[source].armyStrength

        guard survivors > 0 else {
            let reduction = min(attackPower, targetTown.armyStrength)
            state.towns[target].soldierRoster.removeStrength(atLeast: reduction, using: definitions)
            let rosterStrength = state.towns[target].soldierRoster.armyStrength(using: definitions)
            state.towns[target].armyStrength = max(rosterStrength, targetTown.armyStrength - reduction)
            state.towns[target].resources[.soldiers] = state.towns[target].armyStrength
            return false
        }

        for (kind, rate) in balance.captureResourceLossRates {
            state.towns[target].resources[kind] = max(0, Int(Double(state.towns[target].resources[kind]) * (1 - rate)))
        }
        state.towns[target].setFaction(faction)
        state.towns[target].realmID = realmID
        let garrison = SoldierRoster.decompose(strength: survivors, using: definitions)
        state.towns[target].soldierRoster = garrison
        state.towns[target].armyStrength = garrison.armyStrength(using: definitions)
        state.towns[target].resources[.soldiers] = state.towns[target].armyStrength
        let factions = Dictionary(uniqueKeysWithValues: state.towns.map { ($0.id, $0.faction) })
        for index in state.territory.regions.indices {
            state.territory.regions[index].ownerFaction = factions[state.territory.regions[index].townID] ?? .neutral
        }
        return true
    }

    static func graphDistances(from source: UUID, connections: [TownConnection]) -> [UUID: Int] {
        var distances = [source: 0]
        var queue = [source]
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            for connection in connections where connection.contains(current) {
                let next = connection.from == current ? connection.to : connection.from
                guard distances[next] == nil else { continue }
                distances[next] = (distances[current] ?? 0) + 1
                queue.append(next)
            }
        }
        return distances
    }

    static func runEnemyTurn(state: inout GameState, balance: GameBalance) {
        for townID in state.towns.filter({ !$0.isPlayerControlled }).map(\.id) {
            develop(townID, state: &state, balance: balance)
            trainEnemy(townID, state: &state, balance: balance)
            attackFrom(townID, state: &state, balance: balance)
        }
        if state.town(id: state.activeTownID)?.isPlayerControlled != true,
           let next = state.towns.first(where: \.isPlayerControlled) {
            state.activeTownID = next.id
        }
    }

    private static let developmentOrder: [BuildingKind] = [.house, .pier, .farm, .barracks, .factory]

    private static func develop(_ townID: UUID, state: inout GameState, balance: GameBalance) {
        guard let index = state.towns.firstIndex(where: { $0.id == townID }) else { return }
        for kind in developmentOrder
        where state.towns[index].buildings.contains(where: { $0.kind == kind }) == false {
            if let coordinate = nearestValidPlot(for: kind, in: state.towns[index], balance: balance),
               build(kind, at: coordinate, in: &state.towns[index], balance: balance) == nil {
                state.addNews(.buildingConstruction, "\(state.towns[index].name) built a \(kind.title)")
                return
            }
        }
        growWorkforce(index, state: &state, balance: balance)
    }

    /// The plot closest to the town centre, with ties broken by row then column
    /// so the same town state always develops the same way.
    private static func nearestValidPlot(for kind: BuildingKind, in town: Town, balance: GameBalance) -> GridCoordinate? {
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        return validCoordinates(for: kind, in: town, balance: balance).min {
            let left = abs($0.x - center.x) + abs($0.y - center.y)
            let right = abs($1.x - center.x) + abs($1.y - center.y)
            return (left, $0.y, $0.x) < (right, $1.y, $1.x)
        }
    }

    /// Nothing could be built this turn. The build loop never revisits House
    /// once one exists, so a town whose missing infrastructure is gated on
    /// people — rather than on resources — would otherwise stall here forever.
    /// Housing is the only lever that raises the headcount, so add some.
    private static func growWorkforce(_ index: Int, state: inout GameState, balance: GameBalance) {
        let town = state.towns[index]
        let available = freePeople(town, balance: balance)
        let starved = developmentOrder.contains { kind in
            town.buildings.contains(where: { $0.kind == kind }) == false
                && (balance.buildingDefinitions[kind]?.peopleRequired ?? 0) > available
        }
        guard starved else { return }

        if let coordinate = nearestValidPlot(for: .house, in: town, balance: balance),
           build(.house, at: coordinate, in: &state.towns[index], balance: balance) == nil {
            state.addNews(.buildingConstruction, "\(town.name) built a \(BuildingKind.house.title)")
            return
        }
        // Board is full or the plot is unaffordable — grow upward instead.
        guard let house = town.buildings
            .filter({ $0.kind == .house })
            .min(by: { ($0.level, $0.coordinate.y, $0.coordinate.x) < ($1.level, $1.coordinate.y, $1.coordinate.x) }),
              upgrade(house.id, in: &state.towns[index], balance: balance) == nil else { return }
        state.addNews(.buildingConstruction, "\(town.name) expanded a \(BuildingKind.house.title)")
    }

    private static func trainEnemy(_ townID: UUID, state: inout GameState, balance: GameBalance) {
        guard let index = state.towns.firstIndex(where: { $0.id == townID }),
              state.towns[index].buildings.contains(where: { $0.kind == .barracks }) else { return }
        for soldier in [SoldierKind.archer, .knight] {
            if train(soldier, in: &state.towns[index], balance: balance) == nil {
                state.addNews(.soldierTraining, "\(state.towns[index].name) trained a \(soldier.title)")
                return
            }
        }
    }

    private static func attackFrom(_ sourceID: UUID, state: inout GameState, balance: GameBalance) {
        guard let source = state.towns.firstIndex(where: { $0.id == sourceID }),
              hasStableEconomy(state.towns[source], balance: balance),
              state.towns[source].armyStrength > balance.aiReserveThreshold else { return }
        let targets = state.connections.compactMap { connection -> UUID? in
            if connection.from == sourceID { return connection.to }
            if connection.to == sourceID { return connection.from }
            return nil
        }.compactMap { id -> (UUID, Int, Bool)? in
            guard let town = state.town(id: id), town.realmID != state.towns[source].realmID else { return nil }
            let power = defense(town, in: state, balance: balance)
            return state.towns[source].armyStrength > power + balance.aiReserveThreshold ? (id, power, town.isDuskara) : nil
        }.sorted { $0.2 != $1.2 ? $0.2 : ($0.1, $0.0.uuidString) < ($1.1, $1.0.uuidString) }
        guard let chosen = targets.first, let target = state.towns.firstIndex(where: { $0.id == chosen.0 }) else { return }
        let sourceName = state.towns[source].name
        let targetName = state.towns[target].name
        if resolveAttack(source: source, target: target, faction: state.towns[source].faction,
                         realmID: state.towns[source].realmID,
                         strength: state.towns[source].armyStrength - balance.aiReserveThreshold,
                         state: &state, balance: balance) {
            state.addNews(.cityCapture, "\(sourceName) captured \(targetName)")
        }
    }
}
