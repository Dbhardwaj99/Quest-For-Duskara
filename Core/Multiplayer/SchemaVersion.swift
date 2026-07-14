import Foundation

/// Versions stamped into every replicated payload so clients and the server
/// can refuse to apply data they do not understand.
enum SchemaVersion {
    /// Wire/persistence schema of WorldDefinition, MatchState and patches.
    /// 2: factions replaced by per-player ownerID, humanPlayerIDs and
    /// winnerPlayerID added, trade offers reference partner player IDs.
    static let current = 2
    /// Gameplay rules version. Bumped whenever reducer behavior changes so
    /// mixed-version rooms reject actions instead of diverging.
    /// 2: PvP ownership rules, per-player win/lose, all AI islands act.
    static let rules = 2
}
