import Foundation

struct BattleHUDState: Equatable {
    let command: Int
    let seconds: Int
    let reserve: SoldierRoster
    let affordable: Set<SoldierKind>
    let attackerLanes: [Int]
    let defenderLanes: [Int]
    let hasLanded: Bool

    init(_ battle: LaneBattle, hasLanded: Bool = false) {
        command = Int(battle.attackerCommand)
        seconds = Int(battle.timeRemaining.rounded(.up))
        reserve = battle.attackerReserve
        affordable = Set(SoldierKind.allCases.filter(battle.canDeploy))
        attackerLanes = (0..<LaneBattle.lanes).map { lane in battle.units.filter { $0.side == .attacker && $0.lane == lane }.count }
        defenderLanes = (0..<LaneBattle.lanes).map { lane in battle.units.filter { $0.side == .defender && $0.lane == lane }.count }
        self.hasLanded = hasLanded
    }
    var timer: String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
    var spokenSummary: String {
        let lanes = attackerLanes.indices.map { "Lane \($0+1): \(attackerLanes[$0]) friendly, \(defenderLanes[$0]) enemy" }.joined(separator: ". ")
        return "\(reserve[.knight]) knights and \(reserve[.archer]) archers ready to land. \(lanes)."
    }
}

/// Quantize before crossing into SwiftUI; unchanged values never publish.
struct BattleHUDPublisher {
    private var previous: BattleHUDState
    private var lastPublish = -Double.infinity
    init(_ battle: LaneBattle) { previous = BattleHUDState(battle) }
    mutating func update(_ battle: LaneBattle, now: Double, hasLanded: Bool) -> BattleHUDState? {
        guard now-lastPublish >= 0.25 else { return nil }
        let next = BattleHUDState(battle, hasLanded: hasLanded)
        guard next != previous else { return nil }
        previous = next; lastPublish = now
        return next
    }
}

struct BattleBriefing {
    let battle: LaneBattle
    let source: Town
    let target: Town
    let power: Int
    let defense: Int
    var odds: String { Self.odds(power: power, defense: defense) }
    static func odds(power: Int, defense: Int) -> String {
        let ratio = defense > 0 ? Double(power)/Double(defense) : (power > 0 ? Double.infinity : 0)
        if ratio < 0.85 { return "Outmatched" }
        if ratio < 1.1 { return "Even fight" }
        if ratio < 1.5 { return "Favoured" }
        return "Overwhelming"
    }
}

struct BattleReport {
    let townName: String
    let outcome: LaneBattle.Outcome
    let elapsed: Double
    let attackers: SoldierRoster
    let defenders: SoldierRoster
    let attackerLosses: SoldierRoster
    let defenderLosses: SoldierRoster
    let plunder: [ResourceKind: Int]

    init(initial: LaneBattle, result: LaneBattle, townName: String, plunder: [ResourceKind: Int]) {
        self.townName = townName
        outcome = result.outcome ?? .repelled
        elapsed = result.elapsed
        attackers = result.survivors(.attacker); defenders = result.survivors(.defender)
        var lostA = initial.survivors(.attacker), lostD = initial.survivors(.defender)
        lostA.subtract(attackers); lostD.subtract(defenders)
        attackerLosses = lostA; defenderLosses = lostD
        self.plunder = plunder
    }
    var title: String {
        switch outcome { case .captured: "Captured"; case .repelled: "Repelled"; case .withdrew: "Withdrew" }
    }
}
