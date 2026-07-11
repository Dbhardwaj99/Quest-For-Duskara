import Foundation
import Testing

@Suite("Replication boundary")
struct ReplicationBoundaryTests {
    let balance = TestFixtures.balance

    private func generatedState() -> GameState {
        WorldMapSystem().makeInitialState(balance: balance)
    }

    @Test func worldAndMatchRoundTripLosslessly() throws {
        var state = generatedState()
        state.day = 7
        state.newsEvents = [NewsEvent(id: TestFixtures.uuid(500), day: 3, kind: .cityCapture, message: "You captured Oakmere")]

        let world = WorldDefinition(state: state)
        let match = MatchState(state: state, roomID: "room-1", revision: 12)
        let rebuilt = try GameState(world: world, match: match)

        #expect(rebuilt.day == state.day)
        #expect(rebuilt.towns == state.towns)
        #expect(rebuilt.worldNodes == state.worldNodes)
        #expect(Set(rebuilt.connections) == Set(state.connections))
        #expect(rebuilt.world == state.world)
        #expect(rebuilt.territory == state.territory)
        #expect(rebuilt.status == state.status)
        #expect(rebuilt.newsEvents == state.newsEvents)
        #expect(match.roomID == "room-1")
        #expect(match.revision == 12)
        #expect(match.schemaVersion == SchemaVersion.current)
        #expect(match.rulesVersion == SchemaVersion.rules)
    }

    @Test func territoryOwnershipIsDerivedNotStored() throws {
        var state = generatedState()
        let world = WorldDefinition(state: state)

        // Capture a neutral town, then reassemble from the same immutable
        // world data: ownership must follow the new faction.
        guard let neutralIndex = state.towns.firstIndex(where: { $0.faction == .neutral }) else {
            Issue.record("expected a neutral town")
            return
        }
        state.towns[neutralIndex].faction = .player
        let match = MatchState(state: state, roomID: "room-1", revision: 1)
        let rebuilt = try GameState(world: world, match: match)
        let region = rebuilt.territory.region(for: state.towns[neutralIndex].id)
        #expect(region?.ownerFaction == .player)
    }

    @Test func wireFormsContainNoEnumKeyedDictionaries() throws {
        // The encoded contract must stay portable: string-keyed objects only.
        let state = generatedState()
        let data = try GoldenFixture.canonicalJSON(MatchState(state: state, roomID: "r", revision: 0))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let towns = object?["towns"] as? [[String: Any]]
        #expect(towns?.first?["resources"] is [String: Any])
        #expect(towns?.first?["soldiers"] is [String: Any])
    }

    @Test func actionPayloadUsesTypeDiscriminator() throws {
        let action = GameAction(
            actionID: "a-1",
            participantID: "p-1",
            expectedRevision: 4,
            payload: .build(townID: TestFixtures.uuid(1).uuidString, kind: "farm", x: 1, y: 2)
        )
        let data = try GoldenFixture.canonicalJSON(action)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = object?["payload"] as? [String: Any]
        #expect(payload?["type"] as? String == "build")
        #expect(payload?["kind"] as? String == "farm")
        #expect(object?["expectedRevision"] as? Int == 4)

        let decoded = try JSONDecoder().decode(GameAction.self, from: data)
        #expect(decoded == action)
    }

    @Test func payloadRoundTripsAllCases() throws {
        let payloads: [GameActionPayload] = [
            .build(townID: "t", kind: "house", x: 0, y: 1),
            .upgradeBuilding(townID: "t", buildingID: "b"),
            .trainSoldier(townID: "t", soldier: "archer"),
            .transferResources(fromTownID: "a", toTownID: "b", amounts: ["gold": 5]),
            .attack(fromTownID: "a", targetTownID: "b"),
            .advanceDay
        ]
        for payload in payloads {
            let data = try JSONEncoder().encode(payload)
            #expect(try JSONDecoder().decode(GameActionPayload.self, from: data) == payload)
        }
    }
}

@Suite("LocalCommandDispatcher")
@MainActor
struct LocalCommandDispatcherTests {
    let balance = TestFixtures.balance

    private func makeAction(_ payload: GameActionPayload, revision: Int) -> GameAction {
        GameAction(actionID: "test-\(revision)", participantID: "p1", expectedRevision: revision, payload: payload)
    }

    @Test func acceptedActionIncrementsRevisionAndEmitsPatch() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [TestFixtures.town(1)])
        let result = dispatcher.dispatch(
            makeAction(.build(townID: TestFixtures.uuid(1).uuidString, kind: "house", x: 0, y: 0), revision: 0),
            state: &state,
            balance: balance
        )
        #expect(result.status == .accepted)
        #expect(result.revision == 1)
        #expect(dispatcher.revision == 1)
        #expect(state.towns[0].buildings.count == 1)
        #expect(result.patch?.updatedTowns.count == 1)
        #expect(result.patch?.appendedNews.count == 1)
        // Patches carry only touched towns, never the world.
        #expect(result.patch?.updatedTowns.first?.id == TestFixtures.uuid(1).uuidString)
    }

    @Test func rejectedActionLeavesStateAndRevisionUntouched() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [TestFixtures.town(1, resources: [.gold: 0])])
        let before = state
        let result = dispatcher.dispatch(
            makeAction(.build(townID: TestFixtures.uuid(1).uuidString, kind: "house", x: 0, y: 0), revision: 0),
            state: &state,
            balance: balance
        )
        #expect(result.status == .rejected)
        #expect(result.rejectionReason == "Not enough resources.")
        #expect(dispatcher.revision == 0)
        #expect(state == before)
    }

    @Test func staleRevisionIsRejected() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [TestFixtures.town(1)])
        let result = dispatcher.dispatch(
            makeAction(.advanceDay, revision: 3),
            state: &state,
            balance: balance
        )
        #expect(result.status == .rejected)
        #expect(state.day == 1)
    }

    @Test func commandsAgainstForeignTownsAreRejected() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1),
            TestFixtures.town(2, faction: .neutral)
        ])
        let result = dispatcher.dispatch(
            makeAction(.build(townID: TestFixtures.uuid(2).uuidString, kind: "house", x: 0, y: 0), revision: 0),
            state: &state,
            balance: balance
        )
        #expect(result.status == .rejected)
        #expect(state.towns[1].buildings.isEmpty)
    }

    @Test func capturingDuskaraSetsDurableVictoryStatus() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, armyStrength: 500),
            TestFixtures.town(2, faction: .duskara, armyStrength: 10, isDuskara: true)
        ])
        let result = dispatcher.dispatch(
            makeAction(.attack(fromTownID: TestFixtures.uuid(1).uuidString, targetTownID: TestFixtures.uuid(2).uuidString), revision: 0),
            state: &state,
            balance: balance
        )
        #expect(result.status == .accepted)
        #expect(state.status == .victory)
        #expect(result.patch?.status == .victory)

        // Once decided, further commands are refused.
        let followUp = dispatcher.dispatch(makeAction(.advanceDay, revision: 1), state: &state, balance: balance)
        #expect(followUp.status == .rejected)
    }

    @Test func advanceDayRunsSimulation() {
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [
            TestFixtures.town(1, resources: [.gold: 10], buildings: [TestFixtures.building(1, kind: .pier, x: 0, y: 2)])
        ])
        let result = dispatcher.dispatch(makeAction(.advanceDay, revision: 0), state: &state, balance: balance)
        #expect(result.status == .accepted)
        #expect(state.day == 2)
        #expect(state.towns[0].resources[.gold] == 18)
    }
}
