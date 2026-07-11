import Foundation

/// A replicated player command. The server validates and applies it inside a
/// transaction; the same encoded form is the contract for the TypeScript
/// reducer, so the payload uses an explicit type discriminator instead of
/// Swift's synthesized enum encoding.
struct GameAction: Codable, Equatable {
    /// Client-minted idempotency key. Resubmitting the same actionID must
    /// never apply the action twice.
    var actionID: String
    var participantID: String
    /// Revision the client believes the match is at. The server rejects the
    /// action when it no longer matches.
    var expectedRevision: Int
    var schemaVersion: Int
    var rulesVersion: Int
    var payload: GameActionPayload

    init(
        actionID: String = UUID().uuidString,
        participantID: String,
        expectedRevision: Int,
        payload: GameActionPayload
    ) {
        self.actionID = actionID
        self.participantID = participantID
        self.expectedRevision = expectedRevision
        self.schemaVersion = SchemaVersion.current
        self.rulesVersion = SchemaVersion.rules
        self.payload = payload
    }
}

enum GameActionPayload: Equatable {
    case build(townID: String, kind: String, x: Int, y: Int)
    case upgradeBuilding(townID: String, buildingID: String)
    case trainSoldier(townID: String, soldier: String)
    case transferResources(fromTownID: String, toTownID: String, amounts: [String: Int])
    case attack(fromTownID: String, targetTownID: String)
    case advanceDay
}

extension GameActionPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, townID, kind, x, y, buildingID, soldier, fromTownID, toTownID, amounts, targetTownID
    }

    private enum Kind: String, Codable {
        case build, upgradeBuilding, trainSoldier, transferResources, attack, advanceDay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .build:
            self = .build(
                townID: try container.decode(String.self, forKey: .townID),
                kind: try container.decode(String.self, forKey: .kind),
                x: try container.decode(Int.self, forKey: .x),
                y: try container.decode(Int.self, forKey: .y)
            )
        case .upgradeBuilding:
            self = .upgradeBuilding(
                townID: try container.decode(String.self, forKey: .townID),
                buildingID: try container.decode(String.self, forKey: .buildingID)
            )
        case .trainSoldier:
            self = .trainSoldier(
                townID: try container.decode(String.self, forKey: .townID),
                soldier: try container.decode(String.self, forKey: .soldier)
            )
        case .transferResources:
            self = .transferResources(
                fromTownID: try container.decode(String.self, forKey: .fromTownID),
                toTownID: try container.decode(String.self, forKey: .toTownID),
                amounts: try container.decode([String: Int].self, forKey: .amounts)
            )
        case .attack:
            self = .attack(
                fromTownID: try container.decode(String.self, forKey: .fromTownID),
                targetTownID: try container.decode(String.self, forKey: .targetTownID)
            )
        case .advanceDay:
            self = .advanceDay
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .build(townID, kind, x, y):
            try container.encode(Kind.build, forKey: .type)
            try container.encode(townID, forKey: .townID)
            try container.encode(kind, forKey: .kind)
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
        case let .upgradeBuilding(townID, buildingID):
            try container.encode(Kind.upgradeBuilding, forKey: .type)
            try container.encode(townID, forKey: .townID)
            try container.encode(buildingID, forKey: .buildingID)
        case let .trainSoldier(townID, soldier):
            try container.encode(Kind.trainSoldier, forKey: .type)
            try container.encode(townID, forKey: .townID)
            try container.encode(soldier, forKey: .soldier)
        case let .transferResources(fromTownID, toTownID, amounts):
            try container.encode(Kind.transferResources, forKey: .type)
            try container.encode(fromTownID, forKey: .fromTownID)
            try container.encode(toTownID, forKey: .toTownID)
            try container.encode(amounts, forKey: .amounts)
        case let .attack(fromTownID, targetTownID):
            try container.encode(Kind.attack, forKey: .type)
            try container.encode(fromTownID, forKey: .fromTownID)
            try container.encode(targetTownID, forKey: .targetTownID)
        case .advanceDay:
            try container.encode(Kind.advanceDay, forKey: .type)
        }
    }
}
