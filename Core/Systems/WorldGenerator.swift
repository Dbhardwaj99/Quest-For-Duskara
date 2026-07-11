import Foundation

struct WorldGenerationResult {
    var world: WorldMapState
    var nodes: [WorldTownNode]
    var connections: [TownConnection]
}

struct WorldGenerator {
    private let terrainGenerator = TerrainGenerator()

    /// Aspect-corrected center separation that keeps two max-wobble islands
    /// from ever merging (2 × max island radius, plus a water channel).
    private let minimumSeparation = 0.135

    /// The seed is always injected by the match creator; nothing in world
    /// generation may read entropy from anywhere else.
    func generate(towns: [Town], seed: Int) -> WorldGenerationResult {
        let layout = MapLayout.standard
        let generation = WorldGenerationState(
            seed: seed,
            algorithmVersion: 3,
            templateID: "archipelago-v1"
        )
        // Nodes come first: every island is grown around its town's node.
        let nodes = makeNodes(towns: towns, layout: layout, seed: seed)
        let terrainTiles = terrainGenerator.generateTerrain(layout: layout, seed: seed, nodes: nodes)
        let world = WorldMapState(
            generation: generation,
            layout: layout,
            terrainTiles: terrainTiles,
            landmarks: makeLandmarks(from: terrainTiles, layout: layout, seed: seed)
        )
        let connections = makeConnections(nodes: nodes, layout: layout)

        return WorldGenerationResult(world: world, nodes: nodes, connections: connections)
    }

    // Organic archipelago placement: most islands gather around a handful of
    // cluster centers, the rest scatter loose. Candidates too close to an
    // existing island are rejected, so islands cluster tightly without ever
    // merging, and nothing sits on a grid.
    private func makeNodes(towns: [Town], layout: MapLayout, seed: Int) -> [WorldTownNode] {
        guard towns.isEmpty == false else { return [] }
        let inset = layout.playableInset
        let span = 1.0 - inset * 2.0

        let clusterCount = 4
        let clusters: [MapPoint] = (0..<clusterCount).map { index in
            MapPoint(
                x: inset + WorldNoise.value(seed: seed, column: index, row: 3, salt: 401) * span,
                y: inset + WorldNoise.value(seed: seed, column: index, row: 9, salt: 409) * span
            )
        }

        var placed: [MapPoint] = []
        for index in towns.indices {
            var best: MapPoint?
            var bestClearance = -Double.infinity

            for attempt in 0..<50 {
                let candidate = candidatePoint(
                    seed: seed, index: index, attempt: attempt,
                    clusters: clusters, inset: inset, span: span
                )
                let clearance = placed
                    .map { distance(from: candidate, to: $0, aspectRatio: layout.aspectRatio) }
                    .min() ?? .infinity

                if clearance >= minimumSeparation {
                    // First valid candidate wins: cluster-biased sampling
                    // means it usually lands snug beside its neighbors.
                    best = candidate
                    bestClearance = clearance
                    break
                }
                if clearance > bestClearance {
                    best = candidate
                    bestClearance = clearance
                }
            }

            placed.append(best ?? MapPoint(x: 0.5, y: 0.5))
        }

        return zip(towns, placed).map { town, point in
            WorldTownNode(townID: town.id, x: point.x, y: point.y)
        }
    }

    private func candidatePoint(
        seed: Int, index: Int, attempt: Int,
        clusters: [MapPoint], inset: Double, span: Double
    ) -> MapPoint {
        let pick = WorldNoise.value(seed: seed, column: index, row: attempt, salt: 431)
        let x: Double
        let y: Double
        if pick < 0.72 {
            // Near a cluster center; squared falloff keeps most towns tight.
            let cluster = clusters[Int(pick * 100) % clusters.count]
            let radius = 0.05 + pow(WorldNoise.value(seed: seed, column: index, row: attempt, salt: 443), 2) * 0.24
            let angle = WorldNoise.value(seed: seed, column: index, row: attempt, salt: 457) * .pi * 2
            x = cluster.x + cos(angle) * radius
            y = cluster.y + sin(angle) * radius
        } else {
            // Loner island anywhere in the playable area.
            x = inset + WorldNoise.value(seed: seed, column: index, row: attempt, salt: 461) * span
            y = inset + WorldNoise.value(seed: seed, column: index, row: attempt, salt: 479) * span
        }
        return MapPoint(
            x: clamp(x, min: inset, max: 1.0 - inset),
            y: clamp(y, min: inset, max: 1.0 - inset)
        )
    }

    // Sea lanes: each island links to its nearest neighbors, then any
    // disconnected groups are stitched together via their closest pair, so
    // the whole archipelago stays navigable.
    private func makeConnections(nodes: [WorldTownNode], layout: MapLayout) -> [TownConnection] {
        guard nodes.count > 1 else { return [] }
        var connections: Set<TownConnection> = []

        func nodeDistance(_ a: Int, _ b: Int) -> Double {
            distance(
                from: MapPoint(x: nodes[a].x, y: nodes[a].y),
                to: MapPoint(x: nodes[b].x, y: nodes[b].y),
                aspectRatio: layout.aspectRatio
            )
        }

        for index in nodes.indices {
            let nearest = nodes.indices
                .filter { $0 != index }
                .sorted { nodeDistance(index, $0) < nodeDistance(index, $1) }
                .prefix(2)
            for neighbor in nearest {
                connections.insert(TownConnection(from: nodes[index].townID, to: nodes[neighbor].townID))
            }
        }

        // Union-find over the nearest-neighbor graph; bridge components
        // through their closest pair until one archipelago remains.
        var parent = Array(nodes.indices)
        func find(_ value: Int) -> Int {
            var root = value
            while parent[root] != root { root = parent[root] }
            parent[value] = root
            return root
        }
        func union(_ a: Int, _ b: Int) { parent[find(a)] = find(b) }

        let idToIndex = Dictionary(uniqueKeysWithValues: nodes.enumerated().map { ($0.element.townID, $0.offset) })
        for connection in connections {
            if let a = idToIndex[connection.from], let b = idToIndex[connection.to] {
                union(a, b)
            }
        }

        while Set(nodes.indices.map(find)).count > 1 {
            var bestPair: (Int, Int)?
            var bestDistance = Double.infinity
            for a in nodes.indices {
                for b in nodes.indices where find(a) != find(b) {
                    let separation = nodeDistance(a, b)
                    if separation < bestDistance {
                        bestDistance = separation
                        bestPair = (a, b)
                    }
                }
            }
            guard let pair = bestPair else { break }
            connections.insert(TownConnection(from: nodes[pair.0].townID, to: nodes[pair.1].townID))
            union(pair.0, pair.1)
        }

        return Array(connections)
    }

    private func distance(from lhs: MapPoint, to rhs: MapPoint, aspectRatio: Double) -> Double {
        let dx = (lhs.x - rhs.x) * aspectRatio
        let dy = lhs.y - rhs.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func makeLandmarks(from tiles: [TerrainTile], layout: MapLayout, seed: Int) -> [WorldLandmark] {
        var idRandom = DeterministicRandom(seed: seed, stream: 0x1A_0000)
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
            return WorldLandmark(id: idRandom.uuid(), name: request.0, kind: request.1, position: tile.cell.center(in: layout))
        }
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
