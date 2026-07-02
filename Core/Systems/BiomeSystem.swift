import Foundation

struct BiomeSystem {
    func touchingSides(for coordinate: GridCoordinate, gridSize: GridSize) -> [BiomeSide] {
        var sides: [BiomeSide] = []
        if coordinate.y == 0 { sides.append(.top) }
        if coordinate.x == gridSize.columns - 1 { sides.append(.right) }
        if coordinate.y == gridSize.rows - 1 { sides.append(.bottom) }
        if coordinate.x == 0 { sides.append(.left) }
        return sides
    }
}
