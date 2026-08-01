import Foundation

struct SavedGame: Codable, Equatable {
    var dayLabel: String
    var state: GameState
    var difficulty: Difficulty

    init(dayLabel: String, state: GameState, difficulty: Difficulty) {
        self.dayLabel = dayLabel
        self.state = state
        self.difficulty = difficulty
    }

    private enum CodingKeys: String, CodingKey {
        case dayLabel, state, difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayLabel = try container.decode(String.self, forKey: .dayLabel)
        state = try container.decode(GameState.self, forKey: .state)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .medium
    }
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

    func save(state: GameState, difficulty: Difficulty) throws {
        let savedGame = SavedGame(dayLabel: dayLabel(for: state.day), state: state, difficulty: difficulty)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(savedGame)
        try data.write(to: saveURL, options: [.atomic])
    }

    func load() throws -> SavedGame? {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }

        let data: Data
        do { data = try Data(contentsOf: saveURL) }
        catch { throw GameSaveLoadError.unreadable }

        let savedGame: SavedGame
        do { savedGame = try JSONDecoder().decode(SavedGame.self, from: data) }
        catch { throw GameSaveLoadError.invalidData }

        let state = savedGame.state
        guard state.towns.contains(where: { $0.id == state.activeTownID && $0.isPlayerControlled }) else {
            throw GameSaveLoadError.invalidState
        }
        return savedGame
    }

    func dayLabel(for day: Int) -> String {
        "Day \(day)"
    }
}
