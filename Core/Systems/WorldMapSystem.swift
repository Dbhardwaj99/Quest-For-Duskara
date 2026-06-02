import Foundation

struct WorldMapSystem {
    private let combatSystem = CombatSystem()
    private let occupationSystem = OccupationSystem()

    func makeInitialState(balance: GameBalance) -> GameState {
        var towns = makeTowns(balance: balance)
        towns[0].faction = .player
        towns[0].resources = ResourceWallet(balance.baseStartingResources)
        towns[0].armyStrength = 0

        let nodes = towns.enumerated().map { index, town in
            WorldTownNode(townID: town.id, x: nodePosition(for: index).0, y: nodePosition(for: index).1)
        }
        let connections = makeConnections(townIDs: towns.map(\.id))
        applyInitialDefenses(to: &towns, connections: connections)

        return GameState(
            day: 1,
            elapsedSecondsInDay: 0,
            towns: towns,
            worldNodes: nodes,
            connections: connections,
            activeTownID: towns[0].id
        )
    }

    func adjacentTownIDs(to townID: UUID, in state: GameState) -> [UUID] {
        state.connections.compactMap { connection in
            if connection.from == townID { return connection.to }
            if connection.to == townID { return connection.from }
            return nil
        }
    }

    func effectiveDefenseStrength(for town: Town, in state: GameState, balance: GameBalance) -> Int {
        combatSystem.effectiveDefenseStrength(for: town, in: state, balance: balance)
    }

    func canAttack(targetID: UUID, from sourceID: UUID, in state: GameState, balance: GameBalance) -> Bool {
        guard let source = state.towns.first(where: { $0.id == sourceID }), source.isPlayerControlled else { return false }
        guard let target = state.towns.first(where: { $0.id == targetID }), target.isPlayerControlled == false else { return false }
        guard state.connections.contains(where: { $0.connects(sourceID, targetID) }) else { return false }
        let defense = effectiveDefenseStrength(for: target, in: state, balance: balance)
        return source.armyStrength > defense
    }

    func attack(targetID: UUID, from sourceID: UUID, state: inout GameState, balance: GameBalance) -> Bool {
        guard canAttack(targetID: targetID, from: sourceID, in: state, balance: balance) else { return false }
        guard let sourceIndex = state.towns.firstIndex(where: { $0.id == sourceID }) else { return false }
        guard let targetIndex = state.towns.firstIndex(where: { $0.id == targetID }) else { return false }
        return resolveAttack(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            attackerFaction: .player,
            committedStrength: state.towns[sourceIndex].armyStrength,
            state: &state,
            balance: balance
        )
    }

    func resolveAttack(
        sourceIndex: Int,
        targetIndex: Int,
        attackerFaction: TownFaction,
        committedStrength: Int,
        state: inout GameState,
        balance: GameBalance
    ) -> Bool {
        guard sourceIndex != targetIndex else { return false }
        guard state.towns.indices.contains(sourceIndex), state.towns.indices.contains(targetIndex) else { return false }

        let sourceStrength = state.towns[sourceIndex].armyStrength
        let attackStrength = min(committedStrength, sourceStrength)
        let target = state.towns[targetIndex]
        let effectiveDefense = combatSystem.effectiveDefenseStrength(for: target, in: state, balance: balance)
        let survivors = combatSystem.winnerSurvivors(
            attackStrength: attackStrength,
            effectiveDefense: effectiveDefense,
            balance: balance
        )

        guard survivors > 0 else {
            applyFailedAttack(
                sourceIndex: sourceIndex,
                targetIndex: targetIndex,
                attackStrength: attackStrength,
                sourceStrength: sourceStrength,
                effectiveDefense: effectiveDefense,
                state: &state
            )
            return false
        }

        state.towns[sourceIndex].armyStrength = max(0, sourceStrength - attackStrength)
        state.towns[sourceIndex].resources[.soldiers] = state.towns[sourceIndex].armyStrength
        state.towns[sourceIndex].soldierRoster.clear()

        occupationSystem.applyCapturePenalties(to: &state.towns[targetIndex], balance: balance)
        state.towns[targetIndex].setFaction(attackerFaction)
        state.towns[targetIndex].armyStrength = survivors
        state.towns[targetIndex].resources[.soldiers] = survivors
        state.towns[targetIndex].soldierRoster.clear()
        return true
    }

    private func applyFailedAttack(
        sourceIndex: Int,
        targetIndex: Int,
        attackStrength: Int,
        sourceStrength: Int,
        effectiveDefense: Int,
        state: inout GameState
    ) {
        state.towns[sourceIndex].armyStrength = max(0, sourceStrength - attackStrength)
        state.towns[sourceIndex].resources[.soldiers] = state.towns[sourceIndex].armyStrength
        state.towns[sourceIndex].soldierRoster.clear()

        let defenderGarrison = state.towns[targetIndex].armyStrength
        let defenderReduction = min(attackStrength, defenderGarrison)
        state.towns[targetIndex].armyStrength = max(0, defenderGarrison - defenderReduction)
        if state.towns[targetIndex].isPlayerControlled {
            state.towns[targetIndex].resources[.soldiers] = state.towns[targetIndex].armyStrength
            state.towns[targetIndex].soldierRoster.clear()
        } else {
            state.towns[targetIndex].resources[.soldiers] = state.towns[targetIndex].armyStrength
        }
    }

    private func makeTowns(balance: GameBalance) -> [Town] {
        let layouts: [TownBiomeLayout] = [
            TownBiomeLayout(sides: [.left: .forest, .right: .mountain, .top: .forest, .bottom: .mountain]),
            TownBiomeLayout(sides: [.left: .forest, .top: .forest, .right: .forest, .bottom: .mountain]),
            TownBiomeLayout(sides: [.left: .mountain, .right: .mountain, .top: .mountain, .bottom: .mountain]),
            TownBiomeLayout(sides: [.left: .forest, .right: .forest, .top: .forest, .bottom: .forest]),
            TownBiomeLayout(sides: [.left: .mountain, .right: .forest, .top: .mountain, .bottom: .forest]),
            TownBiomeLayout(sides: [.left: .forest, .right: .mountain, .top: .mountain, .bottom: .mountain])
        ]
        let names = [
            "Hearthglen", "Green Hollow", "Ironridge", "Mosswatch", "Ashbarrow", "Pinefall", "Stonewake", "Rivergate", "Brindle Keep", "Oakmere",
            "Frostford", "Briarwall", "Duskara", "Sunreach", "Valehold", "Cinder Pass", "Deepwood", "Crownhill", "Greyfen", "Moonford",
            "Redspire", "Westmere", "Northbarrow", "Dawnfield", "Elderwick"
        ]

        return names.enumerated().map { index, name in
            let layout = layouts[index % layouts.count]
            let resources = ResourceWallet([
                .gold: 60 + index * 6,
                .wood: layout.sides.values.contains(.forest) ? 120 : 50,
                .coal: layout.sides.values.contains(.mountain) ? 110 : 45,
                .tech: 20 + index,
                .food: 30,
                .people: 4,
                .soldiers: 0
            ])
            let isDuskara = name == "Duskara"
            let faction: TownFaction
            if isDuskara {
                faction = .duskara
            } else if index == names.count - 1 {
                faction = .enemy
            } else {
                faction = .neutral
            }
            return Town(
                name: name,
                resources: resources,
                buildings: starterBuildings(for: index, balance: balance),
                biomeLayout: layout,
                faction: faction,
                isDuskara: isDuskara,
                armyStrength: 0
            )
        }
    }

    private func applyInitialDefenses(to towns: inout [Town], connections: [TownConnection]) {
        guard let duskaraID = towns.first(where: \.isDuskara)?.id else { return }
        let distances = graphDistances(from: duskaraID, connections: connections)
        let maxDistance = max(distances.values.max() ?? 1, 1)

        for index in towns.indices {
            let defense: Int
            if towns[index].isDuskara {
                defense = 180
            } else {
                let distance = distances[towns[index].id] ?? maxDistance
                let variation = index % 6
                if distance <= 1 {
                    defense = 35 + variation * 5
                } else if distance <= max(2, maxDistance / 2) {
                    defense = 20 + min(15, variation * 3)
                } else if distance < maxDistance {
                    defense = 10 + min(10, variation * 2)
                } else {
                    defense = 3 + min(5, variation)
                }
            }
            towns[index].armyStrength = towns[index].isPlayerControlled ? 0 : defense
            towns[index].resources[.soldiers] = towns[index].armyStrength
        }
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

    private func starterBuildings(for index: Int, balance: GameBalance) -> [BuildingInstance] {
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        var buildings = [BuildingInstance(kind: .house, coordinate: center)]
        if index % 2 == 0 {
            buildings.append(BuildingInstance(kind: .farm, coordinate: GridCoordinate(x: center.x, y: center.y + 1)))
        }
        return buildings
    }

    private func nodePosition(for index: Int) -> (Double, Double) {
        let column = index / 5
        let row = index % 5
        let x = 0.08 + Double(column) * 0.18
        let yOffsets = [0.12, 0.30, 0.48, 0.66, 0.84]
        let drift = column.isMultiple(of: 2) ? 0.0 : 0.06
        return (min(0.94, x), min(0.90, yOffsets[row] + drift))
    }

    private func makeConnections(townIDs: [UUID]) -> [TownConnection] {
        var connections: Set<TownConnection> = []
        for index in townIDs.indices {
            if index + 5 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 5]))
            }
            if index % 5 < 4 && index + 1 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 1]))
            }
            if index % 5 < 4 && index + 6 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 6]))
            }
        }
        return Array(connections)
    }
}
