import Foundation
import Testing

@Suite("TransferSystem")
struct TransferSystemTests {
    let system = TransferSystem()

    private func twoTownState() -> GameState {
        TestFixtures.state(towns: [
            TestFixtures.town(1, resources: [.gold: 100, .food: 50, .people: 5]),
            TestFixtures.town(2, resources: [.gold: 10, .food: 5, .people: 2])
        ])
    }

    @Test func transferMovesResources() {
        var state = twoTownState()
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.gold: 40, .food: 10]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == nil)
        #expect(state.towns[0].resources[.gold] == 60)
        #expect(state.towns[0].resources[.food] == 40)
        #expect(state.towns[1].resources[.gold] == 50)
        #expect(state.towns[1].resources[.food] == 15)
    }

    @Test func transferRejectsSameTown() {
        var state = twoTownState()
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(1),
            amounts: [.gold: 1]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == .sameTown)
    }

    @Test func transferRejectsUncontrolledTowns() {
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1),
            TestFixtures.town(2, ownerID: TestFixtures.aiPlayer)
        ])
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.gold: 1]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == .destinationNotOwned)

        let reverse = TransferOrder(
            fromTownID: TestFixtures.uuid(2),
            toTownID: TestFixtures.uuid(1),
            amounts: [.gold: 1]
        )
        #expect(system.transfer(order: reverse, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == .sourceNotOwned)
    }

    @Test func transferRejectsOverdraft() {
        var state = twoTownState()
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.gold: 1000]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == .insufficientResources)
        #expect(state.towns[0].resources[.gold] == 100)
    }

    @Test func soldierTransferMovesWholeRosterUnits() {
        var roster = SoldierRoster()
        roster.add(.archer, count: 3)
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, armyStrength: 30, soldierRoster: roster),
            TestFixtures.town(2, armyStrength: 0)
        ])
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.soldiers: 10]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == nil)
        #expect(state.towns[0].armyStrength == 20)
        #expect(state.towns[1].armyStrength == 10)
        #expect(state.towns[0].resources[.soldiers] == 20)
        #expect(state.towns[1].resources[.soldiers] == 10)
        #expect(state.towns[0].soldierRoster[.archer] == 2)
        #expect(state.towns[1].soldierRoster[.archer] == 1)
    }

    @Test func soldierTransferRejectsMoreThanGarrison() {
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, armyStrength: 5),
            TestFixtures.town(2)
        ])
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.soldiers: 10]
        )
        #expect(system.transfer(order: order, state: &state, balance: TestFixtures.balance, actingPlayerID: TestFixtures.humanPlayer) == .insufficientResources)
    }
}
