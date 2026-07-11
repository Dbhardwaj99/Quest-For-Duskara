import Foundation

struct WorldMapSystem {
    private let combatSystem = CombatSystem()
    private let occupationSystem = OccupationSystem()
    private let worldGenerator = WorldGenerator()
    private let territorySystem = TerritorySystem()

    /// The seed is injected: whoever creates the match (the server in
    /// multiplayer, the app for local campaigns) decides it, and every
    /// persistent ID derives from it.
    func makeInitialState(balance: GameBalance, seed: Int) -> GameState {
        var towns = makeTowns(balance: balance, seed: seed)
        towns[0].faction = .player
        towns[0].resources = ResourceWallet(balance.baseStartingResources)
        towns[0].armyStrength = 0

        let generatedWorld = worldGenerator.generate(towns: towns, seed: seed)
        applyInitialDefenses(to: &towns, connections: generatedWorld.connections, balance: balance)
        let territory = territorySystem.generateTerritory(
            towns: towns,
            nodes: generatedWorld.nodes,
            world: generatedWorld.world
        )

        return GameState(
            day: 1,
            towns: towns,
            worldNodes: generatedWorld.nodes,
            connections: generatedWorld.connections,
            world: generatedWorld.world,
            territory: territory
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

        let definitions = balance.soldierDefinitions
        let source = state.towns[sourceIndex]
        let sourceStrength = source.armyStrength

        // Commit whole units first (roster is canonical); legacy strength
        // without units tops the force up for old-save garrisons.
        let requested = min(committedStrength, sourceStrength)
        let committedRoster = source.soldierRoster.fitting(power: requested, using: definitions)
        let committedRosterPower = committedRoster.armyStrength(using: definitions)
        let legacyPool = max(0, sourceStrength - source.soldierRoster.armyStrength(using: definitions))
        let legacyCommitted = min(requested - committedRosterPower, legacyPool)
        let attackStrength = committedRosterPower + legacyCommitted

        let target = state.towns[targetIndex]
        let effectiveDefense = combatSystem.effectiveDefenseStrength(for: target, in: state, balance: balance)
        let survivors = combatSystem.winnerSurvivors(
            attackStrength: attackStrength,
            effectiveDefense: effectiveDefense,
            balance: balance
        )

        state.towns[sourceIndex].soldierRoster.subtract(committedRoster)
        state.towns[sourceIndex].armyStrength = max(0, sourceStrength - attackStrength)
        state.towns[sourceIndex].resources[.soldiers] = state.towns[sourceIndex].armyStrength

        guard survivors > 0 else {
            // Committed force is lost; the defender bleeds units for the
            // strength thrown at it.
            let defender = state.towns[targetIndex]
            let reduction = min(attackStrength, defender.armyStrength)
            state.towns[targetIndex].soldierRoster.removeStrength(atLeast: reduction, using: definitions)
            let rosterStrength = state.towns[targetIndex].soldierRoster.armyStrength(using: definitions)
            state.towns[targetIndex].armyStrength = max(rosterStrength, defender.armyStrength - reduction)
            state.towns[targetIndex].resources[.soldiers] = state.towns[targetIndex].armyStrength
            return false
        }

        occupationSystem.applyCapturePenalties(to: &state.towns[targetIndex], balance: balance)
        state.towns[targetIndex].setFaction(attackerFaction)
        // Survivors garrison the capture as whole units, remainder rounded
        // up to one weakest unit; strength derives from the roster.
        let garrison = SoldierRoster.decompose(strength: survivors, using: definitions)
        state.towns[targetIndex].soldierRoster = garrison
        state.towns[targetIndex].armyStrength = garrison.armyStrength(using: definitions)
        state.towns[targetIndex].resources[.soldiers] = state.towns[targetIndex].armyStrength
        territorySystem.reconcileOwnership(in: &state)
        return true
    }

    private func makeTowns(balance: GameBalance, seed: Int) -> [Town] {
        var idRandom = DeterministicRandom(seed: seed, stream: 0x70_0000)
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
                id: idRandom.uuid(),
                name: name,
                resources: resources,
                buildings: starterBuildings(balance: balance, idRandom: &idRandom),
                biomeLayout: layout,
                faction: faction,
                isDuskara: isDuskara,
                armyStrength: 0
            )
        }
    }

    private func applyInitialDefenses(to towns: inout [Town], connections: [TownConnection], balance: GameBalance) {
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
            if towns[index].isPlayerControlled {
                towns[index].soldierRoster = SoldierRoster()
                towns[index].armyStrength = 0
            } else {
                // The roster is canonical: initial garrisons are whole units
                // and strength derives from them.
                let roster = SoldierRoster.decompose(strength: defense, using: balance.soldierDefinitions)
                towns[index].soldierRoster = roster
                towns[index].armyStrength = roster.armyStrength(using: balance.soldierDefinitions)
            }
            towns[index].resources[.soldiers] = towns[index].armyStrength
        }
    }

    private func starterBuildings(balance: GameBalance, idRandom: inout DeterministicRandom) -> [BuildingInstance] {
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        // The pier sits on the board's bottom edge, at the shoreline.
        let shoreline = GridCoordinate(x: center.x, y: balance.gridSize.rows - 1)
        return [
            BuildingInstance(id: idRandom.uuid(), kind: .house, coordinate: center),
            BuildingInstance(id: idRandom.uuid(), kind: .pier, coordinate: shoreline)
        ]
    }
}
