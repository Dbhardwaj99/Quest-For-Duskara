import Foundation

struct WorldGenerationResult {
    var world: WorldMapState
    var nodes: [WorldTownNode]
    var connections: [TownConnection]
}

struct WorldGenerator {
    private let terrainGenerator = TerrainGenerator()

    func generate(towns: [Town], seed: Int = 73_021) -> WorldGenerationResult {
        let layout = MapLayout.standard
        let generation = WorldGenerationState(
            seed: seed,
            algorithmVersion: 1,
            templateID: "expanding-realm-v1"
        )
        let terrainTiles = terrainGenerator.generateTerrain(layout: layout, seed: seed)
        let world = WorldMapState(
            generation: generation,
            layout: layout,
            terrainTiles: terrainTiles,
            landmarks: makeLandmarks(from: terrainTiles, layout: layout)
        )
        let gridColumns = cityGridColumns(for: towns.count)
        let nodes = makeNodes(towns: towns, layout: layout, gridColumns: gridColumns, seed: seed)
        let connections = makeConnections(townIDs: towns.map(\.id), gridColumns: gridColumns)

        return WorldGenerationResult(world: world, nodes: nodes, connections: connections)
    }

    func generateWorldState(seed: Int = 73_021, layout: MapLayout = .standard) -> WorldMapState {
        let terrainTiles = terrainGenerator.generateTerrain(layout: layout, seed: seed)
        return WorldMapState(
            generation: WorldGenerationState(
                seed: seed,
                algorithmVersion: 1,
                templateID: "loaded-save-upgrade-v1"
            ),
            layout: layout,
            terrainTiles: terrainTiles,
            landmarks: makeLandmarks(from: terrainTiles, layout: layout)
        )
    }

    private func makeNodes(
        towns: [Town],
        layout: MapLayout,
        gridColumns: Int,
        seed: Int
    ) -> [WorldTownNode] {
        guard towns.isEmpty == false else { return [] }
        let rows = Int(ceil(Double(towns.count) / Double(max(1, gridColumns))))
        let xSpan = 1.0 - layout.playableInset * 2.0
        let ySpan = 1.0 - layout.playableInset * 2.0

        return towns.enumerated().map { index, town in
            let column = index % gridColumns
            let row = index / gridColumns
            let baseX = layout.playableInset + normalizedOffset(column, count: gridColumns) * xSpan
            let baseY = layout.playableInset + normalizedOffset(row, count: rows) * ySpan
            let jitterX = jitter(seed: seed, index: index, salt: 7) * 0.032
            let jitterY = jitter(seed: seed, index: index, salt: 19) * 0.026

            return WorldTownNode(
                townID: town.id,
                x: clamp(baseX + jitterX, min: layout.playableInset, max: 1.0 - layout.playableInset),
                y: clamp(baseY + jitterY, min: layout.playableInset, max: 1.0 - layout.playableInset)
            )
        }
    }

    private func makeConnections(townIDs: [UUID], gridColumns: Int) -> [TownConnection] {
        guard townIDs.isEmpty == false else { return [] }
        let rows = Int(ceil(Double(townIDs.count) / Double(max(1, gridColumns))))
        var connections: Set<TownConnection> = []

        func townID(row: Int, column: Int) -> UUID? {
            guard row >= 0, column >= 0, column < gridColumns else { return nil }
            let index = row * gridColumns + column
            guard index >= 0 && index < townIDs.count else { return nil }
            return townIDs[index]
        }

        func connect(_ source: UUID?, _ target: UUID?) {
            guard let source, let target else { return }
            connections.insert(TownConnection(from: source, to: target))
        }

        for row in 0..<rows {
            for column in 0..<gridColumns {
                let current = townID(row: row, column: column)
                connect(current, townID(row: row, column: column + 1))
                connect(current, townID(row: row + 1, column: column))

                if (row + column).isMultiple(of: 2) {
                    connect(current, townID(row: row + 1, column: column + 1))
                } else {
                    connect(current, townID(row: row + 1, column: column - 1))
                }
            }
        }

        return Array(connections)
    }

    private func makeLandmarks(from tiles: [TerrainTile], layout: MapLayout) -> [WorldLandmark] {
        let landmarkRequests: [(String, WorldLandmarkKind, TerrainKind, ClosedRange<Double>)] = [
            ("Crownless Stones", .ancientRuin, .plains, 0.18...0.42),
            ("Wyrdwood Shrine", .forestShrine, .forest, 0.28...0.66),
            ("Gate of Cinders", .mountainGate, .mountains, 0.42...0.72),
            ("Saltwind Harbor", .coastalHarbor, .coast, 0.70...0.96),
            ("Sable Obelisk", .desertObelisk, .desert, 0.46...0.84)
        ]

        return landmarkRequests.compactMap { request in
            guard let tile = tiles.first(where: { tile in
                tile.terrain == request.2 && request.3.contains(tile.cell.center(in: layout).x)
            }) else {
                return nil
            }
            return WorldLandmark(name: request.0, kind: request.1, position: tile.cell.center(in: layout))
        }
    }

    private func cityGridColumns(for townCount: Int) -> Int {
        max(5, Int(ceil(sqrt(Double(max(1, townCount)) * 1.12))))
    }

    private func normalizedOffset(_ index: Int, count: Int) -> Double {
        guard count > 1 else { return 0.5 }
        return Double(index) / Double(count - 1)
    }

    private func jitter(seed: Int, index: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value = value &+ UInt64(index + 1) &* 0x9E3779B185EBCA87
        value = value ^ (UInt64(salt + 13) &* 0xC2B2AE3D27D4EB4F)
        value ^= value >> 33
        value &*= 0xFF51AFD7ED558CCD
        value ^= value >> 33
        return (Double(value % 10_000) / 10_000.0) - 0.5
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
