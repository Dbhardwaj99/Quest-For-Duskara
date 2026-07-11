import Foundation
import Testing

@Suite("SimulationSystem")
struct SimulationSystemTests {
    let system = SimulationSystem()
    let balance = TestFixtures.balance

    @Test func advanceDayAppliesIncome() {
        var roster = SoldierRoster()
        roster.add(.archer, count: 1)
        var state = TestFixtures.state(towns: [
            TestFixtures.town(
                1,
                resources: [.gold: 10, .food: 10, .people: 5],
                buildings: [TestFixtures.building(1, kind: .farm, x: 0, y: 0)],
                armyStrength: 10,
                soldierRoster: roster
            )
        ])
        system.advanceDay(state: &state, balance: balance)

        #expect(state.day == 2)
        // Farm income +8 gold +14 food; one archer eats 2 food.
        #expect(state.towns[0].resources[.gold] == 18)
        #expect(state.towns[0].resources[.food] == 22)
        #expect(state.towns[0].armyStrength == 10)
    }

    @Test func starvingArmyDisbandsUnitsAndReturnsPeople() {
        var roster = SoldierRoster()
        roster.add(.knight, count: 2)
        var state = TestFixtures.state(towns: [
            TestFixtures.town(
                1,
                resources: [.gold: 0, .food: 0, .people: 0],
                armyStrength: 40,
                soldierRoster: roster
            )
        ])

        system.advanceDay(state: &state, balance: balance)

        // Both knights starve out: strength 0, their 4 people return home.
        #expect(state.towns[0].armyStrength == 0)
        #expect(state.towns[0].soldierRoster[.knight] == 0)
        #expect(state.towns[0].resources[.people] == 4)
        #expect(state.towns[0].resources[.soldiers] == 0)
    }

    @Test func enemyAIActsOnlyOnItsCadence() {
        func makeState(day: Int) -> GameState {
            TestFixtures.state(
                towns: [
                    TestFixtures.town(1),
                    TestFixtures.town(2, faction: .enemy, resources: [.gold: 500, .skill: 300, .food: 100, .people: 10])
                ],
                day: day
            )
        }

        // Day 18 -> 19: no AI action, the enemy town builds nothing.
        var quietState = makeState(day: 18)
        system.advanceDay(state: &quietState, balance: balance)
        #expect(quietState.towns[1].buildings.isEmpty)

        // Day 19 -> 20: AI cadence fires and develops infrastructure.
        var activeState = makeState(day: 19)
        system.advanceDay(state: &activeState, balance: balance)
        #expect(activeState.towns[1].buildings.count == 1)
        #expect(activeState.towns[1].buildings[0].kind == .house)
    }
}
