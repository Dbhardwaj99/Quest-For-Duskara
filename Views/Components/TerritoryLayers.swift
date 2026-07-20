import SwiftUI

struct WorldTerrainLayer: View {
    let world: WorldMapState
    let nodes: [WorldTownNode]

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            let land = world.terrainTiles.filter { $0.terrain.isLand }
            for island in islandGroups(from: land) {
                let interior = island.filter { $0.terrain != .coast }
                drawClayLayer(
                    in: &context,
                    cells: island.map(\.cell),
                    layout: world.layout,
                    projection: projection,
                    color: Color(red: 0.40, green: 0.70, blue: 0.71).opacity(0.62),
                    expansion: 5,
                    yOffset: 6,
                    mergeCells: true
                )
                drawClayLayer(
                    in: &context,
                    cells: island.map(\.cell),
                    layout: world.layout,
                    projection: projection,
                    color: Color(red: 0.54, green: 0.43, blue: 0.30),
                    expansion: 2.5,
                    yOffset: 6,
                    shadow: (0.34, 8, 7),
                    mergeCells: true
                )
                drawClayLayer(
                    in: &context,
                    cells: island.map(\.cell),
                    layout: world.layout,
                    projection: projection,
                    color: TerrainKind.coast.mapColor,
                    expansion: 1.2,
                    yOffset: 1,
                    shadow: (0.18, 3, 3),
                    mergeCells: true
                )
                drawClayLayer(
                    in: &context,
                    cells: interior.map(\.cell),
                    layout: world.layout,
                    projection: projection,
                    color: TerrainKind.plains.mapColor,
                    expansion: 0.6,
                    yOffset: -1,
                    shadow: (0.20, 3, 3),
                    mergeCells: true
                )
            }

            drawTerrainTier(.desert, from: land, in: &context, projection: projection, yOffset: -3)
            drawTerrainTier(.forest, from: land, in: &context, projection: projection, yOffset: -5)
            drawTerrainTier(.mountains, from: land, in: &context, projection: projection, yOffset: -8)
        }
        .allowsHitTesting(false)
    }

    private func islandGroups(from tiles: [TerrainTile]) -> [[TerrainTile]] {
        var groups = Array(repeating: [TerrainTile](), count: nodes.count)
        for tile in tiles {
            let point = tile.cell.center(in: world.layout)
            guard let index = nodes.indices.min(by: {
                distance(from: point, to: nodes[$0]) < distance(from: point, to: nodes[$1])
            }) else { continue }
            groups[index].append(tile)
        }
        return groups.filter { $0.isEmpty == false }
    }

    private func distance(from point: MapPoint, to node: WorldTownNode) -> Double {
        let dx = (point.x - node.x) * world.layout.aspectRatio
        let dy = point.y - node.y
        return dx * dx + dy * dy
    }

    private func drawTerrainTier(
        _ terrain: TerrainKind,
        from tiles: [TerrainTile],
        in context: inout GraphicsContext,
        projection: WorldMapProjection,
        yOffset: CGFloat
    ) {
        drawClayLayer(
            in: &context,
            cells: tiles.filter { $0.terrain == terrain }.map(\.cell),
            layout: world.layout,
            projection: projection,
            color: terrain.mapColor,
            expansion: 0.4,
            yOffset: yOffset,
            shadow: (0.24, 4, 4)
        )
    }
}

struct TerritoryRegionLayer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let selectedTownID: UUID?
    let activeTownID: UUID

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            for region in territory.regions {
                let isSelected = region.townID == selectedTownID
                let isActive = region.townID == activeTownID
                drawClayLayer(
                    in: &context,
                    cells: region.cells,
                    layout: world.layout,
                    projection: projection,
                    color: region.ownerFaction.mapColor.opacity(isSelected ? 0.34 : (isActive ? 0.28 : 0.18)),
                    expansion: 0.3,
                    yOffset: -2,
                    shadow: isSelected || isActive ? (0.24, isSelected ? 7 : 5, 2) : nil
                )
            }
        }
        .allowsHitTesting(false)
    }
}

private func drawClayLayer(
    in context: inout GraphicsContext,
    cells: [MapCell],
    layout: MapLayout,
    projection: WorldMapProjection,
    color: Color,
    expansion: CGFloat,
    yOffset: CGFloat,
    shadow: (opacity: Double, radius: CGFloat, y: CGFloat)? = nil,
    mergeCells: Bool = false
) {
    guard cells.isEmpty == false else { return }
    let path = clayBlobPath(
        cells: cells,
        layout: layout,
        projection: projection,
        expansion: expansion,
        yOffset: yOffset,
        mergeCells: mergeCells
    )
    context.drawLayer { layer in
        if let shadow {
            layer.addFilter(.shadow(color: .black.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.y))
        }
        layer.addFilter(.alphaThreshold(min: 0.44, color: color))
        layer.addFilter(.blur(radius: 4))
        layer.fill(path, with: .color(.white))
    }
}

private func clayBlobPath(
    cells: [MapCell],
    layout: MapLayout,
    projection: WorldMapProjection,
    expansion: CGFloat,
    yOffset: CGFloat,
    mergeCells: Bool
) -> Path {
    var path = Path()
    let groups = mergeCells ? [cells] : connectedGroups(in: cells)
    for group in groups {
        let bounds = group
            .map { projection.rect(for: $0, layout: layout) }
            .reduce(CGRect.null) { $0.union($1) }
            .insetBy(dx: -expansion, dy: -expansion)
            .offsetBy(dx: 0, dy: yOffset)
        let phase = Double(group.reduce(0) { $0 + $1.column * 17 + $1.row * 31 } % 100) * .pi / 50
        path.addPath(organicBlob(in: bounds, phase: phase))
    }
    return path
}

private func connectedGroups(in cells: [MapCell]) -> [[MapCell]] {
    var remaining = Set(cells)
    var groups: [[MapCell]] = []

    while let first = remaining.popFirst() {
        var group = [first]
        var frontier = [first]
        while let cell = frontier.popLast() {
            let neighbors = [
                MapCell(column: cell.column - 1, row: cell.row),
                MapCell(column: cell.column + 1, row: cell.row),
                MapCell(column: cell.column, row: cell.row - 1),
                MapCell(column: cell.column, row: cell.row + 1)
            ]
            for neighbor in neighbors where remaining.remove(neighbor) != nil {
                group.append(neighbor)
                frontier.append(neighbor)
            }
        }
        groups.append(group)
    }
    return groups
}

private func organicBlob(in rect: CGRect, phase: Double) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let points = (0..<12).map { index in
        let angle = Double(index) * .pi * 2 / 12
        let wobble = 0.93 + 0.07 * sin(angle * 3 + phase)
        return CGPoint(
            x: center.x + rect.width * 0.5 * wobble * cos(angle),
            y: center.y + rect.height * 0.5 * wobble * sin(angle)
        )
    }

    var path = Path()
    let start = midpoint(points.last!, points[0])
    path.move(to: start)
    for index in points.indices {
        path.addQuadCurve(
            to: midpoint(points[index], points[(index + 1) % points.count]),
            control: points[index]
        )
    }
    path.closeSubpath()
    return path
}

private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
    CGPoint(x: (lhs.x + rhs.x) * 0.5, y: (lhs.y + rhs.y) * 0.5)
}
