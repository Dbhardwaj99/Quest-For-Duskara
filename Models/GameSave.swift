import Foundation

struct SavedGame: Codable, Equatable {
    var dayLabel: String
    var state: GameState
}

enum GameSaveLoadError: Error, Equatable {
    case unreadable
    case invalidData
    case invalidState
}

struct GameSaveStore {
    private let fileName = "duskara-save.json"
    private let directory: URL

    private var saveURL: URL {
        directory.appendingPathComponent(fileName)
    }

    init(directory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]) {
        self.directory = directory
    }

    func save(state: GameState) throws {
        let savedGame = SavedGame(dayLabel: dayLabel(for: state.day), state: state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(savedGame)
        try data.write(to: saveURL, options: [.atomic])
    }

    func load() throws -> GameState? {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }

        let data: Data
        do { data = try Data(contentsOf: saveURL) }
        catch { throw GameSaveLoadError.unreadable }

        let state: GameState
        do { state = try JSONDecoder().decode(SavedGame.self, from: data).state }
        catch { throw GameSaveLoadError.invalidData }

        guard state.towns.contains(where: { $0.id == state.activeTownID && $0.isPlayerControlled }) else {
            throw GameSaveLoadError.invalidState
        }
        return state
    }

    func dayLabel(for day: Int) -> String {
        "Day \(day)"
    }
}
