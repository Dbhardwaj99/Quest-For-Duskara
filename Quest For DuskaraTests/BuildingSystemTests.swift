import Foundation
import Testing

@Suite("BuildingSystem")
struct BuildingSystemTests {
    let system = BuildingSystem()
    let balance = TestFixtures.balance

    @Test func incomeSumsProductionAcrossBuildingsAndLevels() {
        let town = TestFixtures.town(1, buildings: [
            TestFixtures.building(1, kind: .farm, x: 0, y: 0),
            TestFixtures.building(2, kind: .farm, x: 1, y: 0, level: 2),
            TestFixtures.building(3, kind: .pier, x: 0, y: 2),
            TestFixtures.building(4, kind: .house, x: 1, y: 1)
        ])
        let income = system.income(for: town, balance: balance)
        // farm L1 (8g/14f) + farm L2 (16g/28f) + pier L1 (8g), house produces nothing.
        #expect(income[.gold] == 32)
        #expect(income[.food] == 42)
        #expect(income[.skill] == nil)
    }

    @Test func buildSpendsCostAppendsBuildingAndAddsPeople() {
        var town = TestFixtures.town(1, resources: [.gold: 100, .skill: 50, .people: 0])
        let failure = system.build(.house, at: GridCoordinate(x: 0, y: 0), in: &town, balance: balance)
        #expect(failure == nil)
        #expect(town.buildings.count == 1)
        #expect(town.buildings[0].kind == .house)
        #expect(town.resources[.gold] == 75)
        #expect(town.resources[.skill] == 40)
        #expect(town.resources[.people] == 4)
    }

    @Test func buildFailsWhenOccupied() {
        var town = TestFixtures.town(1, buildings: [TestFixtures.building(1, kind: .house, x: 0, y: 0)])
        let failure = system.build(.farm, at: GridCoordinate(x: 0, y: 0), in: &town, balance: balance)
        #expect(failure == .occupied)
        #expect(town.buildings.count == 1)
    }

    @Test func buildFailsOutOfBounds() {
        var town = TestFixtures.town(1)
        #expect(system.build(.house, at: GridCoordinate(x: 3, y: 0), in: &town, balance: balance) == .outOfBounds)
        #expect(system.build(.house, at: GridCoordinate(x: 0, y: -1), in: &town, balance: balance) == .outOfBounds)
    }

    @Test func buildFailsWithoutResources() {
        var town = TestFixtures.town(1, resources: [.gold: 5, .skill: 5])
        #expect(system.build(.house, at: GridCoordinate(x: 0, y: 0), in: &town, balance: balance) == .insufficientResources)
    }

    @Test func secondPierIsRejected() {
        var town = TestFixtures.town(1, buildings: [TestFixtures.building(1, kind: .pier, x: 0, y: 2)])
        #expect(system.build(.pier, at: GridCoordinate(x: 2, y: 0), in: &town, balance: balance) == .duplicatePier)
    }

    @Test func pierRequiresTownEdge() {
        var town = TestFixtures.town(1)
        // Center of the 3x3 grid touches no edge.
        #expect(system.build(.pier, at: GridCoordinate(x: 1, y: 1), in: &town, balance: balance) == .placementRule)
        #expect(system.build(.pier, at: GridCoordinate(x: 0, y: 1), in: &town, balance: balance) == nil)
    }

    @Test func upgradeRaisesLevelAndChargesScaledCost() {
        let house = TestFixtures.building(1, kind: .house, x: 0, y: 0)
        var town = TestFixtures.town(1, resources: [.gold: 100, .skill: 50, .people: 0], buildings: [house])
        let failure = system.upgrade(house.id, in: &town, balance: balance)
        #expect(failure == nil)
        #expect(town.buildings[0].level == 2)
        // Level-2 house costs base x2 (50g/20s) and moves in 8 more people (4 x level 2).
        #expect(town.resources[.gold] == 50)
        #expect(town.resources[.skill] == 30)
        #expect(town.resources[.people] == 8)
    }

    @Test func upgradeStopsAtMaxLevel() {
        let house = TestFixtures.building(1, kind: .house, x: 0, y: 0, level: 3)
        var town = TestFixtures.town(1, buildings: [house])
        #expect(system.upgrade(house.id, in: &town, balance: balance) == .maxLevel)
    }

    @Test func upgradeFailsWithoutResources() {
        let house = TestFixtures.building(1, kind: .house, x: 0, y: 0)
        var town = TestFixtures.town(1, resources: [.gold: 10, .skill: 10], buildings: [house])
        #expect(system.upgrade(house.id, in: &town, balance: balance) == .insufficientResources)
        #expect(town.buildings[0].level == 1)
    }
}
