import Foundation

/// Local campaign save in the replicated wire format: the immutable world
/// and the mutable match are stored separately, exactly as a multiplayer
/// checkpoint would be. Local-only extras (display clock) sit alongside.
struct SavedGame: Codable, Equatable {
    var schemaVersion: Int
    var dayLabel: String
    var world: WorldDefinition
    var match: MatchState
    var elapsedSecondsInDay: TimeInterval
}

// Write-only for now: the game autosaves continuously, but every launch
// starts a new game, so nothing reads the file back yet.
struct GameSaveStore {
    static let localRoomID = "local"

    private let fileName = "duskara-save.json"

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func save(state: GameState, revision: Int = 0) throws {
        let savedGame = SavedGame(
            schemaVersion: SchemaVersion.current,
            dayLabel: dayLabel(for: state.day),
            world: WorldDefinition(state: state),
            match: MatchState(state: state, roomID: Self.localRoomID, revision: revision),
            elapsedSecondsInDay: state.elapsedSecondsInDay
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(savedGame)
        try data.write(to: saveURL, options: [.atomic])
    }

    func dayLabel(for day: Int) -> String {
        "Day \(day)"
    }
}
