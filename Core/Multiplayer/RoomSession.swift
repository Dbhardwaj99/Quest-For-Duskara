import Foundation

/// Everything the authority provides to start a match. The world itself is
/// regenerated deterministically from `seed` on every device; identity is
/// the opposite — player IDs are opaque, server-assigned, and never derived
/// from the seed.
struct MatchConfig: Codable, Equatable {
    /// World seed minted by the match creator (the server in multiplayer).
    var seed: Int
    /// Server-assigned human player IDs, in join order.
    var humanPlayerIDs: [String]
    /// Complete island assignment from the server: town ID string -> owning
    /// player ID (starting islands for humans, an AI player for the rest).
    /// Nil for local matches, where the app is the authority and assigns
    /// owners itself.
    var ownerAssignments: [String: String]?

    static func mintAIPlayerID() -> String {
        "ai-\(UUID().uuidString)"
    }

    /// Local single-player match: the app mints the identities it needs.
    static func localSinglePlayer(seed: Int) -> MatchConfig {
        MatchConfig(seed: seed, humanPlayerIDs: ["local-\(UUID().uuidString)"], ownerAssignments: nil)
    }
}

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
