import FirebaseDatabase
import Foundation

@MainActor
final class RealtimePresenceRepository {
    private let root: DatabaseReference
    private var connection: DatabaseReference?
    private var observer: DatabaseHandle?

    init(database: Database = .database()) { root = database.reference() }

    func connect(roomID: String, participantID: String) async throws {
        disconnect()
        let ref = root.child("presence/\(roomID)/\(participantID)/connections/\(UUID().uuidString)")
        try await ref.onDisconnectRemoveValue()
        try await ref.setValue(["connectedAt": ServerValue.timestamp()])
        connection = ref
    }

    func observe(roomID: String, onChange: @escaping @MainActor (Set<String>) -> Void) {
        if let observer { root.child("presence/\(roomID)").removeObserver(withHandle: observer) }
        let ref = root.child("presence/\(roomID)")
        observer = ref.observe(.value) { snapshot in
            let online = Set(snapshot.children.compactMap { child -> String? in
                guard let participant = child as? DataSnapshot,
                      participant.childSnapshot(forPath: "connections").childrenCount > 0 else { return nil }
                return participant.key
            })
            Task { @MainActor in onChange(online) }
        }
    }

    func disconnect() {
        if let connection { connection.removeValue() }
        connection = nil
        if let observer { root.removeObserver(withHandle: observer) }
        observer = nil
    }
}
