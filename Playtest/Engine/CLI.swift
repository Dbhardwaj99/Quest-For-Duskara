import Foundation

/// `duskara-playtest`: play Quest for Duskara from a terminal, one command at
/// a time or thousands of campaigns at once. Everything it prints is JSON.
public enum PlaytestCLI {
    static let usage = """
        duskara-playtest: the Quest for Duskara rules and view model, headless.

        USAGE
          duskara-playtest new [--seed N] [--difficulty easy|medium|hard] [--session FILE] [--view brief|full]
              Start a campaign and save it to FILE (default duskara-session.json).
          duskara-playtest act [--session FILE] [--view brief|full] COMMAND [COMMAND...]
              Apply commands to the saved campaign, save it, print what happened and the new state.
              Each argument is one command; a single argument may also hold several separated by ';'.
          duskara-playtest state [--session FILE] [--view brief|full]
              Print the saved campaign.
          duskara-playtest play [--seed N] [--difficulty D] [--session FILE] [--view brief|full]
              Read commands from standard input, one line at a time, and answer each line with one line
              of JSON. With --session, resumes that file if it exists and saves after every line.
          duskara-playtest simulate [--games N] [--strategy LIST|all] [--difficulty LIST|all]
                                    [--max-days N] [--seed N] [--save FILE]
              Play N bot campaigns per strategy and difficulty (seeds N, N+1, ...) and summarise them.
              With --games 1 and one strategy and difficulty, --save keeps that campaign as a session file.
          duskara-playtest rules
              The balance tables, with derived numbers (payback days, gold per power, price scales).
          duskara-playtest help

        COMMANDS (for act and play)
        \(PlaytestCommand.reference.split(separator: "\n", omittingEmptySubsequences: false).map { "  " + $0 }.joined(separator: "\n"))

        STRATEGIES (for simulate)
        \(Strategy.allCases.map { "  \($0.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0)) \($0.summary)" }.joined(separator: "\n"))

        Output is JSON on standard output; progress goes to standard error. Add --compact for one-line JSON.
        """

    public static func run(_ arguments: [String]) async -> Int32 {
        var words = Array(arguments.dropFirst())
        guard let verb = words.first else {
            print(usage)
            return 0
        }
        words.removeFirst()
        do {
            var options = try Options(words)
            switch verb {
            case "new":
                let session = PlaytestSession(seed: options.seed ?? Int.random(in: 0..<1_000_000), difficulty: options.difficulty ?? .medium)
                try save(session, to: options.session)
                emit(.object([("session", .string(options.session))] + startIssues(session) + [("state", session.snapshot(options.view))]), options)
            case "act":
                guard options.rest.isEmpty == false else { throw Failure("act needs at least one command. Try: act \"end-day\"") }
                let session = try load(options.session)
                let commands = options.rest.flatMap { $0.split(separator: ";").map(String.init) }
                    .map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
                let results = commands.map(session.perform)
                try save(session, to: options.session)
                emit(.object([("results", .array(results)), ("state", session.snapshot(options.view))]), options)
            case "state":
                emit(try load(options.session).snapshot(options.view), options)
            case "play":
                options.compact = true
                try await play(options)
            case "simulate":
                try await simulate(options)
            case "rules":
                emit(RulesReport.json(), options)
            case "help", "--help", "-h":
                print(usage)
            default:
                throw Failure("Unknown verb \"\(verb)\".\n\n\(usage)")
            }
            return 0
        } catch let failure as Failure {
            printError(failure.message)
            return 1
        } catch {
            printError("\(error)")
            return 1
        }
    }

    // MARK: - Verbs

    private static func play(_ options: Options) async throws {
        let session: PlaytestSession
        if options.seed == nil, options.difficulty == nil, FileManager.default.fileExists(atPath: options.session), options.sessionGiven {
            session = try load(options.session)
        } else {
            session = PlaytestSession(seed: options.seed ?? Int.random(in: 0..<1_000_000), difficulty: options.difficulty ?? .medium)
        }
        emit(.object(startIssues(session) + [("state", session.snapshot(options.view))]), options)
        while let line = readLine() {
            let commands = line.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false }
            if commands == ["quit"] || commands == ["exit"] { break }
            let results = commands.map(session.perform)
            if options.sessionGiven { try save(session, to: options.session) }
            emit(.object([("results", .array(results)), ("state", session.snapshot(options.view))]), options)
            await Task.yield()
        }
    }

    private static func simulate(_ options: Options) async throws {
        var settings = Simulation.Options()
        if let games = options.games { settings.games = games }
        if let strategies = options.strategies { settings.strategies = strategies }
        if let difficulty = options.difficulties { settings.difficulties = difficulty }
        if let maxDays = options.maxDays { settings.maxDays = maxDays }
        if let seed = options.seed { settings.firstSeed = seed }
        if let file = options.save {
            guard settings.games == 1, settings.strategies.count == 1, settings.difficulties.count == 1 else {
                throw Failure("--save keeps one campaign: use it with --games 1, one --strategy and one --difficulty.")
            }
            let (result, session) = await Simulation.play(seed: settings.firstSeed, difficulty: settings.difficulties[0],
                                                         strategy: settings.strategies[0], maxDays: settings.maxDays)
            try save(session, to: file)
            emit(.object([("session", .string(file)), ("report", Simulation.report([result], settings)),
                          ("state", session.snapshot(options.view))]), options)
            return
        }
        let report = await Simulation.run(settings) { printError($0) }
        emit(report, options)
    }

    /// What the rule checks found in the world as generated.
    private static func startIssues(_ session: PlaytestSession) -> [(String, JSON)] {
        let (violations, anomalies) = session.issuesAtStart
        return (violations.isEmpty ? [] : [("violationsAtStart", .strings(violations))])
            + (anomalies.isEmpty ? [] : [("anomaliesAtStart", .strings(anomalies))])
    }

    // MARK: - Files

    private static func load(_ path: String) throws -> PlaytestSession {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw Failure("No session at \(path). Start one with: duskara-playtest new --session \(path)")
        }
        let file: SessionFile
        do { file = try JSONDecoder().decode(SessionFile.self, from: data) } catch {
            throw Failure("\(path) isn't a playtest session: \(error)")
        }
        guard file.format <= SessionFile.currentFormat else { throw Failure("\(path) was written by a newer duskara-playtest.") }
        return PlaytestSession(file: file)
    }

    private static func save(_ session: PlaytestSession, to path: String) throws {
        let data = try JSONEncoder().encode(session.file)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    // MARK: - Output

    private static func emit(_ json: JSON, _ options: Options) {
        print(json.rendered(pretty: options.compact == false))
        fflush(stdout)
    }

    private static func printError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }

    struct Failure: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    struct Options {
        var session = "duskara-session.json"
        var sessionGiven = false
        var seed: Int?
        var difficulty: Difficulty?
        var difficulties: [Difficulty]?
        var view = PlaytestSession.View.brief
        var compact = false
        var games: Int?
        var strategies: [Strategy]?
        var maxDays: Int?
        var save: String?
        var rest: [String] = []

        init(_ words: [String]) throws {
            var index = 0
            func value(_ flag: String) throws -> String {
                index += 1
                guard index < words.count else { throw Failure("\(flag) needs a value.") }
                return words[index]
            }
            func number(_ flag: String, _ range: ClosedRange<Int>) throws -> Int {
                let text = try value(flag)
                guard let number = Int(text), range.contains(number) else { throw Failure("\(flag) takes a number from \(range.lowerBound) to \(range.upperBound).") }
                return number
            }
            while index < words.count {
                let word = words[index]
                switch word {
                case "--session":
                    session = try value(word)
                    sessionGiven = true
                case "--seed":
                    seed = try number(word, Int(Int32.min)...Int(Int32.max))
                case "--difficulty":
                    let text = try value(word)
                    let list = text == "all" ? Difficulty.allCases : try text.split(separator: ",").map { name in
                        guard let difficulty = Difficulty(rawValue: String(name)) else { throw Failure("Difficulties are easy, medium and hard.") }
                        return difficulty
                    }
                    difficulties = list
                    difficulty = list.first
                case "--strategy", "--strategies":
                    let text = try value(word)
                    strategies = text == "all" ? Strategy.allCases : try text.split(separator: ",").map { name in
                        guard let strategy = Strategy(rawValue: String(name)) else {
                            throw Failure("Strategies are \(Strategy.allCases.map(\.rawValue).joined(separator: ", ")).")
                        }
                        return strategy
                    }
                case "--view":
                    guard let view = PlaytestSession.View(rawValue: try value(word)) else { throw Failure("--view is brief or full.") }
                    self.view = view
                case "--compact":
                    compact = true
                case "--games":
                    games = try number(word, 1...100_000)
                case "--max-days":
                    maxDays = try number(word, 1...100_000)
                case "--save":
                    save = try value(word)
                default:
                    rest.append(word)
                }
                index += 1
            }
        }
    }
}
