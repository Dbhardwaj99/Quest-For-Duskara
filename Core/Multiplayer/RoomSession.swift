import Foundation

/// Client-side snapshot of a joined room: identity, membership, and where
/// the local player sits in it. Live replication state (revision cursor,
/// subscriptions) belongs to the replication service, not this value.
struct RoomSession: Codable, Equatable {
    enum Visibility: String, Codable, Equatable {
        case privateCode
        case publicMatchmaking
    }

    var roomID: String
    var visibility: Visibility
    /// Human-enterable invite code for private rooms. Only ever the
    /// normalized display form; the backend stores a hash.
    var inviteCode: String?
    var localParticipantID: String
    var participants: [Participant]
    var status: MatchStatus

    var localParticipant: Participant? {
        participants.first { $0.id == localParticipantID }
    }

    var isLocalOwner: Bool {
        localParticipant?.role == .owner
    }
}
