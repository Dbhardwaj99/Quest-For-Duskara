import Foundation

enum ResourceKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case gold
    case wood
    case coal
    case tech
    case food
    case people
    case soldiers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gold: "Gold"
        case .wood: "Wood"
        case .coal: "Coal"
        case .tech: "Tech"
        case .food: "Food"
        case .people: "People"
        case .soldiers: "Soldiers"
        }
    }

    var symbol: String {
        switch self {
        case .gold: "G"
        case .wood: "W"
        case .coal: "C"
        case .tech: "T"
        case .food: "F"
        case .people: "P"
        case .soldiers: "S"
        }
    }
}

struct ResourceWallet: Codable, Equatable {
    var amounts: [ResourceKind: Int]

    init(_ amounts: [ResourceKind: Int] = [:]) {
        self.amounts = amounts
    }

    subscript(_ kind: ResourceKind) -> Int {
        get { amounts[kind, default: 0] }
        set { amounts[kind] = max(0, newValue) }
    }

    func value(for kind: ResourceKind) -> Int {
        amounts[kind, default: 0]
    }

    func canAfford(_ cost: [ResourceKind: Int]) -> Bool {
        cost.allSatisfy { value(for: $0.key) >= $0.value }
    }

    mutating func add(_ kind: ResourceKind, amount: Int) {
        self[kind] = value(for: kind) + amount
    }

    mutating func apply(_ changes: [ResourceKind: Int]) {
        for (kind, amount) in changes {
            add(kind, amount: amount)
        }
    }

    @discardableResult
    mutating func spend(_ cost: [ResourceKind: Int]) -> Bool {
        guard canAfford(cost) else { return false }
        for (kind, amount) in cost {
            add(kind, amount: -amount)
        }
        return true
    }

    func merged(with other: ResourceWallet) -> ResourceWallet {
        var copy = self
        copy.apply(other.amounts)
        return copy
    }
}

extension Dictionary where Key == ResourceKind, Value == Int {
    var positiveEntries: [(ResourceKind, Int)] {
        filter { $0.value > 0 }.sorted { $0.key.rawValue < $1.key.rawValue }
    }
}
