import SwiftUI

struct WorldTerrainLayer: View {
    let world: WorldMapState

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            let landTiles = world.terrainTiles.filter { $0.terrain != .water }

            var shelf = Path()
            var silhouette = Path()
            for tile in landTiles {
                let rect = projection.rect(for: tile.cell, layout: world.layout)
                shelf.addRect(rect.insetBy(dx: -3.4, dy: -3.4))
                silhouette.addRect(rect.insetBy(dx: -1.1, dy: -1.1))
            }

            // Pale turquoise shallows fuse each island group into one shape.
            context.fill(shelf, with: .color(Color(red: 0.42, green: 0.71, blue: 0.73).opacity(0.55)))

            context.drawLayer { layer in
                layer.addFilter(.shadow(color: .black.opacity(0.28), radius: 5, x: 0, y: 3))
                layer.fill(silhouette, with: .color(Color(red: 0.93, green: 0.83, blue: 0.58)))
            }

            for tile in landTiles {
                let rect = projection.rect(for: tile.cell, layout: world.layout).insetBy(dx: -0.4, dy: -0.4)
                context.fill(Path(rect), with: .color(tile.terrain.mapColor))
            }
        }
    }
}

struct TerritoryRegionLayer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let selectedTownID: UUID?
    let activeTownID: UUID

    var regionByTownID: [UUID: TerritoryRegion] {
        Dictionary(uniqueKeysWithValues: territory.regions.map { ($0.townID, $0) })
    }

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            drawTerritoryCells(in: &context, projection: projection)
            drawBorders(in: &context, projection: projection)
        }
    }

    func drawTerritoryCells(in context: inout GraphicsContext, projection: WorldMapProjection) {
        for region in territory.regions {
            let opacity: Double
            if region.townID == selectedTownID {
                opacity = 0.48
            } else if region.townID == activeTownID {
                opacity = 0.42
            } else {
                opacity = 0.29
            }

            // One merged path per region: a continuous tint instead of a
            // grid of gapped squares.
            var regionPath = Path()
            for cell in region.cells {
                regionPath.addRect(projection.rect(for: cell, layout: world.layout))
            }
            context.fill(regionPath, with: .color(region.ownerFaction.mapColor.opacity(opacity)))
        }
    }

    func drawBorders(in context: inout GraphicsContext, projection: WorldMapProjection) {
        let ownerByCell = makeOwnerByCell()

        // Water cells belong to no region, so every land cell checks all four
        // neighbors: shorelines stroke against unowned sea.
        for region in territory.regions {
            for cell in region.cells {
                let neighbors: [(MapCell, TerritoryBorderEdge)] = [
                    (MapCell(column: cell.column + 1, row: cell.row), .right),
                    (MapCell(column: cell.column - 1, row: cell.row), .left),
                    (MapCell(column: cell.column, row: cell.row + 1), .bottom),
                    (MapCell(column: cell.column, row: cell.row - 1), .top)
                ]
                for (neighborCell, edge) in neighbors {
                    drawBorderIfNeeded(
                        from: cell,
                        to: neighborCell,
                        edge: edge,
                        region: region,
                        ownerByCell: ownerByCell,
                        context: &context,
                        projection: projection
                    )
                }
            }
        }
    }

    func drawBorderIfNeeded(
        from cell: MapCell,
        to neighborCell: MapCell,
        edge: TerritoryBorderEdge,
        region: TerritoryRegion,
        ownerByCell: [MapCell: UUID],
        context: inout GraphicsContext,
        projection: WorldMapProjection
    ) {
        guard world.layout.contains(neighborCell), let neighborTownID = ownerByCell[neighborCell] else {
            // Shoreline: land meeting open sea takes the owner's color.
            stroke(edge: edge, of: cell, region: region, neighbor: nil, context: &context, projection: projection)
            return
        }
        guard neighborTownID != region.townID else { return }
        stroke(edge: edge, of: cell, region: region, neighbor: regionByTownID[neighborTownID], context: &context, projection: projection)
    }

    func stroke(
        edge: TerritoryBorderEdge,
        of cell: MapCell,
        region: TerritoryRegion,
        neighbor: TerritoryRegion?,
        context: inout GraphicsContext,
        projection: WorldMapProjection
    ) {
        let isEmpireBorder = neighbor?.ownerFaction != region.ownerFaction
        let path = projection.path(for: edge, of: cell, layout: world.layout)
        let color = isEmpireBorder ? region.ownerFaction.mapColor.opacity(0.95) : .white.opacity(0.14)
        let lineWidth = isEmpireBorder ? 2.0 : 0.7
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    func makeOwnerByCell() -> [MapCell: UUID] {
        var ownerByCell: [MapCell: UUID] = [:]
        for region in territory.regions {
            for cell in region.cells {
                ownerByCell[cell] = region.townID
            }
        }
        return ownerByCell
    }
}

enum TerritoryBorderEdge {
    case left
    case right
    case top
    case bottom
}

