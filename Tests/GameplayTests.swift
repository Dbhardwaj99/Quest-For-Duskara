import Testing

struct GameplayTests {
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
}
