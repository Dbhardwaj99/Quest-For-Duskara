import Foundation

/// What a campaign did, for simulation reports.
struct CampaignStats {
    struct Issue {
        var severity: String
        var message: String
        /// The message with island names and numbers taken out, so the same
        /// finding on different islands counts as one.
        var key: String
        var day: Int
        /// The commands leading up to it, for a reproduction.
        var recentCommands: [String]
        var occurrences = 1
    }

    var actions = 0
    var refused = 0
    var battles = 0
    var captures = 0
    var withdrawals = 0
    var powerLostInBattle = 0
    var firstCaptureDay: Int?
    var hungerLosses = 0
    var islandsLost = 0
    var trades = 0
    var marketGold = 0
    var peakIslands = 1
    var peakArmy = 0
    /// The longest run of days without building, upgrading, training or
    /// capturing anything.
    var longestStall = 0
    private var lastProgressDay = 1
    var issues: [Issue] = []

    mutating func count(_ command: PlaytestCommand, _ outcome: Outcome, day: Int) {
        actions += 1
        if outcome.ok == false { refused += 1 }
        let progress: Bool = switch command {
        case .build, .upgrade, .train: outcome.ok
        default: false
        }
        if progress { progressed(on: day) }
    }

    mutating func battle(_ outcome: LaneBattle.Outcome?, day: Int, lost: Int) {
        battles += 1
        powerLostInBattle += max(0, lost)
        switch outcome {
        case .captured:
            captures += 1
            if firstCaptureDay == nil { firstCaptureDay = day }
            progressed(on: day)
        case .withdrew:
            withdrawals += 1
        default:
            break
        }
    }

    mutating func observe(_ session: PlaytestSession) {
        peakIslands = max(peakIslands, session.game.playerTowns.count)
        peakArmy = max(peakArmy, session.game.empireArmyStrength)
    }

    mutating func finish(on day: Int) {
        longestStall = max(longestStall, day - lastProgressDay)
    }

    /// Keeps the first of each kind of finding and counts the rest.
    mutating func record(violations: [String], anomalies: [String], session: PlaytestSession) {
        let found = violations.map { ("violation", $0) } + anomalies.map { ("anomaly", $0) }
        for (severity, message) in found {
            let key = severity + ": " + Self.shape(of: message, islands: session.game.state.towns.map(\.name))
            if let index = issues.firstIndex(where: { $0.key == key }) {
                issues[index].occurrences += 1
            } else {
                issues.append(Issue(severity: severity, message: message, key: key, day: session.game.state.day,
                                    recentCommands: Array(session.log.suffix(8))))
            }
        }
    }

    static func shape(of message: String, islands: [String]) -> String {
        var text = message
        for name in islands.sorted(by: { $0.count > $1.count }) {
            text = text.replacingOccurrences(of: name, with: "<island>")
        }
        var shape = ""
        for character in text {
            if character.isNumber {
                if shape.last != "#" { shape.append("#") }
            } else {
                shape.append(character)
            }
        }
        return shape
    }

    private mutating func progressed(on day: Int) {
        longestStall = max(longestStall, day - lastProgressDay)
        lastProgressDay = day
    }
}
