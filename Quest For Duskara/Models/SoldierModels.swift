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
}
