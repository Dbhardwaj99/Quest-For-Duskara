import Foundation

/// Versions stamped into every replicated payload so clients and the server
/// can refuse to apply data they do not understand.
enum SchemaVersion {
    /// Wire/persistence schema of WorldDefinition, MatchState and patches.
    static let current = 1
    /// Gameplay rules version. Bumped whenever reducer behavior changes so
    /// mixed-version rooms reject actions instead of diverging.
    static let rules = 1
}
