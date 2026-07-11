import FirebaseDatabase
import Observation

@MainActor
@Observable
final class RoomReplicationService {
    private(set) var room: RoomSession?
    private(set) var world: WorldDefinition?
    private(set) var match: MatchState?
    private(set) var state: GameState?
    private(set) var isStale = true
    private(set) var isRecovering = false
    private(set) var errorMessage: String?
    private(set) var serverClock = ServerClock()

    private let auth: FirebaseAuthSession
    private let rooms: FirestoreRoomRepository
    private let gateway: RemoteGameCommandDispatching
    private let cache: LocalRoomCache
    private let database: Database
    private var patchRef: DatabaseReference?
    private var patchHandle: DatabaseHandle?
    private var roomID: String?

    init(
        auth: FirebaseAuthSession? = nil,
        rooms: FirestoreRoomRepository? = nil,
        gateway: RemoteGameCommandDispatching? = nil,
        cache: LocalRoomCache? = nil,
        database: Database = .database()
    ) {
        self.auth = auth ?? FirebaseAuthSession()
        self.rooms = rooms ?? FirestoreRoomRepository()
        self.gateway = gateway ?? MultiplayerCommandGateway()
        self.cache = cache ?? LocalRoomCache()
        self.database = database
    }

    var revision: Int { match?.revision ?? 0 }

    func start(roomID: String) async throws {
        stop()
        self.roomID = roomID
        if let cached = cache.load(), cached.roomID == roomID, let checkpoint = cached.checkpoint {
            match = checkpoint
            isStale = true
        }
        _ = try await auth.authenticate()
        try await recoverCheckpoint()
        subscribe()
        await retryPendingActions()
    }

    func submit(_ payload: GameActionPayload) async -> GameActionResult {
        guard let roomID, let participantID = auth.participantID, !isStale else {
            return GameActionResult(actionID: UUID().uuidString, status: .rejected, revision: revision, rejectionReason: "Reconnect before changing the campaign.", patch: nil)
        }
        let action = GameAction(participantID: participantID, expectedRevision: revision, payload: payload)
        var pending = cache.load()?.pendingActions ?? []
        pending.append(action)
        try? cache.update(roomID: roomID, checkpoint: match, pending: pending)
        do {
            let result = try await gateway.submit(action, roomID: roomID)
            if let patch = result.patch { await receive(patch) }
            pending.removeAll { $0.actionID == action.actionID }
            try? cache.update(roomID: roomID, checkpoint: match, pending: pending)
            if result.status == .rejected, result.revision > revision { try? await recoverCheckpoint() }
            return result
        } catch {
            errorMessage = error.localizedDescription
            isStale = true
            return GameActionResult(actionID: action.actionID, status: .rejected, revision: revision, rejectionReason: "Command queued until reconnection.", patch: nil)
        }
    }

    func stop() {
        if let patchHandle, let patchRef { patchRef.removeObserver(withHandle: patchHandle) }
        patchHandle = nil
        patchRef = nil
    }

    private func subscribe() {
        guard let roomID else { return }
        let ref = database.reference(withPath: "patches/\(roomID)")
        patchRef = ref
        patchHandle = ref.queryOrderedByKey().queryStarting(afterValue: String(revision).leftPadded(to: 12)).observe(.childAdded) { [weak self] snapshot in
            guard JSONSerialization.isValidJSONObject(snapshot.value as Any),
                  let data = try? JSONSerialization.data(withJSONObject: snapshot.value as Any),
                  let patch = try? JSONDecoder().decode(GameStatePatch.self, from: data) else { return }
            Task { @MainActor in await self?.receive(patch) }
        }
    }

    private func receive(_ patch: GameStatePatch) async {
        guard var match else { return }
        do {
            try patch.apply(to: &match)
            self.match = match
            try assembleState()
            try? cache.update(roomID: roomID ?? match.roomID, checkpoint: match)
        } catch GameStatePatch.ApplicationError.duplicate {
            return
        } catch GameStatePatch.ApplicationError.revisionGap {
            try? await recoverCheckpoint()
        } catch {
            errorMessage = error.localizedDescription
            isStale = true
        }
    }

    private func recoverCheckpoint() async throws {
        guard let roomID else { return }
        isRecovering = true
        defer { isRecovering = false }
        let checkpoint = try await rooms.fetchCheckpoint(roomID: roomID)
        room = checkpoint.room
        world = checkpoint.world
        match = checkpoint.match
        serverClock.synchronize(serverNowMillis: checkpoint.serverNowMillis)
        try assembleState()
        isStale = false
        try? cache.update(roomID: roomID, checkpoint: checkpoint.match)
    }

    private func assembleState() throws {
        guard let world, let match else { return }
        state = try GameState(world: world, match: match)
    }

    private func retryPendingActions() async {
        guard let roomID else { return }
        var pending = cache.load()?.pendingActions ?? []
        for action in pending {
            do {
                let result = try await gateway.submit(action, roomID: roomID)
                if let patch = result.patch { await receive(patch) }
                pending.removeAll { $0.actionID == action.actionID }
                try? cache.update(roomID: roomID, checkpoint: match, pending: pending)
            } catch { break }
        }
    }
}

private extension String {
    func leftPadded(to length: Int) -> String { String(repeating: "0", count: max(0, length - count)) + self }
}
