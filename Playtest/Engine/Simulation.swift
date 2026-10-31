import Foundation

/// Many bot campaigns at once, summarised: how often each plan wins on each
/// difficulty, how the economy grows, and every rule check that tripped, with
/// the seed to reproduce it.
enum Simulation {
    struct Options {
        var games = 20
        var strategies: [Strategy] = [.balanced, .rush, .turtle, .trader, .idle, .random]
        var difficulties = Difficulty.allCases
        var maxDays = 365
        var firstSeed = 1
    }

    struct Checkpoint {
        var stock: ResourceWallet
        var net: [ResourceKind: Int]
        var army: Int
        var islands: Int

        init(_ session: PlaytestSession) {
            stock = GameRules.empireStock(session.game.state)
            net = session.game.empireIncome
            army = session.game.empireArmyStrength
            islands = session.game.playerTowns.count
        }
    }

    struct GameResult {
        var strategy: Strategy
        var difficulty: Difficulty
        var seed: Int
        var outcome: String
        var day: Int
        var islandsAtEnd: Int
        var stats: CampaignStats
        var checkpoints: [Int: Checkpoint]
    }

    static let checkpointDays = [10, 25, 50, 100, 200, 300]

    static func play(seed: Int, difficulty: Difficulty, strategy: Strategy, maxDays: Int) async -> (GameResult, PlaytestSession) {
        let session = PlaytestSession(seed: seed, difficulty: difficulty)
        var bot = BotPlayer(strategy: strategy, seed: seed)
        var checkpoints: [Int: Checkpoint] = [:]
        while session.isPlaying, session.game.state.day < maxDays {
            bot.playDay(session)
            guard session.isPlaying else { break }
            _ = session.apply("end-day")
            let day = session.game.state.day
            if checkpointDays.contains(day) { checkpoints[day] = Checkpoint(session) }
            // Lets the app's message timers run out instead of piling up.
            if day.isMultiple(of: 5) { await Task.yield() }
        }
        session.stats.finish(on: session.game.state.day)
        let outcome = switch session.game.phase {
        case .victory: "victory"
        case .defeat: "defeat"
        default: "timeout"
        }
        let result = GameResult(strategy: strategy, difficulty: difficulty, seed: seed, outcome: outcome,
                                day: session.game.state.day, islandsAtEnd: session.game.playerTowns.count,
                                stats: session.stats, checkpoints: checkpoints)
        return (result, session)
    }

    static func run(_ options: Options, progress: (String) -> Void) async -> JSON {
        var results: [GameResult] = []
        for strategy in options.strategies {
            for difficulty in options.difficulties {
                for index in 0..<options.games {
                    let (result, _) = await play(seed: options.firstSeed + index, difficulty: difficulty,
                                                 strategy: strategy, maxDays: options.maxDays)
                    results.append(result)
                }
                let group = results.suffix(options.games)
                progress("\(strategy.rawValue)/\(difficulty.rawValue): \(group.filter { $0.outcome == "victory" }.count) of \(options.games) won")
            }
        }
        return report(results, options)
    }

    static func report(_ results: [GameResult], _ options: Options) -> JSON {
        var groups: [JSON] = []
        for strategy in options.strategies {
            for difficulty in options.difficulties {
                let games = results.filter { $0.strategy == strategy && $0.difficulty == difficulty }
                guard games.isEmpty == false else { continue }
                groups.append(groupJSON(strategy, difficulty, games))
            }
        }
        return .object([
            ("settings", .object([
                ("gamesPerGroup", .int(options.games)),
                ("seeds", .string("\(options.firstSeed)–\(options.firstSeed + options.games - 1), the same for every group")),
                ("maxDays", .int(options.maxDays)),
                ("strategies", .object(options.strategies.map { ($0.rawValue, .string($0.summary)) })),
            ])),
            ("groups", .array(groups)),
            ("issues", issuesJSON(results, options)),
        ])
    }

    private static func groupJSON(_ strategy: Strategy, _ difficulty: Difficulty, _ games: [GameResult]) -> JSON {
        let wins = games.filter { $0.outcome == "victory" }
        let losses = games.filter { $0.outcome == "defeat" }
        let count = Double(games.count)
        func average(_ value: (GameResult) -> Int) -> JSON { .double(Double(games.map(value).reduce(0, +)) / count) }
        var fields: [(String, JSON)] = [
            ("strategy", .string(strategy.rawValue)),
            ("difficulty", .string(difficulty.rawValue)),
            ("games", .int(games.count)),
            ("victories", .int(wins.count)),
            ("defeats", .int(losses.count)),
            ("timeouts", .int(games.count - wins.count - losses.count)),
            ("victoryDay", spread(wins.map(\.day))),
            ("defeatDay", spread(losses.map(\.day))),
            ("islandsPeak", spread(games.map(\.stats.peakIslands))),
            ("islandsAtEnd", spread(games.map(\.islandsAtEnd))),
            ("peakArmy", spread(games.map(\.stats.peakArmy))),
            ("battlesPerGame", average(\.stats.battles)),
            ("capturesPerGame", average(\.stats.captures)),
            ("firstCaptureDay", spread(games.compactMap(\.stats.firstCaptureDay))),
            ("powerLostInBattlePerGame", average(\.stats.powerLostInBattle)),
            ("powerLostToHungerPerGame", average(\.stats.hungerLosses)),
            ("islandsLostToEnemiesPerGame", average(\.stats.islandsLost)),
            ("marketTradesPerGame", average(\.stats.trades)),
            ("marketGoldPerGame", average(\.stats.marketGold)),
            ("longestStallDays", spread(games.map(\.stats.longestStall))),
            ("refusedActionShare", .double(Double(games.map(\.stats.refused).reduce(0, +)) / Double(max(1, games.map(\.stats.actions).reduce(0, +))))),
        ]
        fields.append(("byDay", .object(checkpointDays.compactMap { day -> (String, JSON)? in
            let points = games.compactMap { $0.checkpoints[day] }
            guard points.isEmpty == false else { return nil }
            return ("day\(day)", .object([
                ("gamesStillRunning", .int(points.count)),
                ("medianStock", .wallet(Dictionary(uniqueKeysWithValues: GameRules.sharedKinds.map { kind in (kind, median(points.map { $0.stock[kind] })) }))),
                ("medianNetPerDay", .wallet(Dictionary(uniqueKeysWithValues: GameRules.sharedKinds.map { kind in (kind, median(points.map { $0.net[kind, default: 0] })) }))),
                ("medianArmy", .int(median(points.map(\.army)))),
                ("medianIslands", .int(median(points.map(\.islands)))),
            ]))
        })))
        return .object(fields)
    }

    /// Every rule check that tripped, grouped by what it says (islands and
    /// numbers aside), violations first.
    private static func issuesJSON(_ results: [GameResult], _ options: Options) -> JSON {
        var order: [String] = []
        var groups: [String: (count: Int, games: Int, example: (GameResult, CampaignStats.Issue))] = [:]
        for result in results {
            for issue in result.stats.issues {
                if var group = groups[issue.key] {
                    group.count += issue.occurrences
                    group.games += 1
                    groups[issue.key] = group
                } else {
                    order.append(issue.key)
                    groups[issue.key] = (issue.occurrences, 1, (result, issue))
                }
            }
        }
        let sorted = order.sorted { lhs, rhs in
            let left = groups[lhs]!, right = groups[rhs]!
            if left.example.1.severity != right.example.1.severity { return left.example.1.severity == "violation" }
            return left.games > right.games
        }
        return .array(sorted.compactMap { key in
            guard let group = groups[key] else { return nil }
            let (result, issue) = group.example
            return .object([
                ("severity", .string(issue.severity)),
                ("finding", .string(String(key.drop { $0 != ":" }.dropFirst(2)))),
                ("occurrences", .int(group.count)),
                ("gamesAffected", .int(group.games)),
                ("example", .object([
                    ("message", .string(issue.message)),
                    ("strategy", .string(result.strategy.rawValue)),
                    ("difficulty", .string(result.difficulty.rawValue)),
                    ("seed", .int(result.seed)),
                    ("day", .int(issue.day)),
                    ("recentCommands", .strings(issue.recentCommands)),
                    ("reproduce", .string("duskara-playtest simulate --strategy \(result.strategy.rawValue) --difficulty \(result.difficulty.rawValue) --seed \(result.seed) --games 1 --max-days \(issue.day + 1) --save repro.json")),
                ])),
            ])
        })
    }

    private static func spread(_ values: [Int]) -> JSON {
        guard values.isEmpty == false else { return .null }
        return .object([("min", .int(values.min()!)), ("median", .int(median(values))), ("max", .int(values.max()!))])
    }

    private static func median(_ values: [Int]) -> Int {
        guard values.isEmpty == false else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
