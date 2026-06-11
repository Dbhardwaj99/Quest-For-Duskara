import Foundation

struct TerrainGenerator {
    func generateTerrain(layout: MapLayout, seed: Int) -> [TerrainTile] {
        var tiles: [TerrainTile] = []
        tiles.reserveCapacity(layout.columns * layout.rows)

        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let cell = MapCell(column: column, row: row)
                tiles.append(TerrainTile(cell: cell, terrain: terrain(for: cell, in: layout, seed: seed)))
            }
        }

        return tiles
    }

    func terrain(for cell: MapCell, in layout: MapLayout, seed: Int) -> TerrainKind {
        let point = cell.center(in: layout)
        let edgeDistance = min(point.x, point.y, 1.0 - point.x, 1.0 - point.y)
        let coastNoise = noise(seed: seed, column: cell.column, row: cell.row, salt: 11)

        if edgeDistance < 0.035 || (point.y > 0.88 && coastNoise > 0.24) || (point.x > 0.94 && coastNoise > 0.34) {
            return .coast
        }

        let ridge = 0.49 + sin(point.x * 7.2) * 0.055 + (noise(seed: seed, column: cell.column, row: cell.row, salt: 23) - 0.5) * 0.08
        if abs(point.y - ridge) < 0.048 && point.x > 0.16 && point.x < 0.92 {
            return .mountains
        }

        let dryNoise = noise(seed: seed, column: cell.column, row: cell.row, salt: 37)
        if point.y < 0.30 && point.x > 0.46 && dryNoise > 0.22 {
            return .desert
        }

        let forestNoise = noise(seed: seed, column: cell.column, row: cell.row, salt: 53)
        if forestNoise > 0.61 || (point.x < 0.38 && point.y > 0.24 && point.y < 0.84 && forestNoise > 0.34) {
            return .forest
        }

        return .plains
    }

    private func noise(seed: Int, column: Int, row: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value = value &+ UInt64(column + 31) &* 0x9E3779B185EBCA87
        value = value ^ (UInt64(row + 17) &* 0xC2B2AE3D27D4EB4F)
        value = value &+ UInt64(salt + 101) &* 0x165667B19E3779F9
        value ^= value >> 33
        value &*= 0xFF51AFD7ED558CCD
        value ^= value >> 33
        value &*= 0xC4CEB9FE1A85EC53
        value ^= value >> 33
        return Double(value % 10_000) / 10_000.0
    }
}
