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
