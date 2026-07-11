import FirebaseFirestore
import Observation

@MainActor
@Observable
final class RoomLobbyViewModel {
    enum ScreenState: Equatable {
        case idle, loading, matchmaking, lobby, offline
    }

    private(set) var screenState: ScreenState = .idle
    private(set) var session: RoomSession?
    private(set) var readyParticipantIDs: Set<String> = []
    private(set) var isStale = false
    var displayName = "Wayfarer"
    var inviteCode = ""
    var errorMessage: String?

    private let auth: FirebaseAuthSession
    private let rooms: FirestoreRoomRepository
    private var listener: ListenerRegistration?

    init(auth: FirebaseAuthSession? = nil, rooms: FirestoreRoomRepository? = nil) {
        self.auth = auth ?? FirebaseAuthSession()
        self.rooms = rooms ?? FirestoreRoomRepository()
    }

    var canRejoin: Bool { UserDefaults.standard.string(forKey: "multiplayer.lastRoomID") != nil }
    var isOwner: Bool { session?.isLocalOwner == true }
    var localIsReady: Bool { session.map { readyParticipantIDs.contains($0.localParticipantID) } ?? false }

    func open() async {
        screenState = .loading
        do {
            _ = try await auth.authenticate()
            screenState = .idle
        } catch { fail(error, offline: true) }
    }

    func createPrivateRoom() async { await roomOperation { try await rooms.createPrivateRoom(displayName: displayName) } }

    func joinPrivateRoom() async {
        let normalized = inviteCode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard normalized.count >= 6 else { errorMessage = "Enter the six-character room code."; return }
        await roomOperation { try await rooms.joinPrivateRoom(code: normalized, displayName: displayName) }
    }

    func rejoinLastRoom() async {
        guard let roomID = UserDefaults.standard.string(forKey: "multiplayer.lastRoomID") else { return }
        await roomOperation { try await rooms.rejoin(roomID: roomID) }
    }

    func joinMatchmaking() async {
        screenState = .loading
        do {
            _ = try await auth.authenticate()
            if let room = try await rooms.joinMatchmaking(displayName: displayName) { joined(room) }
            else { screenState = .matchmaking }
        } catch { fail(error, offline: true) }
    }

    func cancelMatchmaking() async {
        do { try await rooms.cancelMatchmaking(); screenState = .idle }
        catch { fail(error) }
    }

    func toggleReady() async {
        guard let roomID = session?.roomID else { return }
        do { try await rooms.setReady(roomID: roomID, ready: !localIsReady) }
        catch { fail(error) }
    }

    func startRoom() async {
        guard let roomID = session?.roomID else { return }
        screenState = .loading
        do { joined(try await rooms.start(roomID: roomID)) }
        catch { fail(error) }
    }

    func leaveRoom() async {
        guard let roomID = session?.roomID else { return }
        listener?.remove()
        do { try await rooms.leave(roomID: roomID) }
        catch { errorMessage = error.localizedDescription }
        session = nil
        screenState = .idle
    }

    private func roomOperation(_ operation: () async throws -> RoomSession) async {
        screenState = .loading
        do { _ = try await auth.authenticate(); joined(try await operation()) }
        catch { fail(error, offline: true) }
    }

    private func joined(_ room: RoomSession) {
        session = room
        screenState = .lobby
        isStale = false
        UserDefaults.standard.set(room.roomID, forKey: "multiplayer.lastRoomID")
        listener?.remove()
        listener = rooms.observe(roomID: room.roomID) { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(snapshot):
                session = snapshot.session
                readyParticipantIDs = snapshot.readyParticipantIDs
                isStale = snapshot.isFromCache
                screenState = snapshot.isFromCache ? .offline : .lobby
            case let .failure(error): fail(error, offline: true)
            }
        }
    }

    private func fail(_ error: Error, offline: Bool = false) {
        errorMessage = error.localizedDescription
        screenState = offline ? .offline : .idle
    }
}
