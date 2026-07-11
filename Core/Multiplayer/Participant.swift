import Foundation

/// A person in a room. Cooperative mode: every participant jointly controls
/// the player empire; roles only gate lobby administration, never gameplay.
struct Participant: Codable, Equatable, Identifiable {
    enum Role: String, Codable, Equatable {
        /// Administers the lobby (kick, start). Reassigned when the owner
        /// leaves; there is no gameplay host.
        case owner
        case member
    }

    var id: String
    var displayName: String
    var role: Role
    /// Server timestamp, ms since epoch.
    var joinedAtMillis: Int64
}
