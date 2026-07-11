import Foundation

/// Compact accepted-change record published after every applied action.
/// Carries only what changed; clients apply patches strictly in revision
/// order and fall back to the checkpoint when a gap appears. Full terrain
/// or full match state never travels through patches.
struct GameStatePatch: Codable, Equatable {
    /// Revision produced by applying this patch. A client at revision N may
    /// only apply the patch with revision N + 1.
    var revision: Int
    /// The action that produced this patch (server-side events use a
    /// server-minted ID).
    var actionID: String
    var day: Int
    var dayStartServerMillis: Int64
    var status: MatchStatus
    /// Complete replacement state for every town the action touched.
    var updatedTowns: [TownState]
    /// News appended by this action, newest first.
    var appendedNews: [NewsEventDTO]
}

extension GameStatePatch {
    /// Diffs two assembled states into a patch (used by the local
    /// single-player dispatcher and by contract tests; the server builds
    /// patches the same way).
    init(
        actionID: String,
        revision: Int,
        before: GameState,
        after: GameState,
        dayStartServerMillis: Int64 = 0
    ) {
        let beforeTowns = Dictionary(uniqueKeysWithValues: before.towns.map { ($0.id, $0) })
        self.revision = revision
        self.actionID = actionID
        self.day = after.day
        self.dayStartServerMillis = dayStartServerMillis
        self.status = after.status
        self.updatedTowns = after.towns
            .filter { beforeTowns[$0.id] != $0 }
            .map(TownState.init(town:))
        self.appendedNews = after.newsEvents
            .prefix(max(0, after.newsEvents.count - before.newsEvents.count))
            .map { NewsEventDTO(id: $0.id.uuidString, day: $0.day, kind: $0.kind.rawValue, message: $0.message) }
    }
}
