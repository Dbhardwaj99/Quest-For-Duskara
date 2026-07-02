import SwiftUI

struct TerritoryRenderer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let towns: [Town]
    let nodes: [WorldTownNode]
    let connections: [TownConnection]
    let activeTownID: UUID
    let selectedTownID: UUID?
    let onSelectTown: (UUID) -> Void

    private var townByID: [UUID: Town] {
        Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0) })
    }

    var body: some View {
        GeometryReader { proxy in
            let projection = WorldMapProjection(size: proxy.size)

            ZStack {
                WorldTerrainLayer(world: world)
                TerritoryRegionLayer(
                    world: world,
                    territory: territory,
                    selectedTownID: selectedTownID,
                    activeTownID: activeTownID
                )
                connectionLayer(projection: projection)
                landmarkLayer(projection: projection)
                townMarkerLayer(projection: projection)
                mapLegend
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.13, blue: 0.15),
                    Color(red: 0.13, green: 0.18, blue: 0.17),
                    Color(red: 0.18, green: 0.15, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    // Faint sea lanes between neighboring islands. Purely decorative: any
    // city can be attacked, but the lanes hint at the archipelago's shape.
    private func connectionLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(connections) { connection in
                Path { path in
                    path.move(to: projection.point(for: connection.from, nodes: nodes))
                    path.addLine(to: projection.point(for: connection.to, nodes: nodes))
                }
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [4, 8]))
            }
        }
    }

    private func landmarkLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(world.landmarks) { landmark in
                WorldLandmarkView(landmark: landmark)
                    .position(projection.point(for: landmark.position))
            }
        }
    }

    private func townMarkerLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(nodes) { node in
                if let town = townByID[node.townID] {
                    WorldTownMarkerView(
                        town: town,
                        isActive: node.townID == activeTownID,
                        isSelected: node.townID == selectedTownID
                    )
                    .position(projection.point(for: MapPoint(x: node.x, y: node.y)))
                    .onTapGesture { onSelectTown(node.townID) }
                    .zIndex(node.townID == selectedTownID ? 3 : 2)
                }
            }
        }
    }

    private var mapLegend: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Territories")
                .font(.caption2.weight(.black))
                .foregroundStyle(.white.opacity(0.88))
            HStack(spacing: 7) {
                LegendSwatch(color: TownFaction.player.mapColor, title: "You")
                LegendSwatch(color: TownFaction.neutral.mapColor, title: "Neutral")
                LegendSwatch(color: TownFaction.enemy.mapColor, title: "Enemy")
                LegendSwatch(color: TownFaction.duskara.mapColor, title: "Duskara")
            }
        }
        .padding(9)
        .background(.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

private struct WorldTerrainLayer: View {
    let world: WorldMapState

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            for tile in world.terrainTiles {
                let rect = projection.rect(for: tile.cell, layout: world.layout).insetBy(dx: -0.4, dy: -0.4)
                context.fill(Path(rect), with: .color(tile.terrain.mapColor))
            }
        }
        .overlay(
            LinearGradient(
                colors: [.white.opacity(0.10), .clear, .black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct TerritoryRegionLayer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let selectedTownID: UUID?
    let activeTownID: UUID

    private var regionByTownID: [UUID: TerritoryRegion] {
        Dictionary(uniqueKeysWithValues: territory.regions.map { ($0.townID, $0) })
    }

    var body: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            drawTerritoryCells(in: &context, projection: projection)
            drawBorders(in: &context, projection: projection)
        }
    }

    private func drawTerritoryCells(in context: inout GraphicsContext, projection: WorldMapProjection) {
        for region in territory.regions {
            let opacity: Double
            if region.townID == selectedTownID {
                opacity = 0.48
            } else if region.townID == activeTownID {
                opacity = 0.42
            } else {
                opacity = 0.29
            }

            for cell in region.cells {
                let rect = projection.rect(for: cell, layout: world.layout).insetBy(dx: 0.45, dy: 0.45)
                context.fill(Path(rect), with: .color(region.ownerFaction.mapColor.opacity(opacity)))
            }
        }
    }

    private func drawBorders(in context: inout GraphicsContext, projection: WorldMapProjection) {
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

    private func drawBorderIfNeeded(
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

    private func stroke(
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

    private func makeOwnerByCell() -> [MapCell: UUID] {
        var ownerByCell: [MapCell: UUID] = [:]
        for region in territory.regions {
            for cell in region.cells {
                ownerByCell[cell] = region.townID
            }
        }
        return ownerByCell
    }
}

private enum TerritoryBorderEdge {
    case left
    case right
    case top
    case bottom
}

private struct WorldTownMarkerView: View {
    let town: Town
    let isActive: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(town.faction.mapColor.gradient)
                    .frame(width: nodeSize, height: nodeSize)
                    .shadow(color: town.faction.mapColor.opacity(0.55), radius: isSelected ? 8 : 3)
                Circle()
                    .stroke(.white.opacity(isSelected ? 0.95 : 0.45), lineWidth: isSelected ? 2.2 : 1)
                    .frame(width: nodeSize + 5, height: nodeSize + 5)
                Image(systemName: nodeIcon)
                    .font(.system(size: isActive ? 12 : 10, weight: .black))
                    .foregroundStyle(.white)
            }
            Text(town.name)
                .font(.system(size: isSelected ? 8.5 : 7.5, weight: .heavy, design: .serif))
                .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.82))
                .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 58)
        }
        .padding(4)
        .background(isSelected ? .black.opacity(0.30) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var nodeIcon: String {
        if town.isPlayerControlled { return "house.fill" }
        if town.isDuskara { return "crown.fill" }
        if town.faction == .enemy { return "shield.fill" }
        return "circle.hexagonpath.fill"
    }

    private var nodeSize: CGFloat {
        if isActive { return 27 }
        if town.isDuskara { return 29 }
        return isSelected ? 25 : 20
    }
}

private struct WorldLandmarkView: View {
    let landmark: WorldLandmark

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.86))
                .padding(5)
                .background(.black.opacity(0.24), in: Circle())
            Text(landmark.name)
                .font(.system(size: 6.5, weight: .bold, design: .serif))
                .foregroundStyle(.white.opacity(0.60))
                .lineLimit(1)
                .frame(width: 56)
        }
        .allowsHitTesting(false)
    }

    private var icon: String {
        switch landmark.kind {
        case .ancientRuin: return "building.columns.fill"
        case .forestShrine: return "leaf.fill"
        case .mountainGate: return "mountain.2.fill"
        case .coastalHarbor: return "sailboat.fill"
        case .desertObelisk: return "triangle.fill"
        }
    }
}

private struct LegendSwatch: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))
        }
    }
}

private struct WorldMapProjection {
    var size: CGSize

    func point(for point: MapPoint) -> CGPoint {
        CGPoint(x: size.width * point.x, y: size.height * point.y)
    }

    func point(for townID: UUID, nodes: [WorldTownNode]) -> CGPoint {
        guard let node = nodes.first(where: { $0.townID == townID }) else { return .zero }
        return point(for: MapPoint(x: node.x, y: node.y))
    }

    func rect(for cell: MapCell, layout: MapLayout) -> CGRect {
        CGRect(
            x: size.width * Double(cell.column) * layout.cellWidth,
            y: size.height * Double(cell.row) * layout.cellHeight,
            width: size.width * layout.cellWidth,
            height: size.height * layout.cellHeight
        )
    }

    func path(for edge: TerritoryBorderEdge, of cell: MapCell, layout: MapLayout) -> Path {
        let rect = rect(for: cell, layout: layout)
        return Path { path in
            switch edge {
            case .left:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            case .right:
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            case .top:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            case .bottom:
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
        }
    }
}

private extension TerrainKind {
    var mapColor: Color {
        switch self {
        case .plains: return Color(red: 0.43, green: 0.53, blue: 0.30)
        case .forest: return Color(red: 0.19, green: 0.37, blue: 0.22)
        case .mountains: return Color(red: 0.47, green: 0.48, blue: 0.45)
        case .desert: return Color(red: 0.70, green: 0.55, blue: 0.31)
        case .coast: return Color(red: 0.72, green: 0.64, blue: 0.44)
        case .water: return Color(red: 0.13, green: 0.27, blue: 0.40)
        }
    }
}

private extension TownFaction {
    var mapColor: Color {
        switch self {
        case .player: return Color(red: 0.28, green: 0.72, blue: 0.38)
        case .neutral: return Color(red: 0.74, green: 0.67, blue: 0.50)
        case .enemy: return Color(red: 0.76, green: 0.20, blue: 0.18)
        case .duskara: return Color(red: 0.32, green: 0.25, blue: 0.56)
        }
    }
}
