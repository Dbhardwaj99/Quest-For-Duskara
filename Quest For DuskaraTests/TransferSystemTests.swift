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
        #expect(system.transfer(order: order, state: &state) == nil)
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
        #expect(system.transfer(order: order, state: &state) == .sameTown)
    }

    @Test func transferRejectsUncontrolledTowns() {
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1),
            TestFixtures.town(2, faction: .neutral)
        ])
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.gold: 1]
        )
        #expect(system.transfer(order: order, state: &state) == .destinationNotOwned)

        let reverse = TransferOrder(
            fromTownID: TestFixtures.uuid(2),
            toTownID: TestFixtures.uuid(1),
            amounts: [.gold: 1]
        )
        #expect(system.transfer(order: reverse, state: &state) == .sourceNotOwned)
    }

    @Test func transferRejectsOverdraft() {
        var state = twoTownState()
        let order = TransferOrder(
            fromTownID: TestFixtures.uuid(1),
            toTownID: TestFixtures.uuid(2),
            amounts: [.gold: 1000]
        )
        #expect(system.transfer(order: order, state: &state) == .insufficientResources)
        #expect(state.towns[0].resources[.gold] == 100)
    }

    @Test func soldierTransferMovesStrengthAndClearsRosters() {
        // Characterizes current behavior: moving soldiers wipes both rosters
        // and moves raw strength numbers.
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
        #expect(system.transfer(order: order, state: &state) == nil)
        #expect(state.towns[0].armyStrength == 20)
        #expect(state.towns[1].armyStrength == 10)
        #expect(state.towns[0].resources[.soldiers] == 20)
        #expect(state.towns[1].resources[.soldiers] == 10)
        #expect(state.towns[0].soldierRoster.counts.isEmpty)
        #expect(state.towns[1].soldierRoster.counts.isEmpty)
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
        #expect(system.transfer(order: order, state: &state) == .insufficientResources)
    }
}
