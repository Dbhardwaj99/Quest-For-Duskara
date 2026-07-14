import Foundation
import Testing

@MainActor
@Suite("Multiplayer replication")
struct MultiplayerReplicationTests {
    private func match(revision: Int = 0) -> MatchState {
        MatchState(
            roomID: "room-1", revision: revision, schemaVersion: SchemaVersion.current, rulesVersion: SchemaVersion.rules,
            status: .active, humanPlayerIDs: [TestFixtures.humanPlayer], winnerPlayerID: nil,
            day: 1, dayStartServerMillis: 1000,
            towns: [TownState(id: TestFixtures.uuid(1).uuidString, ownerID: TestFixtures.humanPlayer, armyStrength: 0, resources: ["gold": 100], soldiers: [:], buildings: [])],
            news: [], tradeOffers: [], entityCounter: 0
        )
    }

    private func patch(revision: Int, gold: Int = 90) -> GameStatePatch {
        GameStatePatch(
            revision: revision, actionID: "action-\(revision)", day: 1,
            dayStartServerMillis: 1000, status: .active, winnerPlayerID: nil,
            updatedTowns: [TownState(id: TestFixtures.uuid(1).uuidString, ownerID: TestFixtures.humanPlayer, armyStrength: 0, resources: ["gold": gold], soldiers: [:], buildings: [])],
            appendedNews: [], tradeOffers: [], entityCounter: revision
        )
    }

    @Test func appliesNextRevision() throws {
        var value = match()
        try patch(revision: 1).apply(to: &value)
        #expect(value.revision == 1)
        #expect(value.towns[0].resources["gold"] == 90)
    }

    @Test func duplicatePatchIsIgnoredByCoordinator() {
        var value = match(revision: 1)
        #expect(throws: GameStatePatch.ApplicationError.duplicate) { try patch(revision: 1).apply(to: &value) }
        #expect(value.revision == 1)
    }

    @Test func revisionGapRequiresCheckpointRecovery() throws {
        var value = match()
        #expect(throws: GameStatePatch.ApplicationError.revisionGap(expected: 1, received: 3)) {
            try patch(revision: 3).apply(to: &value)
        }
        value = match(revision: 2)
        try patch(revision: 3, gold: 70).apply(to: &value)
        #expect(value.revision == 3)
        #expect(value.towns[0].resources["gold"] == 70)
    }

    @Test func cacheKeepsOnlyRecoveryFieldsAndPendingIDs() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "duskara-cache-\(UUID().uuidString).json")
        let cache = LocalRoomCache(fileURL: url)
        let action = GameAction(actionID: "pending-action", participantID: "p1", expectedRevision: 4, payload: .advanceDay)
        try cache.save(CachedRoomState(roomID: "room-1", checkpoint: match(revision: 4), lastAppliedRevision: 4, pendingActions: [action]))
        let loaded = try #require(cache.load())
        #expect(loaded.roomID == "room-1")
        #expect(loaded.lastAppliedRevision == 4)
        #expect(loaded.pendingActions.map(\.actionID) == ["pending-action"])
        cache.clear()
    }

    @Test func remoteFailureDoesNotMutateAuthoritativeState() async {
        let gateway = FailingGateway()
        let before = match(revision: 2)
        do {
            _ = try await gateway.submit(GameAction(participantID: "untrusted", expectedRevision: 2, payload: .advanceDay), roomID: "room-1")
            Issue.record("Expected the gateway to fail")
        } catch { }
        #expect(before == match(revision: 2))
        #expect(gateway.submissions == 1)
    }
}

@MainActor
private final class FailingGateway: RemoteGameCommandDispatching {
    private(set) var submissions = 0
    func submit(_ action: GameAction, roomID: String) async throws -> GameActionResult {
        submissions += 1
        throw URLError(.notConnectedToInternet)
    }
}
