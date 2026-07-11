import Foundation
import Testing

@Suite("WorldGenerator")
struct WorldGeneratorTests {
    let generator = WorldGenerator()

    private func fixtureTowns(count: Int = 8) -> [Town] {
        (1...count).map { index in
            TestFixtures.town(index, faction: index == count ? .duskara : .neutral, isDuskara: index == count)
        }
    }

    /// WorldLandmark mints a random UUID on generation (render-only identity,
    /// never gameplay). Pin those IDs so worlds can be compared byte-for-byte.
    /// Server/seeded ID creation replaces this in the multiplayer reducer.
    private func normalized(_ world: WorldMapState) -> WorldMapState {
        var world = world
        for index in world.landmarks.indices {
            world.landmarks[index].id = TestFixtures.uuid(9001 + index)
        }
        return world
    }

    @Test func sameSeedProducesIdenticalWorlds() {
        let towns = fixtureTowns()
        let first = generator.generate(towns: towns, seed: 42)
        let second = generator.generate(towns: towns, seed: 42)
        #expect(normalized(first.world) == normalized(second.world))
        #expect(first.nodes == second.nodes)
        #expect(Set(first.connections) == Set(second.connections))
    }

    @Test func differentSeedsProduceDifferentWorlds() {
        let towns = fixtureTowns()
        let first = generator.generate(towns: towns, seed: 42)
        let second = generator.generate(towns: towns, seed: 43)
        #expect(first.nodes != second.nodes)
    }

    @Test func everyTownGetsANodeInsidePlayableBounds() {
        let towns = fixtureTowns(count: 12)
        let result = generator.generate(towns: towns, seed: 7)
        #expect(result.nodes.count == towns.count)
        let inset = result.world.layout.playableInset
        for node in result.nodes {
            #expect(node.x >= inset && node.x <= 1 - inset)
            #expect(node.y >= inset && node.y <= 1 - inset)
        }
    }

    @Test func seaLanesConnectTheWholeArchipelago() {
        let towns = fixtureTowns(count: 12)
        let result = generator.generate(towns: towns, seed: 7)
        let distances = CombatSystem.graphDistances(
            from: result.nodes[0].townID,
            connections: result.connections
        )
        #expect(distances.count == towns.count)
    }

    @Test func terrainCoversTheFullGridWithLandAroundNodes() {
        let towns = fixtureTowns()
        let result = generator.generate(towns: towns, seed: 42)
        let layout = result.world.layout
        #expect(result.world.terrainTiles.count == layout.columns * layout.rows)
        #expect(result.world.terrainTiles.contains { $0.terrain.isLand })
        #expect(result.world.terrainTiles.contains { $0.terrain == .water })
    }

    @Test func generatedWorldMatchesGoldenFixture() throws {
        struct WorldFixture: Codable {
            var world: WorldMapState
            var nodes: [WorldTownNode]
            var connections: [TownConnection]
        }
        let result = generator.generate(towns: fixtureTowns(), seed: 42)
        let fixture = WorldFixture(
            world: normalized(result.world),
            nodes: result.nodes,
            connections: result.connections.canonicallySorted()
        )
        try GoldenFixture.assertMatches(fixture, fixture: "world-8towns-seed42.json")
    }
}
