import Foundation

/// A JSON value that keeps its keys in the order they were written, so a state
/// reads top-down (day first) and the same campaign always prints the same
/// bytes. Foundation's encoder either sorts keys or leaves them in hash order.
indirect enum JSON {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSON])
    case object([(String, JSON)])

    func rendered(pretty: Bool) -> String {
        var out = ""
        write(to: &out, pretty: pretty, indent: 0)
        return out
    }

    private var isScalar: Bool {
        switch self {
        case .array, .object: false
        default: true
        }
    }

    private func write(to out: inout String, pretty: Bool, indent: Int) {
        switch self {
        case .null:
            out += "null"
        case let .bool(value):
            out += value ? "true" : "false"
        case let .int(value):
            out += String(value)
        case let .double(value):
            guard value.isFinite else { out += "null"; return }
            let rounded = (value * 1_000).rounded() / 1_000
            out += rounded == rounded.rounded() && abs(rounded) < 1e15 ? String(Int(rounded)) : String(rounded)
        case let .string(value):
            Self.quote(value, into: &out)
        case let .array(items):
            guard items.isEmpty == false else { out += "[]"; return }
            // Lists of plain values stay on one line; they are short.
            let broken = pretty && items.contains { $0.isScalar == false }
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += pretty && !broken ? ", " : "," }
                if broken { Self.newline(&out, indent + 1) }
                item.write(to: &out, pretty: pretty, indent: indent + 1)
            }
            if broken { Self.newline(&out, indent) }
            out += "]"
        case let .object(fields):
            guard fields.isEmpty == false else { out += "{}"; return }
            out += "{"
            for (index, field) in fields.enumerated() {
                if index > 0 { out += "," }
                if pretty { Self.newline(&out, indent + 1) }
                Self.quote(field.0, into: &out)
                out += pretty ? ": " : ":"
                field.1.write(to: &out, pretty: pretty, indent: indent + 1)
            }
            if pretty { Self.newline(&out, indent) }
            out += "}"
        }
    }

    private static func newline(_ out: inout String, _ indent: Int) {
        out += "\n" + String(repeating: "  ", count: indent)
    }

    private static func quote(_ text: String, into out: inout String) {
        out += "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case _ where scalar.value < 0x20:
                let hex = String(scalar.value, radix: 16)
                out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
            default: out.unicodeScalars.append(scalar)
            }
        }
        out += "\""
    }
}

extension JSON {
    /// Amounts in a fixed resource order, leaving out kinds that aren't there.
    static func amounts(_ amounts: [ResourceKind: Int], _ kinds: [ResourceKind] = ResourceKind.displayOrder) -> JSON {
        .object(kinds.compactMap { kind in amounts[kind].map { (kind.rawValue, .int($0)) } })
    }

    /// Every kind listed, zero when missing: stockpiles and daily changes.
    static func wallet(_ amounts: [ResourceKind: Int], _ kinds: [ResourceKind] = GameRules.sharedKinds) -> JSON {
        .object(kinds.map { ($0.rawValue, .int(amounts[$0, default: 0])) })
    }

    static func units(_ roster: SoldierRoster) -> JSON {
        .object(SoldierKind.allCases.map { ($0.rawValue, .int(roster[$0])) })
    }

    static func strings(_ values: [String]) -> JSON {
        .array(values.map(JSON.string))
    }
}

extension ResourceKind {
    static let displayOrder: [ResourceKind] = [.gold, .food, .skill, .people, .soldiers]
}

/// "400g 200s 100f": how the playtester writes a price in one line.
func priceText(_ amounts: [ResourceKind: Int]) -> String {
    let parts = ResourceKind.displayOrder.compactMap { kind -> String? in
        guard let amount = amounts[kind], amount != 0 else { return nil }
        return "\(amount)\(kind.symbol.lowercased())"
    }
    return parts.isEmpty ? "free" : parts.joined(separator: " ")
}

/// "200 more skill, 2 more people".
func shortfallText(_ missing: [ResourceKind: Int]) -> String {
    ResourceKind.displayOrder.compactMap { kind in
        missing[kind].map { "\($0) more \(kind.rawValue)" }
    }.joined(separator: ", ")
}
