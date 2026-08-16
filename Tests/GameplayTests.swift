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
        state.tradeOffers = [TownTradeOffer(
            townID: state.towns[0].id,
            partnerTownID: state.towns[1].id,
            wants: [.food: 12],
            gives: [.gold: 18]
        )]

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
    }

    @Test func resumedGameRestoresStateAndResetsPresentation() {
        var state = makeNewGame(balance: .duskDefault)
        state.day = 8
        let viewModel = GameViewModel()
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
        #expect(knight.trainingCost == [.gold: 45, .skill: 15, .food: 25])
        #expect(knight.peopleRequired == 2)
        #expect(knight.dailyFoodUpkeep == 4)
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

        // Bright tones move the other way — the spread pivots on mid-grey.
        let peak = WorldContrast.adjust(saturation: 0.1, brightness: 0.9, level: 1.8)
        let peakShipped = WorldContrast.adjust(saturation: 0.1, brightness: 0.9, level: WorldContrast.standard)
        #expect(peak.brightness > peakShipped.brightness)

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

    @Test func buildTrainAndTransfer() {
        let balance = GameBalance.duskDefault
        var state = makeNewGame(balance: balance)
        state.towns[0].resources = ResourceWallet([.gold: 1_000, .skill: 1_000, .food: 100, .people: 20])

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
        let viewModel = GameViewModel()
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
