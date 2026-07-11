import Foundation
import Testing

/// Pins the outcome of a scripted multi-day scenario so any change to the
/// rules is caught before the same logic is ported to the server reducer.
@Suite("Action outcome fixtures")
struct ActionOutcomeFixtureTests {
    let balance = TestFixtures.balance

    private func scriptedFinalState() -> GameState {
        let buildingSystem = BuildingSystem()
        let trainingSystem = SoldierTrainingSystem()
        let transferSystem = TransferSystem()
        let simulationSystem = SimulationSystem()
        let worldMapSystem = WorldMapSystem()

        var state = TestFixtures.state(
            towns: [
                TestFixtures.town(1, name: "Hearthglen", resources: [.gold: 500, .skill: 300, .food: 120, .people: 12], buildings: [
                    TestFixtures.building(1, kind: .house, x: 1, y: 1),
                    TestFixtures.building(2, kind: .pier, x: 1, y: 2)
                ]),
                TestFixtures.town(2, name: "Oakmere", faction: .player, resources: [.gold: 40, .food: 20, .people: 4]),
                TestFixtures.town(3, name: "Mosswatch", faction: .neutral, resources: [.gold: 80, .skill: 40, .food: 30], armyStrength: 8)
            ],
            connections: [
                TownConnection(from: TestFixtures.uuid(1), to: TestFixtures.uuid(2)),
                TownConnection(from: TestFixtures.uuid(2), to: TestFixtures.uuid(3))
            ]
        )

        // Build up the home island.
        _ = buildingSystem.build(.farm, at: GridCoordinate(x: 0, y: 0), in: &state.towns[0], balance: balance)
        _ = buildingSystem.build(.barracks, at: GridCoordinate(x: 2, y: 0), in: &state.towns[0], balance: balance)

        // BuildingSystem.build mints random UUIDs on the client; pin them so
        // the fixture is stable. Server-created IDs replace this later.
        for (offset, index) in state.towns[0].buildings.indices.enumerated() {
            state.towns[0].buildings[index].id = TestFixtures.uuid(1001 + offset)
        }

        // Raise a small force.
        _ = trainingSystem.train(.archer, in: &state.towns[0], balance: balance)
        _ = trainingSystem.train(.archer, in: &state.towns[0], balance: balance)
        _ = trainingSystem.train(.knight, in: &state.towns[0], balance: balance)

        // Ship supplies to the second town.
        _ = transferSystem.transfer(
            order: TransferOrder(fromTownID: TestFixtures.uuid(1), toTownID: TestFixtures.uuid(2), amounts: [.gold: 50, .food: 20]),
            state: &state
        )

        // Take the neutral island.
        _ = worldMapSystem.attack(targetID: TestFixtures.uuid(3), from: TestFixtures.uuid(1), state: &state, balance: balance)

        // Let three days of production, upkeep and income pass.
        for _ in 0..<3 {
            simulationSystem.advanceDay(state: &state, balance: balance)
        }
        return state
    }

    @Test func scriptedScenarioIsDeterministic() {
        #expect(scriptedFinalState() == scriptedFinalState())
    }

    @Test func scriptedScenarioMatchesGoldenFixture() throws {
        // GameState's Codable form encodes enum-keyed dictionaries as
        // unordered flat arrays, so raw JSON is not byte-stable. Pin an
        // explicitly ordered snapshot instead; commit "replicated action and
        // state boundaries" introduces real wire DTOs for the same reason.
        try GoldenFixture.assertMatches(StateSnapshot(of: scriptedFinalState()), fixture: "action-outcomes-scenario1.json")
    }
}

/// Fully ordered, string-keyed mirror of the gameplay-relevant state.
private struct StateSnapshot: Codable {
    struct BuildingSnapshot: Codable {
        var id: UUID
        var kind: String
        var x: Int
        var y: Int
        var level: Int
    }

    struct TownSnapshot: Codable {
        var id: UUID
        var name: String
        var faction: String
        var isDuskara: Bool
        var armyStrength: Int
        var resources: [String: Int]
        var roster: [String: Int]
        var buildings: [BuildingSnapshot]
    }

    var day: Int
    var elapsedSecondsInDay: Double
    var status: String
    var connections: [String]
    var newsMessages: [String]
    var towns: [TownSnapshot]

    init(of state: GameState) {
        day = state.day
        elapsedSecondsInDay = state.elapsedSecondsInDay
        status = state.status.rawValue
        connections = state.connections.canonicallySorted().map(\.id)
        newsMessages = state.newsEvents.map(\.message)
        towns = state.towns.map { town in
            TownSnapshot(
                id: town.id,
                name: town.name,
                faction: town.faction.rawValue,
                isDuskara: town.isDuskara,
                armyStrength: town.armyStrength,
                resources: Dictionary(uniqueKeysWithValues: town.resources.amounts.map { ($0.key.rawValue, $0.value) }),
                roster: Dictionary(uniqueKeysWithValues: town.soldierRoster.counts.map { ($0.key.rawValue, $0.value) }),
                buildings: town.buildings
                    .map { BuildingSnapshot(id: $0.id, kind: $0.kind.rawValue, x: $0.coordinate.x, y: $0.coordinate.y, level: $0.level) }
                    .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            )
        }
    }
}
