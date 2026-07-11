import Foundation
import Testing

@Suite("CombatSystem")
struct CombatSystemTests {
    let system = CombatSystem()
    let balance = TestFixtures.balance

    /// duskara(1) - mid(2) - far(3) chain.
    private func chainState() -> GameState {
        TestFixtures.state(
            towns: [
                TestFixtures.town(1, faction: .duskara, armyStrength: 100, isDuskara: true),
                TestFixtures.town(2, faction: .neutral, armyStrength: 20),
                TestFixtures.town(3, faction: .neutral, armyStrength: 20)
            ],
            connections: [
                TownConnection(from: TestFixtures.uuid(1), to: TestFixtures.uuid(2)),
                TownConnection(from: TestFixtures.uuid(2), to: TestFixtures.uuid(3))
            ]
        )
    }

    @Test func graphDistancesAreBreadthFirst() {
        let state = chainState()
        let distances = CombatSystem.graphDistances(from: TestFixtures.uuid(1), connections: state.connections)
        #expect(distances[TestFixtures.uuid(1)] == 0)
        #expect(distances[TestFixtures.uuid(2)] == 1)
        #expect(distances[TestFixtures.uuid(3)] == 2)
    }

    @Test func defenseScalesWithGarrisonAndDistanceFromDuskara() {
        let state = chainState()
        // Far town sits at the archipelago edge: garrison 20 + 35% bonus (7).
        let far = state.towns[2]
        #expect(system.effectiveDefenseStrength(for: far, in: state, balance: balance) == 27)
        // Mid town is one step from the edge: +4 per step.
        let mid = state.towns[1]
        #expect(system.effectiveDefenseStrength(for: mid, in: state, balance: balance) == 31)
    }

    @Test func duskaraGetsCapitalBonus() {
        let state = chainState()
        let duskara = state.towns[0]
        // 100 garrison + 35 garrison bonus + 55 capital bonus + 8 for two steps from edge.
        #expect(system.effectiveDefenseStrength(for: duskara, in: state, balance: balance) == 198)
    }

    @Test func enemyCitiesGetImportantCityBonus() {
        var state = chainState()
        state.towns[2].faction = .enemy
        let enemyTown = state.towns[2]
        // 20 + 7 garrison bonus + 18 important-city bonus.
        #expect(system.effectiveDefenseStrength(for: enemyTown, in: state, balance: balance) == 45)
    }

    @Test func winnerSurvivorsAppliesCasualtyRate() {
        // Raw margin 10, casualties round(10 * 0.25) = 3 -> 7 survive.
        #expect(system.winnerSurvivors(attackStrength: 20, effectiveDefense: 10, balance: balance) == 7)
        // No margin means no survivors: attacker loses.
        #expect(system.winnerSurvivors(attackStrength: 10, effectiveDefense: 10, balance: balance) == 0)
        // Tiny margin still leaves at least one survivor.
        #expect(system.winnerSurvivors(attackStrength: 11, effectiveDefense: 10, balance: balance) == 1)
    }

    @Test func playerAttackCapturesTownAndAppliesPenalties() {
        let worldMapSystem = WorldMapSystem()
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, resources: [.gold: 100], armyStrength: 100),
            TestFixtures.town(2, faction: .neutral, resources: [.gold: 100, .skill: 50, .food: 30], armyStrength: 10)
        ])
        let won = worldMapSystem.attack(
            targetID: TestFixtures.uuid(2),
            from: TestFixtures.uuid(1),
            state: &state,
            balance: balance
        )
        #expect(won)
        #expect(state.towns[1].faction == .player)
        // Capture halves gold and skill; food is untouched.
        #expect(state.towns[1].resources[.gold] == 50)
        #expect(state.towns[1].resources[.skill] == 25)
        #expect(state.towns[1].resources[.food] == 30)
        // Attacker commits everything; survivors garrison the capture.
        #expect(state.towns[0].armyStrength == 0)
        // 100 vs 10+4=14 defense: raw 86, casualties round(86*0.25)=22 -> 64.
        #expect(state.towns[1].armyStrength == 64)
    }

    @Test func failedAttackDestroysCommittedForcesAndBleedsDefender() {
        let worldMapSystem = WorldMapSystem()
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, armyStrength: 100),
            TestFixtures.town(2, faction: .neutral, armyStrength: 90)
        ])
        // canAttack requires strength > defense, so call resolveAttack directly.
        let won = worldMapSystem.resolveAttack(
            sourceIndex: 0,
            targetIndex: 1,
            attackerFaction: .player,
            committedStrength: 50,
            state: &state,
            balance: balance
        )
        #expect(won == false)
        #expect(state.towns[0].armyStrength == 50)
        #expect(state.towns[1].faction == .neutral)
        // Defender loses garrison equal to the committed attack.
        #expect(state.towns[1].armyStrength == 40)
    }

    @Test func cannotAttackOwnOrFromForeignTowns() {
        let worldMapSystem = WorldMapSystem()
        let state = TestFixtures.state(towns: [
            TestFixtures.town(1, armyStrength: 100),
            TestFixtures.town(2, armyStrength: 5),
            TestFixtures.town(3, faction: .neutral, armyStrength: 5)
        ])
        #expect(worldMapSystem.canAttack(targetID: TestFixtures.uuid(2), from: TestFixtures.uuid(1), in: state, balance: balance) == false)
        #expect(worldMapSystem.canAttack(targetID: TestFixtures.uuid(3), from: TestFixtures.uuid(3), in: state, balance: balance) == false)
        #expect(worldMapSystem.canAttack(targetID: TestFixtures.uuid(3), from: TestFixtures.uuid(1), in: state, balance: balance))
    }
}
