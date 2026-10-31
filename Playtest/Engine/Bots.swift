import Foundation

/// Scripted players for bulk simulation. They aren't clever: they are a fixed
/// yardstick, so a balance change shows up as a change in how often the same
/// plan wins, and how long it takes. Every move goes through the same
/// commands an agent types, so bots exercise the real code paths.
enum Strategy: String, CaseIterable {
    case idle
    case turtle
    case balanced
    case rush
    case trader
    case random

    var summary: String {
        switch self {
        case .idle: "Never acts: how long until the enemy finishes you, and do they?"
        case .turtle: "Builds and upgrades its economy; never trains or fights."
        case .balanced: "Economy first, then a Barracks and knights; attacks only what a dry run says it can take."
        case .rush: "Barracks and archers first; attacks as soon as a dry run says it can win."
        case .trader: "Turtle's economy plus the Harbor Market: sells surplus food, buys skill."
        case .random: "Random commands, legal or not, every day: a fuzzer."
        }
    }

    var fights: Bool { self == .balanced || self == .rush }
}

struct BotPlayer {
    let strategy: Strategy
    private var rng: SplitMix

    init(strategy: Strategy, seed: Int) {
        self.strategy = strategy
        rng = SplitMix(seed: UInt64(bitPattern: Int64(seed)) ^ UInt64(Strategy.allCases.firstIndex(of: strategy) ?? 0) << 32)
    }

    mutating func playDay(_ session: PlaytestSession) {
        switch strategy {
        case .idle: return
        case .random: playRandomly(session)
        default: playPlan(session)
        }
    }

    // MARK: - Planned play

    /// Buildings each island works toward, in order. With the House and Pier
    /// every island starts with, each plan fills the 3 × 3 board.
    private var buildPlan: [(kind: BuildingKind, count: Int)] {
        switch strategy {
        case .rush: [(.farm, 1), (.barracks, 1), (.house, 2), (.farm, 2), (.factory, 1), (.house, 3), (.farm, 3)]
        case .balanced: [(.farm, 1), (.factory, 1), (.house, 2), (.farm, 2), (.barracks, 1), (.factory, 2), (.farm, 3)]
        default: [(.farm, 1), (.factory, 1), (.house, 2), (.farm, 2), (.factory, 2), (.farm, 3), (.house, 3)]
        }
    }

    private func playPlan(_ session: PlaytestSession) {
        for name in session.game.playerTowns.map(\.name) {
            guard session.isPlaying else { return }
            if session.game.activeTown.name != name { _ = session.apply("switch \(slug(name))") }
            develop(session)
            if strategy.fights { train(session) }
        }
        if strategy == .trader || strategy == .balanced { trade(session) }
        if strategy.fights { attack(session) }
    }

    private func develop(_ session: PlaytestSession) {
        for _ in 0..<4 {
            guard let command = nextBuild(session), session.apply(command).ok else { return }
        }
    }

    private func nextBuild(_ session: PlaytestSession) -> String? {
        let game = session.game
        let town = game.activeTown
        let full = town.buildings.count >= game.balance.gridSize.columns * game.balance.gridSize.rows
        if full == false, let wanted = buildPlan.first(where: { step in town.buildings.filter { $0.kind == step.kind }.count < step.count }) {
            if let command = buildCommand(wanted.kind, session) { return command }
            let workers = game.playerBalance.buildingDefinitions[wanted.kind]?.peopleRequired ?? 0
            if GameRules.freePeople(town, balance: game.balance) < workers { return housingCommand(session) }
            // Saving up for it.
            if game.shortfall(for: game.playerBalance.buildingDefinitions[wanted.kind]?.cost(for: 1) ?? [:]).isEmpty == false { return nil }
        }
        return upgradeCommand(session)
    }

    private func buildCommand(_ kind: BuildingKind, _ session: PlaytestSession) -> String? {
        let game = session.game
        guard let cost = game.playerBalance.buildingDefinitions[kind]?.cost(for: 1),
              game.shortfall(for: cost).isEmpty, keepsReserve(cost, session) else { return nil }
        let plots = GameRules.validCoordinates(for: kind, in: game.spendingTown, balance: game.playerBalance)
            .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
        return plots.first.map { "build \(kind.rawValue) \($0.x) \($0.y)" }
    }

    private func housingCommand(_ session: PlaytestSession) -> String? {
        if let command = buildCommand(.house, session) { return command }
        let game = session.game
        return game.activeTown.buildings.filter { $0.kind == .house && game.canUpgrade($0) && keepsReserve(game.upgradeCost($0), session) }
            .min { $0.level < $1.level }
            .map { "upgrade \($0.coordinate.x) \($0.coordinate.y)" }
    }

    private func upgradeCommand(_ session: PlaytestSession) -> String? {
        let game = session.game
        return game.activeTown.buildings
            .filter { game.canUpgrade($0) && keepsReserve(game.upgradeCost($0), session) }
            .min { (game.upgradeCost($0)[.gold] ?? 0) < (game.upgradeCost($1)[.gold] ?? 0) }
            .map { "upgrade \($0.coordinate.x) \($0.coordinate.y)" }
    }

    /// Fighters keep gold back for soldiers.
    private func keepsReserve(_ cost: [ResourceKind: Int], _ session: PlaytestSession) -> Bool {
        guard strategy.fights else { return true }
        let stock = GameRules.empireStock(session.game.state)
        return stock[.gold] - (cost[.gold] ?? 0) >= 600
    }

    private func train(_ session: PlaytestSession) {
        let game = session.game
        guard game.activeTown.buildings.contains(where: { $0.kind == .barracks }) else { return }
        for _ in 0..<5 {
            let kind: SoldierKind = strategy == .balanced && game.trainingUnavailableReason(for: .knight) == nil ? .knight : .archer
            guard game.trainingUnavailableReason(for: kind) == nil,
                  let upkeep = game.balance.soldierDefinitions[kind]?.dailyFoodUpkeep else { return }
            // Never more mouths than the farms feed; a rush accepts ten days of runway.
            let net = game.empireIncome[.food, default: 0] - upkeep
            let food = GameRules.empireStock(game.state)[.food]
            guard net >= 0 || (strategy == .rush && food + net * 10 > 0) else { return }
            guard session.apply("train \(kind.rawValue)").ok else { return }
        }
    }

    private func trade(_ session: PlaytestSession) {
        let game = session.game
        guard game.isMarketOpen else { return }
        if game.surplusFood >= 500 { _ = session.apply("sell-surplus") }
        if strategy == .trader {
            let stock = GameRules.empireStock(game.state)
            if stock[.skill] < 500, stock[.gold] > 2_500 { _ = session.apply("buy skill 100 3") }
        }
    }

    /// Stages on the island with the biggest army and takes the weakest
    /// target a dry run says it can capture.
    private func attack(_ session: PlaytestSession) {
        let game = session.game
        guard game.empireArmyStrength > 0,
              let staging = game.playerTowns.max(by: { $0.armyStrength < $1.armyStrength }) else { return }
        if game.activeTown.id != staging.id { _ = session.apply("switch \(slug(staging.name))") }
        let targets = game.state.towns.filter { $0.isPlayerControlled == false }
            .map { ($0, game.effectiveDefenseStrength(for: $0)) }
            .sorted { ($0.1, $0.0.name) < ($1.1, $1.0.name) }
            .prefix(3)
        for (target, defense) in targets {
            guard Double(game.empireArmyStrength) >= Double(defense) * 0.8 else { return }
            if game.activeArmyStrength < game.empireArmyStrength, Double(game.activeArmyStrength) < Double(defense) * 1.2 {
                _ = session.apply("pull-all")
            }
            let scout = session.apply("scout \(slug(target.name)) weakest")
            if scout.detail("outcome") == "captured" {
                _ = session.apply("attack \(slug(target.name)) weakest")
                return
            }
        }
    }

    // MARK: - Random play

    private mutating func playRandomly(_ session: PlaytestSession) {
        let towns = session.game.state.towns.map { slug($0.name) }
        let plans = ["focus:0", "focus:1", "focus:2", "spread", "weakest", "order:knight@1,archer@1", "weakest withdraw:20"]
        for _ in 0..<Int.random(in: 0...6, using: &rng) {
            guard session.isPlaying else { return }
            let x = Int.random(in: -1...3, using: &rng)
            let y = Int.random(in: -1...3, using: &rng)
            let town = towns.randomElement(using: &rng) ?? "duskara"
            let command: String = switch Int.random(in: 0..<100, using: &rng) {
            case 0..<30: "build \(BuildingKind.allCases.randomElement(using: &rng)!.rawValue) \(x) \(y)"
            case 30..<42: "upgrade \(x) \(y)"
            case 42..<46: "demolish \(x) \(y)"
            case 46..<62: "train \(SoldierKind.allCases.randomElement(using: &rng)!.rawValue) \(Int.random(in: 1...3, using: &rng))"
            case 62..<72: "\(Bool.random(using: &rng) ? "buy" : "sell") \(Bool.random(using: &rng) ? "food" : "skill") \(Bool.random(using: &rng) ? 100 : 1_000)"
            case 72..<76: "sell-surplus"
            case 76..<81: "switch \(town)"
            case 81..<87: "\(Bool.random(using: &rng) ? "send" : "pull") \(town) \(Bool.random(using: &rng) ? "half" : "all")"
            case 87..<89: "pull-all"
            case 89..<96: "\(Bool.random(using: &rng) ? "attack" : "rally-attack") \(town) \(plans.randomElement(using: &rng)!)"
            default: "scout \(town) \(plans.randomElement(using: &rng)!)"
            }
            _ = session.apply(command)
        }
    }
}

func slug(_ name: String) -> String {
    name.lowercased().replacingOccurrences(of: " ", with: "-")
}

extension Outcome {
    func detail(_ key: String) -> String? {
        guard let value = details.first(where: { $0.0 == key })?.1, case let .string(text) = value else { return nil }
        return text
    }
}

/// A seeded random number generator, so a bot plays the same seed the same way.
struct SplitMix: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
