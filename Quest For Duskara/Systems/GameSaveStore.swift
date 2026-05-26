import Foundation

struct SavedGame: Codable, Equatable {
    var dayLabel: String
    var state: GameState
}

struct SavedGameSummary: Equatable {
    var dayLabel: String
}

struct GameSaveStore {
    private let fileName = "duskara-save.json"

    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    func savedGameSummary() -> SavedGameSummary? {
        guard let savedGame = try? loadSavedGame() else { return nil }
        return SavedGameSummary(dayLabel: savedGame.dayLabel)
    }

    func loadSavedGame() throws -> SavedGame {
        let data = try Data(contentsOf: saveURL)
        return try JSONDecoder().decode(SavedGame.self, from: data)
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
