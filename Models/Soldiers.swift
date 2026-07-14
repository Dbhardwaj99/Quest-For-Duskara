import Foundation

enum SoldierKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case archer
    case knight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .archer: "Archer"
        case .knight: "Knight"
        }
    }
}

struct SoldierDefinition: Identifiable, Codable, Equatable {
    var id: SoldierKind { kind }
    var kind: SoldierKind
    var trainingCost: [ResourceKind: Int]
    var power: Int
    var peopleRequired: Int
    var dailyFoodUpkeep: Int
}

struct SoldierRoster: Codable, Equatable {
    var counts: [SoldierKind: Int] = [:]

    subscript(_ kind: SoldierKind) -> Int {
        get { counts[kind, default: 0] }
        set { counts[kind] = max(0, newValue) }
    }

    mutating func add(_ kind: SoldierKind, count: Int) {
        self[kind] = self[kind] + count
    }

    func armyStrength(using definitions: [SoldierKind: SoldierDefinition]) -> Int {
        counts.reduce(0) { partial, entry in
            partial + entry.value * (definitions[entry.key]?.power ?? 0)
        }
    }

    mutating func clear() {
        counts.removeAll()
    }

    func manpowerCommitted(using definitions: [SoldierKind: SoldierDefinition]) -> Int {
        counts.reduce(0) { partial, entry in
            partial + entry.value * (definitions[entry.key]?.peopleRequired ?? 0)
        }
    }

    /// Kinds ordered by unit power, strongest first, with the declaration
    /// order of SoldierKind as the stable tie-break.
    static func kindsByPowerDescending(using definitions: [SoldierKind: SoldierDefinition]) -> [SoldierKind] {
        SoldierKind.allCases.sorted {
            (definitions[$0]?.power ?? 0) > (definitions[$1]?.power ?? 0)
        }
    }

    /// Greedily selects whole units, strongest first, whose combined power
    /// fits within `power`. Used for committing armies and transfers.
    func fitting(power: Int, using definitions: [SoldierKind: SoldierDefinition]) -> SoldierRoster {
        var remaining = power
        var selected = SoldierRoster()
        for kind in Self.kindsByPowerDescending(using: definitions) {
            let unitPower = definitions[kind]?.power ?? 0
            guard unitPower > 0 else { continue }
            let count = min(self[kind], remaining / unitPower)
            if count > 0 {
                selected.add(kind, count: count)
                remaining -= count * unitPower
            }
        }
        return selected
    }

    /// Deterministically converts raw strength into whole units, strongest
    /// first, rounding any remainder up to one extra of the weakest kind so
    /// a non-zero garrison never dissolves.
    static func decompose(strength: Int, using definitions: [SoldierKind: SoldierDefinition]) -> SoldierRoster {
        var roster = SoldierRoster()
        guard strength > 0 else { return roster }
        var remaining = strength
        let kinds = kindsByPowerDescending(using: definitions).filter { (definitions[$0]?.power ?? 0) > 0 }
        for kind in kinds {
            let unitPower = definitions[kind]!.power
            let count = remaining / unitPower
            if count > 0 {
                roster.add(kind, count: count)
                remaining -= count * unitPower
            }
        }
        if remaining > 0, let weakest = kinds.last {
            roster.add(weakest, count: 1)
        }
        return roster
    }

    mutating func subtract(_ other: SoldierRoster) {
        for (kind, count) in other.counts {
            self[kind] = self[kind] - count
        }
    }

    mutating func merge(_ other: SoldierRoster) {
        for (kind, count) in other.counts {
            self[kind] = self[kind] + count
        }
    }

    /// Removes units, weakest first, until at least `strength` power is
    /// gone or the roster is empty. Returns the power actually removed.
    @discardableResult
    mutating func removeStrength(atLeast strength: Int, using definitions: [SoldierKind: SoldierDefinition]) -> Int {
        var removed = 0
        let weakestFirst = Self.kindsByPowerDescending(using: definitions).reversed()
        for kind in weakestFirst {
            let unitPower = definitions[kind]?.power ?? 0
            guard unitPower > 0 else { continue }
            while removed < strength, self[kind] > 0 {
                self[kind] -= 1
                removed += unitPower
            }
        }
        return removed
    }

    mutating func removeHighestUpkeepUnit(using definitions: [SoldierKind: SoldierDefinition]) -> SoldierKind? {
        let order = SoldierKind.allCases.sorted {
            (definitions[$1]?.dailyFoodUpkeep ?? 0) < (definitions[$0]?.dailyFoodUpkeep ?? 0)
        }
        for kind in order where self[kind] > 0 {
            self[kind] -= 1
            return kind
        }
        return nil
    }
}
