import Foundation
import Testing

/// Stable IDs and prebuilt game objects for deterministic tests.
enum TestFixtures {
    static let balance = GameBalance.duskDefault

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    static let defaultLayout = TownBiomeLayout(
        sides: [.left: .forest, .right: .mountain, .top: .forest, .bottom: .mountain]
    )

    static func town(
        _ number: Int,
        name: String? = nil,
        faction: TownFaction = .player,
        resources: [ResourceKind: Int] = [.gold: 500, .skill: 300, .food: 100, .people: 10],
        buildings: [BuildingInstance] = [],
        armyStrength: Int = 0,
        soldierRoster: SoldierRoster = SoldierRoster(),
        isDuskara: Bool = false
    ) -> Town {
        var town = Town(
            id: uuid(number),
            name: name ?? "Town \(number)",
            resources: ResourceWallet(resources),
            buildings: buildings,
            biomeLayout: defaultLayout,
            faction: faction,
            isDuskara: isDuskara,
            armyStrength: armyStrength,
            soldierRoster: soldierRoster
        )
        town.resources[.soldiers] = armyStrength
        return town
    }

    static func building(_ number: Int, kind: BuildingKind, x: Int, y: Int, level: Int = 1) -> BuildingInstance {
        BuildingInstance(id: uuid(1000 + number), kind: kind, coordinate: GridCoordinate(x: x, y: y), level: level)
    }

    static func state(
        towns: [Town],
        connections: [TownConnection] = [],
        day: Int = 1,
        activeTownID: UUID? = nil
    ) -> GameState {
        GameState(
            day: day,
            elapsedSecondsInDay: 0,
            towns: towns,
            worldNodes: [],
            connections: connections,
            activeTownID: activeTownID ?? towns[0].id
        )
    }
}

/// Golden-file characterization: encodes a value as canonical JSON and
/// compares it byte-for-byte with a fixture stored in the repository.
/// A missing fixture is recorded on first run so behavior gets pinned.
enum GoldenFixture {
    static var directory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static func canonicalJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    static func assertMatches<T: Encodable>(
        _ value: T,
        fixture name: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let data = try canonicalJSON(value)
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url)
            Issue.record(
                "Recorded new fixture \(name); re-run to verify against it.",
                sourceLocation: sourceLocation
            )
            return
        }
        let stored = try Data(contentsOf: url)
        if stored != data {
            // Leave the diverging output next to the fixture for diffing.
            try? data.write(to: url.appendingPathExtension("actual"))
        }
        #expect(
            stored == data,
            "Output diverged from fixture \(name). If the change is intentional, delete the fixture and re-record.",
            sourceLocation: sourceLocation
        )
    }
}

extension Array where Element == TownConnection {
    /// Stable ordering for fixtures: connection sets have no inherent order.
    func canonicallySorted() -> [TownConnection] {
        sorted {
            ($0.from.uuidString, $0.to.uuidString) < ($1.from.uuidString, $1.to.uuidString)
        }
    }
}
