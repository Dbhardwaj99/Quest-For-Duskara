import Foundation
import Testing

struct GameplayTests {
    @Test func autosaveRoundTripsAndSurfacesTypedFailures() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = GameSaveStore(directory: directory)
        #expect(try store.load() == nil)

        var state = makeNewGame(balance: .duskDefault)
        state.day = 12
        state.elapsedSecondsInDay = 37
        state.towns[0].resources[.gold] = 321
        state.towns[0].soldierRoster[.archer] = 4
        state.towns[0].armyStrength = 20
        state.towns[1].faction = .player
        state.towns[1].resources[.gold] = 777
        state.towns[1].buildings.append(BuildingInstance(
            kind: .farm,
            coordinate: GridCoordinate(x: 0, y: 0),
            level: 2
        ))
        state.towns[1].soldierRoster[.knight] = 3
        state.towns[1].armyStrength = 30
        state.newsEvents = [NewsEvent(day: 11, kind: .cityCapture, message: "Captured Ironridge")]

        for difficulty in Difficulty.allCases {
            try store.save(state: state, difficulty: difficulty)
            let loadedGame = try store.load()
            let savedGame = try #require(loadedGame)
            #expect(savedGame.state == state)
            #expect(savedGame.difficulty == difficulty)
            #expect(savedGame.schemaVersion == SavedGame.currentSchemaVersion)
        }

        let legacyData = try JSONEncoder().encode(LegacySavedGame(dayLabel: "Day 12", state: state))
        try legacyData.write(to: directory.appendingPathComponent("duskara-save.json"))
        let loadedLegacyGame = try store.load()
        let legacyGame = try #require(loadedLegacyGame)
        #expect(legacyGame.state == state)
        #expect(legacyGame.difficulty == .medium)

        try Data("not json".utf8).write(to: directory.appendingPathComponent("duskara-save.json"))
        let corruptData = try Data(contentsOf: directory.appendingPathComponent("duskara-save.json"))

        #expect(throws: GameSaveLoadError.invalidData) {
            try store.load()
        }
        #expect(try Data(contentsOf: directory.appendingPathComponent("duskara-save.json")) == corruptData)

        let unsupportedData = try JSONEncoder().encode(UnsupportedSavedGame(
            schemaVersion: SavedGame.currentSchemaVersion + 1,
            dayLabel: "Day 12",
            state: state,
            difficulty: .hard
        ))
        try unsupportedData.write(to: directory.appendingPathComponent("duskara-save.json"))

        #expect(throws: GameSaveLoadError.unsupportedVersion) {
            try store.load()
        }
        #expect(try Data(contentsOf: directory.appendingPathComponent("duskara-save.json")) == unsupportedData)
        #expect(GameSaveLoadError.invalidData.recoveryMessage.contains(directory.path) == false)

        // Version 1 saves ran a tenth of today's economy on 60-second days:
        // their stores come back scaled up, and the day restarts rather than
        // replaying several ten-second days at once.
        try JSONEncoder().encode(UnsupportedSavedGame(schemaVersion: 1, dayLabel: "Day 12", state: state, difficulty: .easy))
            .write(to: directory.appendingPathComponent("duskara-save.json"))
        let migratedGame = try #require(try store.load())
        #expect(migratedGame.state.towns[0].resources[.gold] == 3_210)
        #expect(migratedGame.state.towns[1].resources[.gold] == 7_770)
        #expect(migratedGame.state.towns[0].resources[.people] == state.towns[0].resources[.people])
        #expect(migratedGame.state.elapsedSecondsInDay == 0)
    }

    @Test func resumedGameRestoresStateAndResetsPresentation() {
        var state = makeNewGame(balance: .duskDefault)
        state.day = 8
        let viewModel = makeViewModel()
        let destinationViewModel = viewModel
        let buildingID = UUID()
        viewModel.bonusAllocation = [.gold: 100]
        viewModel.selectedCoordinate = GridCoordinate(x: 1, y: 1)
        viewModel.selectedBuildingID = buildingID
        viewModel.placementBuildingKind = .farm
        viewModel.buildingPresentation = .details(buildingID)
        viewModel.isBuildMenuPresented = true
        viewModel.isWorldMapPresented = true
        viewModel.feedback = GameMessage(text: "Old message")

        viewModel.resume(state: state, difficulty: .hard)
        defer { viewModel.stopClock() }

        #expect(viewModel === destinationViewModel)
        #expect(viewModel.phase == .town)
        #expect(viewModel.state == state)
        #expect(viewModel.selectedDifficulty == .hard)
        #expect(viewModel.clockTask != nil)
        #expect(viewModel.bonusAllocation.isEmpty)
        #expect(viewModel.selectedCoordinate == nil)
        #expect(viewModel.selectedBuildingID == nil)
        #expect(viewModel.placementBuildingKind == nil)
        #expect(viewModel.buildingPresentation == nil)
        #expect(viewModel.isBuildMenuPresented == false)
        #expect(viewModel.isWorldMapPresented == false)
        #expect(viewModel.feedback == nil)
    }

    @Test func knightOutpowersTwoArchersWithoutChangingPremiumCosts() throws {
        let definitions = GameBalance.duskDefault.soldierDefinitions
        let archer = try #require(definitions[.archer])
        let knight = try #require(definitions[.knight])

        #expect(knight.power == 24)
        #expect(knight.power > archer.power * 2)
        #expect(knight.trainingCost == [.gold: 450, .skill: 150, .food: 250])
        #expect(knight.peopleRequired == 2)
        #expect(knight.dailyFoodUpkeep == 40)
    }

    @Test func contrastKnobPushesColorWithoutEscapingTheChannelRange() {
        // A mid-blue like the open sea, in HSB.
        let water = (saturation: 0.68, brightness: 0.47)

        let shipped = WorldContrast.adjust(saturation: water.saturation, brightness: water.brightness, level: WorldContrast.neutral)
        // At neutral the curve is the pastel pass and nothing more: 0.76
        // desaturation and the brightness lift, with the knob contributing nothing.
        #expect(abs(shipped.saturation - water.saturation * 0.76) < 0.0001)
        #expect(abs(shipped.brightness - water.brightness * 1.06) < 0.0001)

        // The world ships above neutral, so the default is deliberately punchier
        // than the plain pastel pass — that is the whole point of the preset.
        #expect(WorldContrast.standard > WorldContrast.neutral)
        #expect(WorldContrast.range.contains(WorldContrast.standard))
        let byDefault = WorldContrast.adjust(saturation: water.saturation, brightness: water.brightness, level: WorldContrast.standard)
        #expect(byDefault.saturation > shipped.saturation)

        // Turning it up saturates (bluer water, greener grass) and pushes the
        // sub-midpoint tones darker, which is what makes buildings pop.
        let vivid = WorldContrast.adjust(saturation: water.saturation, brightness: water.brightness, level: 1.8)
        #expect(vivid.saturation > shipped.saturation)
        #expect(vivid.brightness < shipped.brightness)

        // Turning it down flattens both toward grey and mid.
        let flat = WorldContrast.adjust(saturation: water.saturation, brightness: water.brightness, level: 0.4)
        #expect(flat.saturation < shipped.saturation)
        #expect(flat.brightness > shipped.brightness)

        // Bright tones move the other way — the spread pivots on mid-grey. Kept
        // clear of 1.0, where both sides would clamp and compare equal.
        let litNeutral = WorldContrast.adjust(saturation: 0.1, brightness: 0.7, level: WorldContrast.neutral)
        let litVivid = WorldContrast.adjust(saturation: 0.1, brightness: 0.7, level: 1.8)
        #expect(litVivid.brightness > litNeutral.brightness)

        // NSColor(hue:saturation:brightness:) traps outside 0...1, and the
        // extremes of the slider are exactly where the curve wants to overshoot.
        for level in [WorldContrast.range.lowerBound, WorldContrast.standard, WorldContrast.range.upperBound] {
            for saturation in [0.0, 0.5, 1.0] {
                for brightness in [0.0, 0.5, 1.0] {
                    let adjusted = WorldContrast.adjust(saturation: saturation, brightness: brightness, level: level)
                    #expect((0...1).contains(adjusted.saturation))
                    #expect((0...1).contains(adjusted.brightness))
                }
            }
        }
    }

    @Test func campaignUsesFifteenLargeIslandsAndKeepsThreeByThreeTowns() {
        let balance = GameBalance.duskDefault
        let state = makeNewGame(balance: balance)
        let generated = WorldGenerator().generate(towns: state.towns, seed: 42)
        let landTileCount = generated.world.terrainTiles.count { $0.terrain.isLand }

        #expect(state.towns.count == 15)
        #expect(state.towns.filter(\.isDuskara).count == 1)
        #expect(balance.gridSize == GridSize(columns: 3, rows: 3))
        #expect(landTileCount >= 300)
        #expect(generated.nodes.first(where: { $0.townID == state.towns[0].id })?.x == generated.world.layout.playableInset)
        #expect(generated.nodes.first(where: { $0.townID == state.towns[0].id })?.y == 1 - generated.world.layout.playableInset)
        #expect(generated.nodes.first(where: { $0.townID == state.towns.last?.id })?.x == 1 - generated.world.layout.playableInset)
        #expect(generated.nodes.first(where: { $0.townID == state.towns.last?.id })?.y == generated.world.layout.playableInset)
    }

    @MainActor
    @Test func foundingBuildingsStockTheirOwnPopulationForPlayerAndAI() throws {
        let balance = GameBalance.duskDefault
        let house = try #require(balance.buildingDefinitions[.house])
        let expected = house.peopleOnBuild
        let state = makeNewGame(balance: balance)

        // The player's wallet is rebuilt from `baseStartingResources`, which has
        // no people in it — the regression was that rebuild wiping the founding
        // population and leaving the town at zero under a House built for eight.
        #expect(state.towns[0].isPlayerControlled)
        #expect(state.towns[0].resources[.people] == expected)
        for town in state.towns {
            #expect(town.resources[.people] == expected)
        }

        // Starting the campaign rebuilds that wallet a second time, with the
        // difficulty bonus on top. People have to survive that pass too.
        let viewModel = makeViewModel()
        viewModel.adjustBonusPresets(for: .easy)
        viewModel.startGame()
        defer { viewModel.stopClock() }
        #expect(viewModel.activeTown.resources[.people] == expected)
        #expect(viewModel.activeTown.resources[.gold] > (balance.baseStartingResources[.gold] ?? 0))

        // The Pier is staffed out of that population, so free people is what is
        // left over — not the zero a starved town reports.
        let pierWorkers = try #require(balance.buildingDefinitions[.pier]).peopleRequired
        #expect(viewModel.freePeople == expected - pierWorkers)
        #expect(viewModel.freePeople > 0)
    }

    @MainActor
    @Test func troopsMoveByHandWhileTheStockpileIsShared() throws {
        let viewModel = makeViewModel()
        viewModel.startGame()
        defer { viewModel.stopClock() }

        // One island: nowhere to move troops, so the button is not offered at all.
        #expect(viewModel.transferDestinations.isEmpty)

        let second = try #require(viewModel.state.towns.firstIndex { $0.isPlayerControlled == false })
        let secondID = viewModel.state.towns[second].id
        viewModel.state.towns[second].faction = .player
        // The island doing the moving is never its own destination.
        #expect(viewModel.transferDestinations.map(\.id) == [secondID])

        // Troops move in whole units and the report is what actually moved:
        // half of a knight and an archer (17 of 34) fits only the archer.
        let balance = viewModel.balance
        viewModel.state.updateTown(id: viewModel.state.activeTownID) {
            $0.soldierRoster = SoldierRoster(counts: [.knight: 1, .archer: 1])
            GameRules.syncArmy(&$0, balance: balance)
        }
        let garrison = try #require(viewModel.state.town(id: secondID)).armyStrength
        viewModel.moveTroops(from: viewModel.state.activeTownID, to: secondID, fraction: 0.5)
        #expect(viewModel.activeArmyStrength == 24)
        #expect(viewModel.state.town(id: secondID)?.armyStrength == garrison + 10)
        viewModel.pullAllTroops()
        #expect(viewModel.activeArmyStrength == 34 + garrison)
        #expect(viewModel.state.town(id: secondID)?.armyStrength == 0)

        // Building needs no transfer: the gold ships in from the other island.
        // Two islands price a Farm at 500 gold.
        viewModel.state.updateTown(id: viewModel.state.activeTownID) { $0.resources[.gold] = 0 }
        viewModel.state.towns[second].resources[.gold] = 5_000
        viewModel.place(.farm, at: GridCoordinate(x: 0, y: 0))
        #expect(viewModel.activeTown.buildings.contains { $0.kind == .farm })
        #expect(viewModel.state.town(id: secondID)?.resources[.gold] == 4_500)
    }

    @Test func buildTrainAndTransfer() {
        let balance = GameBalance.duskDefault
        var state = makeNewGame(balance: balance)
        state.towns[0].resources = ResourceWallet([.gold: 2_000, .skill: 1_000, .food: 100, .people: 20])

        #expect(GameRules.build(.barracks, at: GridCoordinate(x: 0, y: 0), in: &state.towns[0], balance: balance) == nil)
        #expect(GameRules.train(.archer, in: &state.towns[0], balance: balance) == nil)
        #expect(state.towns[0].armyStrength > 0)

        var second = state.towns[1]
        second.faction = .player
        state.towns[1] = second
        let order = TransferOrder(fromTownID: state.towns[0].id, toTownID: second.id, amounts: [.gold: 10])
        #expect(GameRules.transfer(order, state: &state, balance: balance) == nil)
        #expect(state.towns[1].resources[.gold] >= 10)
    }

    @Test func workforceStarvedEnemyTownRecoversAndKeepsDeveloping() {
        let balance = GameBalance.duskDefault
        var state = makeNewGame(balance: balance)
        guard let enemy = state.towns.first(where: { $0.faction == .enemy }) else {
            Issue.record("New game needs an enemy town.")
            return
        }
        // Two towns and no sea routes: the AI has no attack targets, so this
        // fixture is only ever exercising development.
        state.towns = [state.towns[0], enemy]
        state.connections = []
        let enemyID = enemy.id
        // Resources are deliberately abundant so workforce is the only blocker.
        state.updateTown(id: enemyID) {
            $0.resources = ResourceWallet([.gold: 5_000, .skill: 5_000, .food: 500, .people: 4])
            $0.soldierRoster = SoldierRoster()
            $0.armyStrength = 0
        }

        // Turn one builds the Farm and spends the last free person. This is
        // where development used to stop for good.
        GameRules.runEnemyTurn(state: &state, balance: balance)
        #expect(state.town(id: enemyID)?.buildings.contains { $0.kind == .farm } == true)
        #expect(GameRules.freePeople(state.town(id: enemyID) ?? enemy, balance: balance) == 0)

        for _ in 0..<11 { GameRules.runEnemyTurn(state: &state, balance: balance) }

        guard let developed = state.town(id: enemyID) else {
            Issue.record("Enemy town disappeared.")
            return
        }
        #expect(developed.buildings.filter { $0.kind == .house }.count > 1)
        #expect(developed.buildings.contains { $0.kind == .barracks })
        #expect(developed.buildings.contains { $0.kind == .factory })
        #expect(developed.armyStrength > 0)
    }

    @MainActor
    @Test func losingTheLastTownEndsTheCampaign() {
        let viewModel = makeViewModel()
        let balance = viewModel.balance
        viewModel.startGame()

        guard let player = viewModel.state.towns.firstIndex(where: \.isPlayerControlled),
              let raider = viewModel.state.towns.firstIndex(where: { $0.faction == .enemy }) else {
            Issue.record("New game needs a player town and an enemy town.")
            return
        }
        viewModel.state.towns[raider].soldierRoster = SoldierRoster.decompose(strength: 5_000, using: balance.soldierDefinitions)
        GameRules.syncArmy(&viewModel.state.towns[raider], balance: balance)

        #expect(GameRules.resolveAttack(
            source: raider,
            target: player,
            faction: .enemy,
            realmID: viewModel.state.towns[raider].realmID,
            strength: viewModel.state.towns[raider].armyStrength,
            state: &viewModel.state,
            balance: balance
        ))
        #expect(viewModel.state.towns.contains(where: \.isPlayerControlled) == false)

        viewModel.sanitizeSelection()
        #expect(viewModel.phase == .defeat)

        // A terminal campaign must not keep ticking over.
        let terminal = viewModel.state
        viewModel.advanceDayManually()
        viewModel.tick()
        #expect(viewModel.state == terminal)
        #expect(viewModel.phase == .defeat)
    }

    @Test func hungerDisbandsOnlyTheUnfedSoldiers() {
        let balance = GameBalance.duskDefault
        var town = makeNewGame(balance: balance).towns[0]
        town.soldierRoster = SoldierRoster(counts: [.archer: 3])
        GameRules.syncArmy(&town, balance: balance)
        town.resources[.food] = 45 // three archers eat 60

        GameRules.applyUpkeep(to: &town, balance: balance)

        // 15 short costs one archer — it used to cost the whole army.
        #expect(town.soldierRoster[.archer] == 2)
        #expect(town.armyStrength == 20)
        #expect(town.resources[.food] == 0)
    }

    @Test func garrisonsHoldAndEatFromTheSharedStockpile() {
        let balance = GameBalance.duskDefault
        var state = makeNewGame(balance: balance)
        // A captured island with an army and no food of its own.
        state.towns[1].faction = .player
        state.towns[1].resources[.food] = 0
        state.towns[1].soldierRoster = SoldierRoster(counts: [.archer: 2])
        GameRules.syncArmy(&state.towns[1], balance: balance)
        state.towns[0].resources[.food] = 1_000
        let enemyGarrisons = state.towns.filter { $0.isPlayerControlled == false }.map(\.armyStrength)

        // Stay short of the enemy turn, which can train and fight.
        for _ in 1..<(balance.enemyTurnInterval - 1) { GameRules.advanceDay(state: &state, balance: balance) }

        #expect(state.towns[1].armyStrength == 20)
        #expect(state.towns[0].resources[.food] == 1_000 - 40 * (balance.enemyTurnInterval - 2))
        // Enemy garrisons are fed by their islands: Duskara's used to starve on day two.
        #expect(state.towns.filter { $0.isPlayerControlled == false }.map(\.armyStrength) == enemyGarrisons)
    }

    @Test func pricesClimbWithEachIslandAndEachLevel() {
        let balance = GameBalance.duskDefault
        #expect(balance.priced(forIslands: 1).buildingDefinitions[.farm]?.cost(for: 1) == [.gold: 400, .skill: 200])
        // Three islands: +25% twice. Food is sized by upkeep and never scales.
        let threeIslands = balance.priced(forIslands: 3)
        #expect(threeIslands.buildingDefinitions[.farm]?.cost(for: 1) == [.gold: 600, .skill: 300])
        #expect(threeIslands.soldierDefinitions[.knight]?.trainingCost == [.gold: 680, .skill: 230, .food: 250])
        // Skill climbs faster than gold as a building levels up.
        #expect(balance.buildingDefinitions[.farm]?.cost(for: 3) == [.gold: 1_200, .skill: 1_200])
        // The House stays gold-only, so an island with no skill can still grow.
        #expect(balance.buildingDefinitions[.house]?.cost(for: 3) == [.gold: 900])
    }

    @Test func harborMarketNeedsAFreeCityAndNeverPaysARoundTrip() throws {
        let balance = GameBalance.duskDefault
        for partners in 1...5 {
            for kind in [ResourceKind.food, .skill] {
                let buy = try #require(GameRules.marketPrice(of: kind, lot: 100, buying: true, partners: partners, balance: balance))
                let sell = try #require(GameRules.marketPrice(of: kind, lot: 100, buying: false, partners: partners, balance: balance))
                #expect(buy > sell)
            }
        }
        #expect(GameRules.marketPrice(of: .food, lot: 100, buying: false, partners: 1, balance: balance) == 35)
        #expect(GameRules.marketPrice(of: .skill, lot: 100, buying: true, partners: 4, balance: balance) == 230)

        // Partners are free cities one sea lane from a player island with a Pier.
        var state = makeNewGame(balance: balance)
        let freeCity = try #require(state.towns.first { $0.faction == .neutral })
        let enemy = try #require(state.towns.first { $0.faction == .enemy })
        state.connections = [
            TownConnection(from: state.towns[0].id, to: freeCity.id),
            TownConnection(from: state.towns[0].id, to: enemy.id)
        ]
        #expect(GameRules.tradePartners(state).map(\.id) == [freeCity.id])

        state.towns[0].resources[.food] = 1_000
        let gold = state.towns[0].resources[.gold]
        #expect(GameRules.trade(.food, lot: 1_000, buying: false, at: state.towns[0].id, state: &state, balance: balance))
        #expect(state.towns[0].resources[.food] == 0)
        #expect(state.towns[0].resources[.gold] == gold + 350)

        // No free city on a sea lane: the market is closed.
        state.connections = [TownConnection(from: state.towns[0].id, to: enemy.id)]
        #expect(GameRules.trade(.skill, lot: 100, buying: true, at: state.towns[0].id, state: &state, balance: balance) == false)
    }

    @Test func demolishingRefundsHalfAndFreesThePlot() throws {
        let balance = GameBalance.duskDefault
        var town = makeNewGame(balance: balance).towns[0]
        let house = try #require(town.buildings.first { $0.kind == .house })
        let gold = town.resources[.gold]

        GameRules.demolish(house.id, in: &town, balance: balance)

        #expect(town.buildings.contains { $0.id == house.id } == false)
        #expect(town.resources[.gold] == gold + 150)
        // Its four residents leave with it.
        #expect(town.resources[.people] == 0)
        #expect(GameRules.placementFailure(for: .house, at: house.coordinate, in: town, balance: balance) == nil)
    }

    @Test func houseUpgradesAndDemolitionRespectHousingCapacity() throws {
        let balance = GameBalance.duskDefault
        var town = makeNewGame(balance: balance).towns[0]
        let house = try #require(town.buildings.first { $0.kind == .house })
        town.resources[.gold] = 10_000
        town.resources[.people] = GameRules.populationCapacity(town, balance: balance)

        #expect(GameRules.upgrade(house.id, in: &town, balance: balance) == nil)
        #expect(GameRules.upgrade(house.id, in: &town, balance: balance) == nil)
        #expect(town.resources[.people] == GameRules.populationCapacity(town, balance: balance))

        GameRules.demolish(house.id, in: &town, balance: balance)
        #expect(town.resources[.people] <= GameRules.populationCapacity(town, balance: balance))
    }

    /// The pacing target: a Medium opening takes its first island inside a
    /// minute and a half of ten-second days.
    @Test func mediumOpeningTakesAnIslandWithinNinetySeconds() throws {
        let viewModel = makeViewModel()
        viewModel.adjustBonusPresets(for: .medium)
        viewModel.startGame()
        defer { viewModel.stopClock() }

        let house = try #require(viewModel.activeTown.buildings.first { $0.kind == .house })
        viewModel.place(.farm, at: GridCoordinate(x: 0, y: 0))
        viewModel.selectedBuildingID = house.id
        viewModel.upgradeSelectedBuilding()
        viewModel.place(.factory, at: GridCoordinate(x: 2, y: 0))
        viewModel.place(.barracks, at: GridCoordinate(x: 0, y: 1))
        #expect(viewModel.activeTown.buildings.count == 5)

        func weakestTarget() throws -> Town {
            try #require(viewModel.state.towns.filter { $0.isPlayerControlled == false }
                .min { viewModel.effectiveDefenseStrength(for: $0) < viewModel.effectiveDefenseStrength(for: $1) })
        }
        while try viewModel.canAttack(weakestTarget().id) == false, viewModel.state.day < 9 {
            viewModel.advanceDayManually()
            while viewModel.trainingUnavailableReason(for: .archer) == nil { viewModel.train(.archer) }
        }
        let target = try weakestTarget()
        viewModel.attackTown(target.id)

        #expect(viewModel.state.town(id: target.id)?.isPlayerControlled == true)
        #expect(viewModel.state.day < 9)
    }

    @Test func housesRefillAfterLosses() {
        let balance = GameBalance.duskDefault
        var state = makeNewGame(balance: balance)
        state.towns[0].resources[.people] = 0

        // A level-1 House holds 8; a quarter of that moves in each day.
        GameRules.advanceDay(state: &state, balance: balance)
        #expect(state.towns[0].resources[.people] == 2)
        for _ in 0..<5 { GameRules.advanceDay(state: &state, balance: balance) }
        #expect(state.towns[0].resources[.people] == 8)
    }
}

/// Autosaves go to a throwaway directory — never the player's real save.
private func makeViewModel() -> GameViewModel {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return GameViewModel(saveStore: GameSaveStore(directory: directory))
}

private struct LegacySavedGame: Encodable {
    let dayLabel: String
    let state: GameState
}

private struct UnsupportedSavedGame: Encodable {
    let schemaVersion: Int
    let dayLabel: String
    let state: GameState
    let difficulty: Difficulty
}
