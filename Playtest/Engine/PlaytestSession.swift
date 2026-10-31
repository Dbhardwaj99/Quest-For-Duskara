import Foundation

/// One headless campaign: the app's own GameViewModel (the code behind every
/// button) with its clock stopped and its autosave off. Days pass only when a
/// command ends them, so a playtester can take as long as it likes over each.
final class PlaytestSession {
    let seed: Int
    let difficulty: Difficulty
    let game: GameViewModel
    /// Every action applied, in order: replaying them on a new session with the
    /// same seed and difficulty plays the campaign out again.
    private(set) var log: [String] = []
    var stats = CampaignStats()
    private var reportedNews: Set<UUID>
    /// Persistent problems are reported the first time they appear.
    private var reportedIssues: Set<String> = []
    /// What the rule checks found in the world as it was generated.
    private(set) var issuesAtStart: (violations: [String], anomalies: [String]) = ([], [])

    init(seed: Int, difficulty: Difficulty) {
        self.seed = seed
        self.difficulty = difficulty
        game = GameViewModel(saveStore: GameSaveStore(directory: nil))
        game.state = Self.headless(makeNewGame(balance: game.balance, seed: seed), seed: seed)
        // What the setup screen's difficulty button does.
        game.adjustBonusPresets(for: difficulty)
        game.startGame()
        game.stopClock()
        reportedNews = Set(game.state.newsEvents.map(\.id))
        let found = ruleChecks()
        issuesAtStart = (fresh(found.violations, key: Self.violationKey), fresh(found.anomalies, key: Self.anomalyKey))
        stats.observe(self)
    }

    init(file: SessionFile) {
        seed = file.seed
        difficulty = file.difficulty
        log = file.log
        game = GameViewModel(resuming: file.state, difficulty: file.difficulty, saveStore: GameSaveStore(directory: nil))
        game.stopClock()
        switch file.phase {
        case "victory": game.phase = .victory
        case "defeat": game.phase = .defeat
        default: break
        }
        reportedNews = Set(file.state.newsEvents.map(\.id))
        reportedIssues = Set(file.reported ?? [])
        stats.observe(self)
    }

    var file: SessionFile {
        SessionFile(seed: seed, difficulty: difficulty, phase: phaseName, log: log, reported: reportedIssues.sorted(), state: game.state)
    }

    var phaseName: String {
        switch game.phase {
        case .setup: "setup"
        case .town: "playing"
        case .victory: "victory"
        case .defeat: "defeat"
        }
    }

    var isPlaying: Bool { game.phase == .town }

    var daysUntilEnemyTurn: Int {
        let interval = game.balance.enemyTurnInterval
        return interval - game.state.day % interval
    }

    /// Runs one command and reports it as the app would have shown it, plus
    /// whatever broke a rule along the way.
    func perform(_ line: String) -> JSON {
        let text = line.trimmingCharacters(in: .whitespaces)
        return apply(text).json(command: text)
    }

    func apply(_ text: String) -> Outcome {
        var outcome: Outcome
        do {
            let command = try PlaytestCommand.parse(text)
            if case .state = command {
                outcome = Outcome(ok: true, message: "")
            } else if isPlaying == false {
                outcome = .blocked("The campaign is over: \(phaseName).")
            } else {
                if command.isAction { log.append(text) }
                outcome = execute(command)
                stats.count(command, outcome, day: game.state.day)
            }
        } catch let error as PlaytestCommand.ParseError {
            outcome = Outcome(ok: false, message: error.message)
        } catch {
            outcome = Outcome(ok: false, message: "\(error)")
        }
        // The player's own news ("You built…") repeats the outcome.
        _ = takeNews()
        let found = ruleChecks()
        outcome.violations += found.violations
        outcome.anomalies += found.anomalies
        outcome.violations = fresh(outcome.violations, key: Self.violationKey)
        outcome.anomalies = fresh(outcome.anomalies, key: Self.anomalyKey)
        stats.record(violations: outcome.violations, anomalies: outcome.anomalies, session: self)
        stats.observe(self)
        return outcome
    }

    /// News the playtester hasn't seen yet, oldest first.
    func takeNews() -> [NewsEvent] {
        let unseen = game.state.newsEvents.filter { reportedNews.contains($0.id) == false }
        reportedNews.formUnion(unseen.map(\.id))
        return unseen.reversed()
    }

    private func fresh(_ issues: [String], key: (String) -> String) -> [String] {
        issues.filter { reportedIssues.insert(key($0)).inserted }
    }

    private static func violationKey(_ issue: String) -> String { issue }

    /// An anomaly that lasts is the same finding however its numbers drift.
    private static func anomalyKey(_ issue: String) -> String {
        "anomaly: " + String(issue.filter { $0.isNumber == false })
    }

    func town(named name: String) -> Town? {
        let key = Self.key(name)
        guard key.isEmpty == false else { return nil }
        let towns = game.state.towns
        if let exact = towns.first(where: { Self.key($0.name) == key }) { return exact }
        let matches = towns.filter { Self.key($0.name).hasPrefix(key) }
        return matches.count == 1 ? matches[0] : nil
    }

    static func key(_ text: String) -> String {
        String(text.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The world generator can store a sea lane both ways round, so neighbours
    /// are deduplicated.
    func neighbors(of town: Town) -> [Town] {
        let ids = Set(game.state.connections.compactMap { lane -> UUID? in
            guard lane.contains(town.id) else { return nil }
            return lane.from == town.id ? lane.to : lane.from
        })
        return game.state.towns.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    // MARK: - A headless world

    /// Drops what only the map draws, and gives towns UUIDs derived from the
    /// seed: the enemy breaks ties between equal targets by UUID, so random
    /// ones would let the same seed play out two ways.
    static func headless(_ state: GameState, seed: Int) -> GameState {
        var state = state
        state.world.terrainTiles = []
        state.world.landmarks = []
        for index in state.territory.regions.indices { state.territory.regions[index].cells = [] }

        var ids: [UUID: UUID] = [:]
        func stable(_ id: UUID) -> UUID {
            if let known = ids[id] { return known }
            let made = stableUUID(seed: seed, index: ids.count)
            ids[id] = made
            return made
        }
        for index in state.towns.indices { state.towns[index].id = stable(state.towns[index].id) }
        for index in state.towns.indices { state.towns[index].realmID = stable(state.towns[index].realmID) }
        state.worldNodes = state.worldNodes.map { WorldTownNode(townID: stable($0.townID), x: $0.x, y: $0.y) }
        state.connections = state.connections
            .map { TownConnection(from: stable($0.from), to: stable($0.to)) }
            .sorted { ($0.from.uuidString, $0.to.uuidString) < ($1.from.uuidString, $1.to.uuidString) }
        for index in state.territory.regions.indices {
            state.territory.regions[index].townID = stable(state.territory.regions[index].townID)
        }
        state.activeTownID = stable(state.activeTownID)
        return state
    }

    private static func stableUUID(seed: Int, index: Int) -> UUID {
        // splitmix64
        var word = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(index)
        func next() -> UInt64 {
            word &+= 0x9E37_79B9_7F4A_7C15
            var z = word
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        let high = next()
        let low = next()
        func byte(_ value: UInt64, _ index: Int) -> UInt8 { UInt8(truncatingIfNeeded: value >> (index * 8)) }
        return UUID(uuid: (
            byte(high, 0), byte(high, 1), byte(high, 2), byte(high, 3),
            byte(high, 4), byte(high, 5), byte(high, 6), byte(high, 7),
            byte(low, 0), byte(low, 1), byte(low, 2), byte(low, 3),
            byte(low, 4), byte(low, 5), byte(low, 6), byte(low, 7)
        ))
    }
}

/// A campaign on disk, between two runs of the command-line tool.
struct SessionFile: Codable {
    static let currentFormat = 1

    var format = currentFormat
    var seed: Int
    var difficulty: Difficulty
    var phase: String
    var log: [String]
    /// Rule-check findings already reported, so each shows up once.
    var reported: [String]?
    var state: GameState
}

/// What one command did.
struct Outcome {
    var ok: Bool
    var message: String
    /// True when the app wouldn't have offered the action at all (a greyed-out
    /// button, a hidden panel), rather than the game refusing it.
    var blocked = false
    var details: [(String, JSON)] = []
    var violations: [String] = []
    var anomalies: [String] = []

    static func blocked(_ message: String) -> Outcome {
        Outcome(ok: false, message: message, blocked: true)
    }

    func json(command: String) -> JSON {
        var fields: [(String, JSON)] = [("command", .string(command)), ("ok", .bool(ok))]
        if blocked { fields.append(("blocked", .bool(true))) }
        if message.isEmpty == false { fields.append(("message", .string(message))) }
        fields += details
        if violations.isEmpty == false { fields.append(("violations", .strings(violations))) }
        if anomalies.isEmpty == false { fields.append(("anomalies", .strings(anomalies))) }
        return .object(fields)
    }
}
