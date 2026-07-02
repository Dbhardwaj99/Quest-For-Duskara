import Foundation

struct WorldMapSystem {
    private let combatSystem = CombatSystem()
    private let occupationSystem = OccupationSystem()
    private let worldGenerator = WorldGenerator()
    private let territorySystem = TerritorySystem()

    func makeInitialState(balance: GameBalance) -> GameState {
        var towns = makeTowns(balance: balance)
        towns[0].faction = .player
        towns[0].resources = ResourceWallet(balance.baseStartingResources)
        towns[0].armyStrength = 0

        let generatedWorld = worldGenerator.generate(towns: towns)
        applyInitialDefenses(to: &towns, connections: generatedWorld.connections)
        let territory = territorySystem.generateTerritory(
            towns: towns,
            nodes: generatedWorld.nodes,
            world: generatedWorld.world
        )

        return GameState(
            day: 1,
            elapsedSecondsInDay: 0,
            towns: towns,
            worldNodes: generatedWorld.nodes,
            connections: generatedWorld.connections,
            world: generatedWorld.world,
            territory: territory,
            activeTownID: towns[0].id
        )
    }

    func effectiveDefenseStrength(for town: Town, in state: GameState, balance: GameBalance) -> Int {
        combatSystem.effectiveDefenseStrength(for: town, in: state, balance: balance)
    }

    // Every city is an island: the player's armies travel by sea, so any
    // city in the world is a valid target.
    func canAttack(targetID: UUID, from sourceID: UUID, in state: GameState, balance: GameBalance) -> Bool {
        guard let source = state.towns.first(where: { $0.id == sourceID }), source.isPlayerControlled else { return false }
        guard let target = state.towns.first(where: { $0.id == targetID }), target.isPlayerControlled == false else { return false }
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
        territorySystem.reconcileOwnership(in: &state)
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
            "Frostford", "Briarwall", "Duskwatch", "Sunreach", "Valehold", "Cinder Pass", "Deepwood", "Crownhill", "Greyfen", "Moonford",
            "Westmere", "Northbarrow", "Dawnfield", "Elderwick", "Foxgrove", "Highmere", "Willowdeep", "Amberfall", "Ravenford", "Thornwatch",
            "Glasswater", "Kingsford", "Mistvale", "Barrowmere", "Emberwick", "Wolfscar", "Blackfen", "Grimhaven", "Redspire", "Duskara"
        ]
        let enemyTownNames: Set<String> = ["Wolfscar", "Blackfen", "Grimhaven", "Redspire"]

        return names.enumerated().map { index, name in
            let layout = layouts[index % layouts.count]
            let resources = ResourceWallet([
                .gold: 60 + index * 6,
                .skill: 20 + index,
                .food: 30,
                .people: 4,
                .soldiers: 0
            ])
            let isDuskara = name == "Duskara"
            let faction: TownFaction
            if isDuskara {
                faction = .duskara
            } else if enemyTownNames.contains(name) {
                faction = .enemy
            } else {
                faction = .neutral
            }
            return Town(
                name: name,
                resources: resources,
                buildings: starterBuildings(balance: balance),
                biomeLayout: layout,
                faction: faction,
                isDuskara: isDuskara,
                armyStrength: 0
            )
        }
    }

    private func applyInitialDefenses(to towns: inout [Town], connections: [TownConnection]) {
        guard let duskaraID = towns.first(where: \.isDuskara)?.id else { return }
        let distances = CombatSystem.graphDistances(from: duskaraID, connections: connections)
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

    private func starterBuildings(balance: GameBalance) -> [BuildingInstance] {
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        // The pier sits on the board's bottom edge, at the shoreline.
        let shoreline = GridCoordinate(x: center.x, y: balance.gridSize.rows - 1)
        return [
            BuildingInstance(kind: .house, coordinate: center),
            BuildingInstance(kind: .pier, coordinate: shoreline)
        ]
    }
}
