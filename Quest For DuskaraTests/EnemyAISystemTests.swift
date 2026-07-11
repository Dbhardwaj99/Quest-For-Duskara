import Foundation
import Testing

@Suite("EnemyAISystem")
struct EnemyAISystemTests {
    let system = EnemyAISystem()
    let balance = TestFixtures.balance

    @Test func actsEveryTwentiethDay() {
        #expect(system.shouldAct(on: 20))
        #expect(system.shouldAct(on: 40))
        #expect(system.shouldAct(on: 19) == false)
        #expect(system.shouldAct(on: 21) == false)
    }

    @Test func buildsMissingInfrastructureInPriorityOrder() {
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1),
            TestFixtures.town(2, faction: .enemy, resources: [.gold: 500, .skill: 300, .food: 100, .people: 10])
        ])
        system.takeTurn(state: &state, balance: balance)
        // House is first in the priority list and the town has none.
        #expect(state.towns[1].buildings.count == 1)
        #expect(state.towns[1].buildings[0].kind == .house)
        // Player towns are never touched.
        #expect(state.towns[0].buildings.isEmpty)
    }

    @Test func trainsSoldiersWhenBarracksExists() {
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1),
            TestFixtures.town(
                2,
                faction: .enemy,
                // 20 people: the five buildings commit 11 workers, leaving free hands to train.
                resources: [.gold: 500, .skill: 300, .food: 100, .people: 20],
                buildings: [
                    TestFixtures.building(1, kind: .house, x: 1, y: 1),
                    TestFixtures.building(2, kind: .pier, x: 0, y: 2),
                    TestFixtures.building(3, kind: .farm, x: 0, y: 0),
                    TestFixtures.building(4, kind: .barracks, x: 2, y: 0),
                    TestFixtures.building(5, kind: .factory, x: 2, y: 2)
                ]
            )
        ])
        system.takeTurn(state: &state, balance: balance)
        #expect(state.towns[1].soldierRoster[.archer] == 1)
        #expect(state.towns[1].armyStrength == 10)
    }

    @Test func attacksAdjacentWeakerTownWhenEconomyIsStable() {
        var roster = SoldierRoster()
        roster.add(.archer, count: 5)
        var state = TestFixtures.state(
            towns: [
                TestFixtures.town(1),
                TestFixtures.town(
                    2,
                    faction: .enemy,
                    resources: [.gold: 500, .skill: 300, .food: 100, .people: 10],
                    buildings: [
                        TestFixtures.building(1, kind: .house, x: 1, y: 1),
                        TestFixtures.building(2, kind: .pier, x: 0, y: 2),
                        TestFixtures.building(3, kind: .farm, x: 0, y: 0),
                        TestFixtures.building(4, kind: .barracks, x: 2, y: 0),
                        TestFixtures.building(5, kind: .factory, x: 2, y: 2)
                    ],
                    armyStrength: 50,
                    soldierRoster: roster
                ),
                TestFixtures.town(3, faction: .neutral, armyStrength: 5)
            ],
            connections: [
                TownConnection(from: TestFixtures.uuid(2), to: TestFixtures.uuid(3))
            ]
        )
        system.takeTurn(state: &state, balance: balance)
        #expect(state.towns[2].faction == .enemy)
    }

    @Test func holdsPositionWithoutStableEconomy() {
        // No farm: projected food surplus is negative, so the AI never attacks.
        var roster = SoldierRoster()
        roster.add(.archer, count: 5)
        var state = TestFixtures.state(
            towns: [
                TestFixtures.town(1),
                TestFixtures.town(
                    2,
                    faction: .enemy,
                    resources: [.gold: 500, .skill: 300, .food: 100, .people: 10],
                    armyStrength: 50,
                    soldierRoster: roster
                ),
                TestFixtures.town(3, faction: .neutral, armyStrength: 5)
            ],
            connections: [
                TownConnection(from: TestFixtures.uuid(2), to: TestFixtures.uuid(3))
            ]
        )
        system.takeTurn(state: &state, balance: balance)
        #expect(state.towns[2].faction == .neutral)
    }

    @Test func reassignsActiveTownWhenPlayerLosesIt() {
        var state = TestFixtures.state(
            towns: [
                TestFixtures.town(1, faction: .neutral),
                TestFixtures.town(2)
            ],
            activeTownID: TestFixtures.uuid(1)
        )
        system.takeTurn(state: &state, balance: balance)
        #expect(state.activeTownID == TestFixtures.uuid(2))
    }
}
