import Foundation

struct TerrainGenerator {
    // Large enough to read as an island rather than a map pin. The v2 world
    // generator spaces centers far enough apart to preserve water channels.
    private let islandRadius = 0.072
    // Fraction of the radius that is interior terrain; the rest is shoreline.
    private let coastFraction = 0.70

    func generateTerrain(layout: MapLayout, seed: Int, nodes: [WorldTownNode]) -> [TerrainTile] {
        var tiles: [TerrainTile] = []
        tiles.reserveCapacity(layout.columns * layout.rows)

        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let cell = MapCell(column: column, row: row)
                tiles.append(TerrainTile(cell: cell, terrain: terrain(for: cell, in: layout, seed: seed, nodes: nodes)))
            }
        }

        return tiles
    }

    func terrain(for cell: MapCell, in layout: MapLayout, seed: Int, nodes: [WorldTownNode]) -> TerrainKind {
        guard nodes.isEmpty == false else { return .water }
        let point = cell.center(in: layout)
        let nearestDistance = nodes
            .map { node in distance(from: point, to: MapPoint(x: node.x, y: node.y), aspectRatio: layout.aspectRatio) }
            .min() ?? .infinity

        // Wobble the radius per cell so coastlines come out irregular instead
        // of stamped circles.
        let coastWobble = (WorldNoise.value(seed: seed, column: cell.column, row: cell.row, salt: 11) - 0.5) * 0.44
        let radius = islandRadius * (1.0 + coastWobble)
        guard nearestDistance < radius else { return .water }

        if nearestDistance > radius * coastFraction {
            return .coast
        }

        let peakNoise = WorldNoise.value(seed: seed, column: cell.column, row: cell.row, salt: 23)
        if peakNoise > 0.82 {
            return .mountains
        }

        let dryNoise = WorldNoise.value(seed: seed, column: cell.column, row: cell.row, salt: 37)
        if point.y < 0.32 && point.x > 0.52 && dryNoise > 0.40 {
            return .desert
        }

        let forestNoise = WorldNoise.value(seed: seed, column: cell.column, row: cell.row, salt: 53)
        if forestNoise > 0.52 {
            return .forest
        }

        return .plains
    }

    private func distance(from lhs: MapPoint, to rhs: MapPoint, aspectRatio: Double) -> Double {
        let dx = (lhs.x - rhs.x) * aspectRatio
        let dy = lhs.y - rhs.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
