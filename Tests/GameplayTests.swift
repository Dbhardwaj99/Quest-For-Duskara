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
