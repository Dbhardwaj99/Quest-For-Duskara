import Foundation

/// How the headless player fights a lane battle, since nobody clicks the
/// beach. The default, focus on lane 1 with knights first, is what the app's
/// own `-battleAutoplay` does (LaneBattleScene).
struct BattlePlan {
    enum Mode {
        case focus(lane: Int)
        case spread
        case weakest
        case order([(kind: SoldierKind, lane: Int)])
    }

    var mode = Mode.focus(lane: 1)
    var withdrawAfter: Double?

    var name: String {
        var text: String
        switch mode {
        case let .focus(lane): text = "focus:\(lane)"
        case .spread: text = "spread"
        case .weakest: text = "weakest"
        case let .order(steps): text = "order:" + steps.map { "\($0.kind.rawValue)@\($0.lane)" }.joined(separator: ",")
        }
        if let withdrawAfter { text += " withdraw:\(Int(withdrawAfter))" }
        return text
    }

    static func isPlanWord(_ word: String) -> Bool {
        ["auto", "focus", "spread", "weakest"].contains(word)
            || ["focus:", "order:", "withdraw:"].contains { word.hasPrefix($0) }
    }

    static func parse(_ words: [String]) throws -> BattlePlan {
        var plan = BattlePlan()
        for word in words {
            if word == "auto" || word == "focus" {
                plan.mode = .focus(lane: 1)
            } else if word == "spread" {
                plan.mode = .spread
            } else if word == "weakest" {
                plan.mode = .weakest
            } else if let value = word.value(after: "focus:") {
                plan.mode = .focus(lane: try lane(value))
            } else if let value = word.value(after: "withdraw:") {
                guard let seconds = Double(value), seconds >= 0 else {
                    throw PlaytestCommand.ParseError(message: "withdraw:<seconds>, e.g. withdraw:40.")
                }
                plan.withdrawAfter = seconds
            } else if let value = word.value(after: "order:") {
                let steps = try value.split(separator: ",").map { step -> (kind: SoldierKind, lane: Int) in
                    let parts = step.split(separator: "@")
                    guard parts.count == 2, let kind = SoldierKind(rawValue: String(parts[0])) else {
                        throw PlaytestCommand.ParseError(message: "order:knight@1,archer@0 lists units and their lanes.")
                    }
                    return (kind, try lane(String(parts[1])))
                }
                plan.mode = .order(steps)
            } else {
                throw PlaytestCommand.ParseError(message: "Unknown battle plan \"\(word)\".")
            }
        }
        return plan
    }

    private static func lane(_ text: String) throws -> Int {
        guard let lane = Int(text), (0..<LaneBattle.lanes).contains(lane) else {
            throw PlaytestCommand.ParseError(message: "Lanes are 0, 1 and 2.")
        }
        return lane
    }

    /// Plays the battle out at the scene's fixed step until it ends.
    func fight(_ battle: LaneBattle) -> LaneBattle {
        var battle = battle
        var queue: [(kind: SoldierKind, lane: Int)] = []
        if case let .order(steps) = mode { queue = steps }
        var nextLane = 0
        while battle.outcome == nil {
            if let withdrawAfter, battle.elapsed >= withdrawAfter {
                battle.withdraw()
                break
            }
            switch mode {
            case let .focus(lane):
                for kind in [SoldierKind.knight, .archer] where battle.canDeploy(kind) {
                    battle.deploy(kind, lane: lane)
                }
            case .spread:
                for kind in [SoldierKind.knight, .archer] where battle.canDeploy(kind) {
                    battle.deploy(kind, lane: nextLane)
                    nextLane = (nextLane + 1) % LaneBattle.lanes
                }
            case .weakest:
                for kind in [SoldierKind.knight, .archer] where battle.canDeploy(kind) {
                    let lane = (0..<LaneBattle.lanes).min { lhs, rhs in
                        Self.defenders(in: lhs, battle) < Self.defenders(in: rhs, battle)
                    } ?? 1
                    battle.deploy(kind, lane: lane)
                }
            case .order:
                while let step = queue.first {
                    if battle.attackerReserve[step.kind] == 0 { queue.removeFirst(); continue }
                    guard battle.canDeploy(step.kind) else { break }
                    battle.deploy(step.kind, lane: step.lane)
                    queue.removeFirst()
                }
            }
            battle.step(LaneBattle.tick)
            // The scene drains these to animate; nothing in the rules reads them.
            battle.events.removeAll(keepingCapacity: true)
        }
        return battle
    }

    private static func defenders(in lane: Int, _ battle: LaneBattle) -> Int {
        battle.units.filter { $0.side == .defender && $0.lane == lane }.count
    }
}

private extension String {
    func value(after prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
