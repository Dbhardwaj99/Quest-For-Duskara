import Foundation

struct SavedGame: Codable, Equatable {
    var dayLabel: String
    var state: GameState
}

// Write-only for now: the game autosaves continuously, but every launch
// starts a new game, so nothing reads the file back yet.
struct GameSaveStore {
    private let fileName = "duskara-save.json"

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func save(state: GameState) throws {
        let savedGame = SavedGame(dayLabel: dayLabel(for: state.day), state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(savedGame)
        try data.write(to: saveURL, options: [.atomic])
    }

    func dayLabel(for day: Int) -> String {
        "Day \(day)"
    }
}
