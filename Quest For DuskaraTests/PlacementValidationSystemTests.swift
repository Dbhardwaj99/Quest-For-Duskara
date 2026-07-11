import Foundation
import Testing

@Suite("PlacementValidationSystem")
struct PlacementValidationSystemTests {
    let system = PlacementValidationSystem()
    let balance = TestFixtures.balance

    @Test func houseIsValidOnAnyFreeCell() {
        let town = TestFixtures.town(1, buildings: [TestFixtures.building(1, kind: .house, x: 1, y: 1)])
        let coordinates = system.validCoordinates(for: .house, in: town, balance: balance)
        #expect(coordinates.count == 8)
        #expect(coordinates.contains(GridCoordinate(x: 1, y: 1)) == false)
    }

    @Test func pierIsOnlyValidOnTheEdgeRing() {
        let town = TestFixtures.town(1)
        let coordinates = system.validCoordinates(for: .pier, in: town, balance: balance)
        // 3x3 grid: everything except the center is shoreline.
        #expect(coordinates.count == 8)
        #expect(coordinates.contains(GridCoordinate(x: 1, y: 1)) == false)
    }

    @Test func nothingIsValidWithoutResources() {
        let town = TestFixtures.town(1, resources: [.gold: 0, .skill: 0])
        #expect(system.validCoordinates(for: .house, in: town, balance: balance).isEmpty)
    }

    @Test func barracksRequiresFreePeople() {
        // Barracks needs 4 workers; town has 3 people and no committed workers.
        let town = TestFixtures.town(1, resources: [.gold: 500, .skill: 300, .people: 3])
        #expect(
            system.canPlace(.barracks, on: GridCoordinate(x: 0, y: 0), in: town, balance: balance)
                == .insufficientPeople
        )
    }

    @Test func workersCommittedToBuildingsReduceFreePeople() {
        // Farm commits 2 workers; a second farm needs 2 free of the 3 people.
        let town = TestFixtures.town(
            1,
            resources: [.gold: 500, .skill: 300, .people: 3],
            buildings: [TestFixtures.building(1, kind: .farm, x: 0, y: 0)]
        )
        #expect(
            system.canPlace(.farm, on: GridCoordinate(x: 1, y: 0), in: town, balance: balance)
                == .insufficientPeople
        )
    }
}
