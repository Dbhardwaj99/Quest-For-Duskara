import Foundation

/// A lane assault. The attacker lands units on the shore, one at a time from a
/// refilling command meter, and fights up three lanes to break the gate before
/// time runs out. The garrison starts spread across every lane and the rest
/// reinforces wherever the pressure is — late — so concentrating, feinting and
/// screening archers behind knights let a smaller army beat a bigger one.
///
/// A pure value type so the rules are testable; LaneBattleScene only draws it
/// and feeds it input. Positions run from 0 (shore) to 1 (gate).
struct LaneBattle {
    enum Side { case attacker, defender }
    enum Outcome { case captured, repelled, withdrew }

    struct Stats {
        let health: Double
        let damage: Double
        let interval: Double
        let range: Double
        let speed: Double
        let cost: Double
    }

    struct Unit: Identifiable {
        let id: Int
        let kind: SoldierKind
        let side: Side
        var lane: Int
        var position: Double
        var health: Double
        var cooldown = 0.0
    }

    /// What happened during the last steps, for the scene to animate. The
    /// scene drains it; nothing in the rules reads it.
    enum Event {
        case shot(lane: Int, from: Double, to: Double, side: Side)
        case fell(lane: Int, at: Double, side: Side)
        case gateHit
    }

    static let lanes = 3
    /// The fixed step the battle advances by, so an outcome never depends on
    /// the frame rate.
    static let tick = 1.0 / 60
    static let timeLimit = 90.0
    static let maxCommand = 10.0
    static let startingCommand = 6.0
    static let commandPerSecond = 1.0
    /// Where idle defenders wait for attackers.
    static let holdLine = 0.62
    /// How often the garrison sends one reinforcement — the lag a feint exploits.
    static let reinforceInterval = 1.2
    static let towerRange = 0.3
    /// An attacker past this point has reached the fortress: idle defenders
    /// fall back through the gate to meet it.
    static let breachLine = 0.95
    static let towerInterval = 1.2
    /// The fortress scales with fortification — the town's defense that isn't
    /// its garrison (walls, Duskara, distance) — so a hamlet's walls never
    /// outweigh the armies fighting over it.
    static let gateBase = 20.0
    static let gatePerFortification = 6.0
    static let towerDamagePerFortification = 0.12

    // ponytail: stats tuned so a unit's health × damage tracks its power²
    // (Knight 24 vs Archer 10), the square law that makes strength comparable.
    static func stats(_ kind: SoldierKind) -> Stats {
        switch kind {
        case .archer: Stats(health: 40, damage: 6, interval: 1, range: 0.22, speed: 0.07, cost: 2)
        case .knight: Stats(health: 100, damage: 14, interval: 1, range: 0.035, speed: 0.06, cost: 4)
        }
    }

    let sourceID: UUID
    let targetID: UUID
    let gateMaxHealth: Double
    let towerDamage: Double
    private(set) var units: [Unit] = []
    private(set) var attackerReserve: SoldierRoster
    private(set) var defenderReserve: SoldierRoster
    private(set) var attackerCommand = startingCommand
    private(set) var gateHealth: Double
    private(set) var elapsed = 0.0
    private(set) var outcome: Outcome?
    var events: [Event] = []
    private var nextID = 0
    private var towerCooldown = 0.0
    private var reinforceCooldown = reinforceInterval

    init(sourceID: UUID, targetID: UUID, attackers: SoldierRoster, defenders: SoldierRoster, fortification: Int) {
        self.sourceID = sourceID
        self.targetID = targetID
        attackerReserve = attackers
        defenderReserve = defenders
        gateMaxHealth = Self.gateBase + Double(max(0, fortification)) * Self.gatePerFortification
        towerDamage = Double(max(0, fortification)) * Self.towerDamagePerFortification
        gateHealth = gateMaxHealth
        // A third of the garrison (rounded up) starts on the line, dealt
        // round-robin so every lane is held thinly; the rest is the reserve.
        let stationed = (defenders.counts.values.reduce(0, +) + 2) / 3
        for index in 0..<stationed {
            guard let kind = [SoldierKind.knight, .archer].first(where: { defenderReserve[$0] > 0 }) else { break }
            spawn(kind, side: .defender, lane: index % Self.lanes, at: Self.holdLine)
        }
    }

    var timeRemaining: Double { max(0, Self.timeLimit - elapsed) }

    func canDeploy(_ kind: SoldierKind) -> Bool {
        outcome == nil && attackerReserve[kind] > 0 && attackerCommand >= Self.stats(kind).cost
    }

    @discardableResult
    mutating func deploy(_ kind: SoldierKind, lane: Int) -> Bool {
        guard canDeploy(kind), (0..<Self.lanes).contains(lane) else { return false }
        attackerCommand -= Self.stats(kind).cost
        spawn(kind, side: .attacker, lane: lane, at: 0)
        return true
    }

    /// Sounds the retreat: every attacker still standing sails home.
    mutating func withdraw() {
        guard outcome == nil else { return }
        outcome = .withdrew
    }

    /// Everyone on `side` still alive, deployed or not.
    func survivors(_ side: Side) -> SoldierRoster {
        var roster = side == .attacker ? attackerReserve : defenderReserve
        for unit in units where unit.side == side { roster.add(unit.kind, count: 1) }
        return roster
    }

    mutating func step(_ dt: Double) {
        guard outcome == nil, dt > 0 else { return }
        elapsed += dt
        attackerCommand = min(Self.maxCommand, attackerCommand + Self.commandPerSecond * dt)
        reinforceCooldown -= dt
        if reinforceCooldown <= 0 {
            reinforceCooldown = Self.reinforceInterval
            reinforce()
        }

        for index in units.indices where units[index].health > 0 {
            act(index, dt: dt)
        }
        fireTower(dt)

        for unit in units where unit.health <= 0 {
            events.append(.fell(lane: unit.lane, at: unit.position, side: unit.side))
        }
        units.removeAll { $0.health <= 0 }

        if gateHealth <= 0 {
            outcome = .captured
        } else if elapsed >= Self.timeLimit
            || (attackerReserve.counts.values.allSatisfy { $0 == 0 } && units.contains { $0.side == .attacker } == false) {
            outcome = .repelled
        }
    }

    // MARK: - Rules

    private mutating func act(_ index: Int, dt: Double) {
        let unit = units[index]
        let stats = Self.stats(unit.kind)
        units[index].cooldown -= dt
        if let target = nearestEnemy(of: unit, within: stats.range) {
            guard units[index].cooldown <= 0 else { return }
            units[index].cooldown = stats.interval
            units[target].health -= stats.damage
            if unit.kind == .archer {
                events.append(.shot(lane: unit.lane, from: unit.position, to: units[target].position, side: unit.side))
            }
        } else if unit.side == .attacker {
            if unit.position >= 1 {
                guard units[index].cooldown <= 0 else { return }
                units[index].cooldown = stats.interval
                gateHealth -= stats.damage
                events.append(.gateHit)
            } else {
                units[index].position = min(1, unit.position + stats.speed * dt)
            }
        } else {
            // Defenders charge the nearest attacker in their lane. With their
            // own lane clear and the fortress under threat, they fall back
            // through the gate — which joins every lane — and come out where
            // they're needed; otherwise they hold the line.
            var goal = Self.holdLine
            if let enemy = nearestEnemy(of: unit, within: 1) {
                goal = units[enemy].position
            } else if let breached = breachedLane, breached != unit.lane {
                goal = 1
                if unit.position >= 1 { units[index].lane = breached }
            }
            let step = stats.speed * dt
            units[index].position += max(-step, min(step, goal - unit.position))
        }
    }

    private func nearestEnemy(of unit: Unit, within range: Double) -> Int? {
        units.indices
            .filter { units[$0].side != unit.side && units[$0].lane == unit.lane && units[$0].health > 0 }
            .map { ($0, abs(units[$0].position - unit.position)) }
            .filter { $0.1 <= range }
            .min { $0.1 < $1.1 }?.0
    }

    /// The gate tower shoots whichever attacker is closest to the gate.
    private mutating func fireTower(_ dt: Double) {
        towerCooldown -= dt
        guard towerCooldown <= 0,
              let target = units.indices
                .filter({ units[$0].side == .attacker && units[$0].health > 0 && units[$0].position >= 1 - Self.towerRange })
                .max(by: { units[$0].position < units[$1].position }) else { return }
        towerCooldown = Self.towerInterval
        units[target].health -= towerDamage
        events.append(.shot(lane: units[target].lane, from: 1, to: units[target].position, side: .defender))
    }

    /// How much attackers outweigh defenders in a lane, weighting attackers by
    /// how close they are to the gate.
    private func pressure(_ lane: Int) -> Double {
        units.filter { $0.lane == lane }.reduce(0) { total, unit in
            unit.side == .attacker ? total + unit.health * (0.5 + unit.position) : total - unit.health
        }
    }

    /// The worst-pressed lane with an attacker at the fortress, if any.
    private var breachedLane: Int? {
        (0..<Self.lanes)
            .filter { lane in units.contains { $0.side == .attacker && $0.lane == lane && $0.position >= Self.breachLine } }
            .max { pressure($0) < pressure($1) }
    }

    /// One reinforcement to the lane under the most pressure.
    private mutating func reinforce() {
        guard let lane = (0..<Self.lanes).max(by: { pressure($0) < pressure($1) }), pressure(lane) > 0,
              let kind = [SoldierKind.knight, .archer].first(where: { defenderReserve[$0] > 0 }) else { return }
        spawn(kind, side: .defender, lane: lane, at: 1)
    }

    private mutating func spawn(_ kind: SoldierKind, side: Side, lane: Int, at position: Double) {
        if side == .attacker { attackerReserve[kind] -= 1 } else { defenderReserve[kind] -= 1 }
        units.append(Unit(id: nextID, kind: kind, side: side, lane: lane, position: position, health: Self.stats(kind).health))
        nextID += 1
    }
}
