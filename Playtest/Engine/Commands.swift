import Foundation

/// What a playtester can do: the actions the app's buttons offer, typed out.
/// Coordinates are a town plot (x, y), each 0–2 on the 3 × 3 board.
enum PlaytestCommand {
    case state
    case build(BuildingKind, GridCoordinate)
    case upgrade(GridCoordinate)
    case demolish(GridCoordinate)
    case train(SoldierKind, count: Int)
    case switchTo(town: String)
    case trade(ResourceKind, lot: Int, buying: Bool, times: Int)
    case sellSurplusFood
    case send(town: String, all: Bool)
    case pull(town: String, all: Bool)
    case pullAll
    case attack(town: String, plan: BattlePlan, rally: Bool)
    case scout(town: String, plan: BattlePlan)
    case endDay(count: Int)

    struct ParseError: Error {
        let message: String
    }

    static let reference = """
        state                              Show the campaign (changes nothing).
        build <kind> <x> <y>               Build house|farm|factory|barracks|pier on a plot of the active island.
        upgrade <x> <y>                    Upgrade the building on that plot.
        demolish <x> <y>                   Demolish it (half its current gold price comes back).
        train <archer|knight> [count]      Train soldiers at the active island's Barracks.
        switch <town>                      Make another of your islands the active one.
        buy <food|skill> <100|1000> [times]    Harbor Market: buy a lot with gold.
        sell <food|skill> <100|1000> [times]   Harbor Market: sell a lot for gold.
        sell-surplus                       Sell all food above ten days of rations (the market's button).
        send <town> <half|all>             Move troops from the active island to another of yours.
        pull <town> <half|all>             Move troops from another of your islands to the active one.
        pull-all                           Gather every island's troops on the active island.
        attack <town> [plan]               Land the active island's whole army and fight the lane battle.
        rally-attack <town> [plan]         Pull every island's troops here, then attack.
        scout <town> [plan]                Dry run of that battle: shows the result, changes nothing.
        end-day [days]                     End the day (default 1). Enemies act on every 10th day.

        Battle plans (the player deploys units on three lanes, 0, 1 and 2):
        focus[:lane]     Land every unit on one lane, knights first (default: focus:1, the app's autoplay).
        spread           Rotate lanes 0, 1, 2.
        weakest          Each unit lands on the lane with the fewest defenders.
        order:<kind>@<lane>,...   Land exactly these, in order, as the command meter allows; the rest stay home.
        withdraw:<seconds>        Sound the retreat at that time if the gate still stands.
        Town names ignore case, spaces and punctuation: green-hollow, GreenHollow and "green hollow" all work.
        """

    static func parse(_ line: String) throws -> PlaytestCommand {
        let words = line.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard let verb = words.first else { throw ParseError(message: "Empty command.") }
        let rest = Array(words.dropFirst())
        switch verb {
        case "state", "status", "look":
            return .state
        case "build":
            guard let word = rest.first, let kind = BuildingKind(rawValue: singular(word)) else {
                throw ParseError(message: "Build what? house, farm, factory, barracks or pier, then a plot: build farm 0 0.")
            }
            return .build(kind, try plot(Array(rest.dropFirst())))
        case "upgrade":
            return .upgrade(try plot(rest))
        case "demolish":
            return .demolish(try plot(rest))
        case "train":
            guard let word = rest.first, let kind = SoldierKind(rawValue: singular(word)) else {
                throw ParseError(message: "Train what? archer or knight: train archer 3.")
            }
            return .train(kind, count: try count(rest.dropFirst().first, upTo: 100))
        case "switch", "goto":
            return .switchTo(town: try name(rest))
        case "buy", "sell":
            guard rest.count >= 2, let kind = ResourceKind(rawValue: rest[0]), kind == .food || kind == .skill else {
                throw ParseError(message: "The market trades food and skill: \(verb) food 100.")
            }
            guard let lot = Int(rest[1].replacingOccurrences(of: ",", with: "")), lot == 100 || lot == 1_000 else {
                throw ParseError(message: "The market sells lots of 100 or 1000.")
            }
            return .trade(kind, lot: lot, buying: verb == "buy", times: try count(rest.dropFirst(2).first, upTo: 100))
        case "sell-surplus", "sellsurplus", "sell-surplus-food":
            return .sellSurplusFood
        case "send", "pull":
            guard rest.count >= 2, let amount = rest.last, amount == "half" || amount == "all" else {
                throw ParseError(message: "\(verb) <town> <half|all>, as the Troops panel offers.")
            }
            let town = try name(Array(rest.dropLast()))
            return verb == "send" ? .send(town: town, all: amount == "all") : .pull(town: town, all: amount == "all")
        case "pull-all", "pullall":
            return .pullAll
        case "attack", "rally-attack", "scout":
            let planStart = rest.firstIndex(where: BattlePlan.isPlanWord) ?? rest.endIndex
            let town = try name(Array(rest[..<planStart]))
            let plan = try BattlePlan.parse(Array(rest[planStart...]))
            return verb == "scout" ? .scout(town: town, plan: plan) : .attack(town: town, plan: plan, rally: verb == "rally-attack")
        case "end-day", "endday", "next", "wait":
            return .endDay(count: try count(rest.first, upTo: 1_000))
        default:
            throw ParseError(message: "Unknown command \"\(verb)\". `duskara-playtest help` lists them.")
        }
    }

    /// Whether replaying the command could change the campaign.
    var isAction: Bool {
        switch self {
        case .state, .scout: false
        default: true
        }
    }

    private static func singular(_ word: String) -> String {
        word.hasSuffix("s") && word != "barracks" ? String(word.dropLast()) : word
    }

    private static func plot(_ words: [String]) throws -> GridCoordinate {
        let numbers = words.joined(separator: " ")
            .split(whereSeparator: { $0.isNumber == false && $0 != "-" })
            .compactMap { Int($0) }
        guard numbers.count == 2 else { throw ParseError(message: "Give a plot as two numbers, x then y: 0 2.") }
        return GridCoordinate(x: numbers[0], y: numbers[1])
    }

    private static func count(_ word: String?, upTo limit: Int) throws -> Int {
        guard let word else { return 1 }
        guard let value = Int(word), (1...limit).contains(value) else {
            throw ParseError(message: "\"\(word)\" isn't a count from 1 to \(limit).")
        }
        return value
    }

    private static func name(_ words: [String]) throws -> String {
        guard words.isEmpty == false else { throw ParseError(message: "Which town?") }
        return words.joined(separator: " ")
    }
}
