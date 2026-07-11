import Foundation
import Testing

@Suite("SoldierTrainingSystem")
struct SoldierTrainingSystemTests {
    let system = SoldierTrainingSystem()
    let balance = TestFixtures.balance

    private func barracksTown(
        resources: [ResourceKind: Int] = [.gold: 500, .skill: 300, .food: 100, .people: 10]
    ) -> Town {
        TestFixtures.town(1, resources: resources, buildings: [
            TestFixtures.building(1, kind: .barracks, x: 0, y: 0),
            TestFixtures.building(2, kind: .house, x: 1, y: 1, level: 2)
        ])
    }

    @Test func trainingRequiresBarracks() {
        var town = TestFixtures.town(1)
        #expect(system.train(.archer, in: &town, balance: balance) == .noBarracks)
    }

    @Test func trainingArcherSpendsCostAndSyncsArmy() {
        var town = barracksTown()
        let failure = system.train(.archer, in: &town, balance: balance)
        #expect(failure == nil)
        #expect(town.soldierRoster[.archer] == 1)
        #expect(town.armyStrength == 10)
        #expect(town.resources[.soldiers] == 10)
        #expect(town.resources[.gold] == 480)
        #expect(town.resources[.skill] == 295)
        #expect(town.resources[.food] == 90)
        // Archer consumes 1 person.
        #expect(town.resources[.people] == 9)
    }

    @Test func trainingFailsWithoutResources() {
        var town = barracksTown(resources: [.gold: 5, .skill: 300, .food: 100, .people: 10])
        #expect(system.train(.archer, in: &town, balance: balance) == .insufficientResources)
    }

    @Test func trainingFailsWithoutFreePeople() {
        // Barracks commits 4 workers, leaving 0 of the 4 people free.
        var town = barracksTown(resources: [.gold: 500, .skill: 300, .food: 100, .people: 4])
        #expect(system.train(.knight, in: &town, balance: balance) == .insufficientPeople)
    }

    @Test func trainingStopsAtPopulationCap() {
        var town = barracksTown()
        // House level 2 caps military manpower at 16.
        for _ in 0..<8 {
            town.resources.add(.people, amount: 2)
            town.resources.add(.gold, amount: 100)
            town.resources.add(.food, amount: 50)
            town.resources.add(.skill, amount: 50)
            _ = system.train(.knight, in: &town, balance: balance)
        }
        #expect(town.soldierRoster[.knight] == 8)
        town.resources.add(.people, amount: 2)
        #expect(system.train(.knight, in: &town, balance: balance) == .militaryCapReached)
    }

    @Test func syncArmyStrengthDerivesFromRoster() {
        var town = TestFixtures.town(1, armyStrength: 3)
        town.soldierRoster.add(.archer, count: 2)
        town.soldierRoster.add(.knight, count: 1)
        system.syncArmyStrength(&town, balance: balance)
        #expect(town.armyStrength == 40)
        #expect(town.resources[.soldiers] == 40)
    }

    @Test func syncArmyStrengthKeepsLegacyValueWhenRosterEmpty() {
        // Characterizes migration behavior: towns without a roster keep their
        // stored armyStrength.
        var town = TestFixtures.town(1, armyStrength: 25)
        system.syncArmyStrength(&town, balance: balance)
        #expect(town.armyStrength == 25)
        #expect(town.resources[.soldiers] == 25)
    }
}
