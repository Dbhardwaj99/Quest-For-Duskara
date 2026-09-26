import Foundation

struct SavedGame: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var dayLabel: String
    var state: GameState
    var difficulty: Difficulty

    init(dayLabel: String, state: GameState, difficulty: Difficulty) {
        schemaVersion = Self.currentSchemaVersion
        self.dayLabel = dayLabel
        self.state = state
        self.difficulty = difficulty
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, dayLabel, state, difficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        guard schemaVersion > 0 else { throw GameSaveLoadError.invalidData }
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw GameSaveLoadError.unsupportedVersion
        }
        dayLabel = try container.decode(String.self, forKey: .dayLabel)
        state = try container.decode(GameState.self, forKey: .state)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .medium
        if schemaVersion < 2 {
            // Version 1 ran a tenth of this economy on 60-second days: scale the
            // stores to match, and restart the day so it can't replay several.
            for index in state.towns.indices {
                for kind in GameRules.sharedKinds { state.towns[index].resources[kind] *= 10 }
            }
            state.elapsedSecondsInDay = 0
        }
    }
}

enum GameSaveLoadError: Error, Equatable {
    case unreadable
    case invalidData
    case invalidState
    case unsupportedVersion

    var recoveryMessage: String {
        switch self {
        case .unsupportedVersion:
            "This save was created by an unsupported game version. Start a new campaign to replace it."
        case .unreadable, .invalidData, .invalidState:
            "This save could not be loaded. Start a new campaign to replace it."
        }
    }
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
        // Compact: this runs on the main thread every ten-second day.
        let data = try JSONEncoder().encode(savedGame)
        try data.write(to: saveURL, options: [.atomic])
    }

    func load() throws -> SavedGame? {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return nil }

        let data: Data
        do { data = try Data(contentsOf: saveURL) }
        catch { throw GameSaveLoadError.unreadable }

        let savedGame: SavedGame
        do { savedGame = try JSONDecoder().decode(SavedGame.self, from: data) }
        catch let error as GameSaveLoadError { throw error }
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
