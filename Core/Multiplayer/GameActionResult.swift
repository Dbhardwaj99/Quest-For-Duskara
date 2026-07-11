import Foundation

/// Authoritative outcome of a submitted GameAction, returned to the
/// initiating client and mirrored by the accepted patch stream.
struct GameActionResult: Codable, Equatable {
    enum Status: String, Codable, Equatable {
        case accepted
        /// The action was valid but not applied (rule violation, stale
        /// revision, version mismatch). `rejectionReason` explains why.
        case rejected
        /// The idempotency key was already applied; the stored outcome is
        /// returned unchanged.
        case duplicate
    }

    var actionID: String
    var status: Status
    /// Match revision after handling the action.
    var revision: Int
    var rejectionReason: String?
    /// Present when the action was accepted (or was a duplicate of an
    /// accepted action).
    var patch: GameStatePatch?
}
