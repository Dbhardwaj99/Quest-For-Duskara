import FirebaseFirestore
import FirebaseFunctions

struct RoomSnapshot: Equatable {
    var session: RoomSession
    var readyParticipantIDs: Set<String>
    var isFromCache: Bool
}

@MainActor
final class FirestoreRoomRepository {
    private let store: Firestore
    private let functions: Functions

    init(store: Firestore = .firestore(), functions: Functions = .functions()) {
        self.store = store
        self.functions = functions
    }

    func createPrivateRoom(displayName: String) async throws -> RoomSession {
        try await callRoom("createRoom", data: ["visibility": "privateCode", "displayName": displayName])
    }

    func joinPrivateRoom(code: String, displayName: String) async throws -> RoomSession {
        try await callRoom("joinRoom", data: ["inviteCode": code, "displayName": displayName])
    }

    func rejoin(roomID: String) async throws -> RoomSession {
        try await callRoom("joinRoom", data: ["roomID": roomID])
    }

    func leave(roomID: String) async throws {
        _ = try await functions.httpsCallable("leaveRoom").call(["roomID": roomID])
    }

    func setReady(roomID: String, ready: Bool) async throws {
        _ = try await functions.httpsCallable("setLobbyReady").call(["roomID": roomID, "ready": ready])
    }

    func start(roomID: String) async throws -> RoomSession {
        try await callRoom("startRoom", data: ["roomID": roomID])
    }

    func joinMatchmaking(displayName: String) async throws -> RoomSession? {
        let result = try await functions.httpsCallable("joinMatchmaking").call(["displayName": displayName])
        guard let value = result.data as? [String: Any], value["room"] != nil else { return nil }
        return try decode(RoomSession.self, from: value["room"] as Any)
    }

    func cancelMatchmaking() async throws {
        _ = try await functions.httpsCallable("cancelMatchmaking").call()
    }

    func verifyMembership(roomID: String) async throws -> RoomSession {
        try await callRoom("fetchCheckpoint", data: ["roomID": roomID], key: "room")
    }

    func observe(roomID: String, onChange: @escaping @MainActor (Result<RoomSnapshot, Error>) -> Void) -> ListenerRegistration {
        store.collection("rooms").document(roomID).addSnapshotListener { snapshot, error in
            Task { @MainActor in
                if let error { onChange(.failure(error)); return }
                guard let snapshot, snapshot.exists else {
                    onChange(.failure(RoomRepositoryError.roomUnavailable)); return
                }
                do { onChange(.success(try Self.roomSnapshot(snapshot))) }
                catch { onChange(.failure(error)) }
            }
        }
    }

    private func callRoom(_ name: String, data: [String: Any], key: String = "room") async throws -> RoomSession {
        let result = try await functions.httpsCallable(name).call(data)
        guard let value = result.data as? [String: Any], let room = value[key] else {
            throw RoomRepositoryError.invalidResponse
        }
        return try decode(RoomSession.self, from: room)
    }

    private func decode<T: Decodable>(_ type: T.Type, from value: Any) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
    }

    private static func roomSnapshot(_ document: DocumentSnapshot) throws -> RoomSnapshot {
        guard let data = document.data(),
              let roomValue = data["publicSession"] else { throw RoomRepositoryError.invalidResponse }
        let room = try JSONDecoder().decode(RoomSession.self, from: JSONSerialization.data(withJSONObject: roomValue))
        let ready = Set(data["readyParticipantIDs"] as? [String] ?? [])
        return RoomSnapshot(session: room, readyParticipantIDs: ready, isFromCache: document.metadata.isFromCache)
    }
}

enum RoomRepositoryError: LocalizedError {
    case invalidResponse, roomUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The multiplayer service returned an unreadable response."
        case .roomUnavailable: "This room is no longer available."
        }
    }
}
