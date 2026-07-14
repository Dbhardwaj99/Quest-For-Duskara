import SwiftUI

/// Presentation-only reading of an island's owner from the local player's
/// perspective. Never part of game state: rules only compare owner IDs.
enum TownRole {
    case localPlayer
    case rivalPlayer
    case ai
    case duskara

    init(town: Town, localPlayerID: String, humanPlayerIDs: [String]) {
        if town.ownerID == localPlayerID {
            self = .localPlayer
        } else if humanPlayerIDs.contains(town.ownerID) {
            self = .rivalPlayer
        } else if town.isDuskara {
            self = .duskara
        } else {
            self = .ai
        }
    }
}

struct TerritoryRenderer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let towns: [Town]
    let localPlayerID: String
    let humanPlayerIDs: [String]
    let nodes: [WorldTownNode]
    let connections: [TownConnection]
    let activeTownID: UUID
    let selectedTownID: UUID?
    /// Counter-scale for markers/landmarks so they stay readable instead of
    /// ballooning while the terrain zooms.
    var markerScale: CGFloat = 1
    let onSelectTown: (UUID) -> Void

    private var townByID: [UUID: Town] {
        Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0) })
    }

    private func role(of town: Town) -> TownRole {
        TownRole(town: town, localPlayerID: localPlayerID, humanPlayerIDs: humanPlayerIDs)
    }

    private var roleByTownID: [UUID: TownRole] {
        Dictionary(uniqueKeysWithValues: towns.map { ($0.id, role(of: $0)) })
    }

    // Every sea lane, tagged with whether it is a live trade route (local
    // pier town <-> AI-ruled free city) and whether a ship sails it.
    private var seaRoutes: [SeaRoute] {
        let byID = townByID
        let nodeByTown = Dictionary(uniqueKeysWithValues: nodes.map { ($0.townID, MapPoint(x: $0.x, y: $0.y)) })
        return connections.compactMap { connection in
            guard let from = nodeByTown[connection.from],
                  let to = nodeByTown[connection.to],
                  let townA = byID[connection.from],
                  let townB = byID[connection.to] else { return nil }
            let isTrade = isTradeRoute(townA, townB) || isTradeRoute(townB, townA)
            let seed = SeaRoute.stableHash(connection.id)
            return SeaRoute(
                id: connection.id,
                from: from,
                to: to,
                isTrade: isTrade,
                hasShip: isTrade || seed % 3 == 0,
                seed: seed
            )
        }
    }

    private func isTradeRoute(_ pierTown: Town, _ partner: Town) -> Bool {
        pierTown.isOwned(by: localPlayerID)
            && pierTown.buildings.contains { $0.kind == .pier }
            && humanPlayerIDs.contains(partner.ownerID) == false
    }

    var body: some View {
        GeometryReader { proxy in
            let projection = WorldMapProjection(size: proxy.size)

            ZStack {
                WorldTerrainLayer(world: world)
                TerritoryRegionLayer(
                    world: world,
                    territory: territory,
                    roleByTownID: roleByTownID,
                    selectedTownID: selectedTownID,
                    activeTownID: activeTownID
                )
                laneLayer
                SeaTrafficLayer(routes: seaRoutes)
                landmarkLayer(projection: projection)
                townMarkerLayer(projection: projection)
            }
        }
    }

    // Faint curved sea lanes between neighboring islands. Purely decorative:
    // any city can be attacked, but the lanes hint at the archipelago's
    // shape. Trade routes are drawn (animated) by SeaTrafficLayer instead.
    private var laneLayer: some View {
        Canvas { context, size in
            let projection = WorldMapProjection(size: size)
            for route in seaRoutes where route.isTrade == false {
                context.stroke(
                    route.path(projection: projection),
                    with: .color(.white.opacity(0.13)),
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [4, 8])
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func landmarkLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(world.landmarks) { landmark in
                WorldLandmarkView(landmark: landmark)
                    .scaleEffect(markerScale)
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
                        role: role(of: town),
                        isActive: node.townID == activeTownID,
                        isSelected: node.townID == selectedTownID
                    )
                    .scaleEffect(markerScale)
                    .position(projection.point(for: MapPoint(x: node.x, y: node.y)))
                    .onTapGesture { onSelectTown(node.townID) }
                    .zIndex(node.townID == selectedTownID ? 3 : 2)
                }
            }
        }
    }

}

// MARK: - Sea traffic

private struct SeaRoute: Identifiable {
    let id: String
    let from: MapPoint
    let to: MapPoint
    let isTrade: Bool
    let hasShip: Bool
    let seed: Int


    // Hasher's per-launch seed would reshuffle ships every run; this stays
    // stable so each lane keeps its curve, pace, and phase.
    static func stableHash(_ value: String) -> Int {
        var hash = 5381
        for scalar in value.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return abs(hash)
    }

    // Lanes bow gently to one side so crossings read as shipping arcs, not
    // a straight wire diagram.
    func controlPoint(projection: WorldMapProjection) -> CGPoint {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let side: CGFloat = seed.isMultiple(of: 2) ? 1 : -1
        let bulge = min(30, length * 0.16) * side
        return CGPoint(x: mid.x - dy / length * bulge, y: mid.y + dx / length * bulge)
    }

    func path(projection: WorldMapProjection) -> Path {
        var path = Path()
        path.move(to: projection.point(for: from))
        path.addQuadCurve(to: projection.point(for: to), control: controlPoint(projection: projection))
        return path
    }

    func point(at t: CGFloat, projection: WorldMapProjection) -> CGPoint {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let control = controlPoint(projection: projection)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    func heading(at t: CGFloat, projection: WorldMapProjection) -> CGFloat {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let control = controlPoint(projection: projection)
        let dx = 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x)
        let dy = 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
        return atan2(dy, dx)
    }
}

// Animated layer: flowing gold trade lanes, little ships shuttling between
// islands, and slow cloud shadows. One Canvas redrawn at ~24 fps; everything
// else on the map stays static.
private struct SeaTrafficLayer: View {
    let routes: [SeaRoute]

    private static let tradeGold = Color(red: 0.94, green: 0.78, blue: 0.42)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            Canvas { context, size in
                let projection = WorldMapProjection(size: size)
                let time = timeline.date.timeIntervalSinceReferenceDate

                drawCloudShadows(context: context, size: size, time: time)

                for route in routes where route.isTrade {
                    // Dashes flow along the lane so trade reads as movement
                    // even between ship crossings.
                    context.stroke(
                        route.path(projection: projection),
                        with: .color(Self.tradeGold.opacity(0.55)),
                        style: StrokeStyle(
                            lineWidth: 1.6,
                            lineCap: .round,
                            dash: [5, 7],
                            dashPhase: CGFloat(route.seed % 12) - CGFloat(time * 10)
                        )
                    )
                }

                for route in routes where route.hasShip {
                    drawShip(route: route, projection: projection, time: time, context: context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // Ships shuttle back and forth with an eased turnaround at each pier.
    private func drawShip(route: SeaRoute, projection: WorldMapProjection, time: TimeInterval, context: GraphicsContext) {
        let period = Double(16 + route.seed % 7 * 2)
        let phase = Double(route.seed % 100) / 100
        let raw = ((time / period) + phase).truncatingRemainder(dividingBy: 1)
        let outbound = raw < 0.5
        let linear = CGFloat(outbound ? raw * 2 : 2 - raw * 2)
        let t = linear * linear * (3 - 2 * linear)

        let position = route.point(at: t, projection: projection)
        var heading = route.heading(at: t, projection: projection)
        if outbound == false { heading += .pi }

        context.drawLayer { layer in
            layer.translateBy(x: position.x, y: position.y)
            layer.rotate(by: Angle(radians: heading + .pi / 2))

            var wake = Path()
            wake.move(to: CGPoint(x: -1.6, y: 5))
            wake.addLine(to: CGPoint(x: -2.8, y: 11))
            wake.move(to: CGPoint(x: 1.6, y: 5))
            wake.addLine(to: CGPoint(x: 2.8, y: 11))
            layer.stroke(wake, with: .color(.white.opacity(0.35)), lineWidth: 1)

            var hull = Path()
            hull.move(to: CGPoint(x: 0, y: -6))
            hull.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 3.6, y: -2))
            hull.addLine(to: CGPoint(x: -3, y: 4))
            hull.addQuadCurve(to: CGPoint(x: 0, y: -6), control: CGPoint(x: -3.6, y: -2))
            layer.fill(hull, with: .color(Color(red: 0.45, green: 0.32, blue: 0.23)))

            var sail = Path()
            sail.move(to: CGPoint(x: 0, y: -4.5))
            sail.addLine(to: CGPoint(x: 2.8, y: 1.5))
            sail.addLine(to: CGPoint(x: 0, y: 1.5))
            sail.closeSubpath()
            layer.fill(sail, with: .color(route.isTrade ? Self.tradeGold : .white.opacity(0.92)))
        }
    }

    // Big soft shadows sliding across the sea sell scale and motion for
    // almost nothing: three radial-gradient ellipses per frame.
    private func drawCloudShadows(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<3 {
            let speed = 0.006 + Double(index) * 0.003
            let x = ((time * speed + Double(index) * 0.37).truncatingRemainder(dividingBy: 1.3) - 0.15) * size.width
            let y = size.height * (0.18 + Double(index) * 0.28)
            let radius = size.width * (0.10 + CGFloat(index) * 0.03)
            let center = CGPoint(x: x, y: y)
            let rect = CGRect(x: center.x - radius * 1.6, y: center.y - radius, width: radius * 3.2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [.black.opacity(0.07), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius * 1.6
                )
            )
        }
    }
}

// Water cells are never painted — the shared sea shows through — so the
// terrain canvas has no visible rectangle edge. Islands get a shallow-water
// shelf, one cohesive sand silhouette with a soft drop shadow, then the
// per-cell terrain colors on top.
private struct WorldTerrainLayer: View {
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

private struct TerritoryRegionLayer: View {
    let world: WorldMapState
    let territory: TerritoryState
    let roleByTownID: [UUID: TownRole]
    let selectedTownID: UUID?
    let activeTownID: UUID

    private func color(for region: TerritoryRegion) -> Color {
        (roleByTownID[region.townID] ?? .ai).mapColor
    }

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

            // One merged path per region: a continuous tint instead of a
            // grid of gapped squares.
            var regionPath = Path()
            for cell in region.cells {
                regionPath.addRect(projection.rect(for: cell, layout: world.layout))
            }
            context.fill(regionPath, with: .color(color(for: region).opacity(opacity)))
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
        let isEmpireBorder = neighbor?.ownerID != region.ownerID
        let path = projection.path(for: edge, of: cell, layout: world.layout)
        let color = isEmpireBorder ? color(for: region).opacity(0.95) : .white.opacity(0.14)
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
    let role: TownRole
    let isActive: Bool
    let isSelected: Bool

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isActive {
                    PulsingRing(color: role.mapColor)
                }
                Circle()
                    .fill(role.mapColor.gradient)
                    .frame(width: nodeSize, height: nodeSize)
                    .shadow(color: role.mapColor.opacity(0.55), radius: isSelected ? 8 : 3)
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
            infoBadge
        }
        .padding(4)
        .background(isSelected ? .black.opacity(0.30) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .scaleEffect(isHovered ? 1.12 : 1)
        .animation(.smooth(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
        .help(helpText)
    }

    private var helpText: String {
        switch role {
        case .localPlayer: return "\(town.name) — your city. Click to inspect, Visit to rule it."
        case .rivalPlayer: return "\(town.name) — a rival player's city. Garrison of \(town.armyStrength)."
        case .duskara: return "\(town.name) — the stronghold. Defeat its \(town.armyStrength) soldiers to win."
        case .ai: return "\(town.name) — garrison of \(town.armyStrength). Click to inspect or attack."
        }
    }

    // Your own cities show their stockpile; everyone else reveals only
    // soldier count.
    private var infoBadge: some View {
        Group {
            if role == .localPlayer {
                Text("G \(town.resources[.gold]) · F \(town.resources[.food]) · S \(town.resources[.skill])")
            } else {
                Label("\(town.armyStrength)", systemImage: "shield.fill")
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.system(size: 7, weight: .heavy))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.black.opacity(0.45), in: Capsule())
    }

    private var nodeIcon: String {
        switch role {
        case .localPlayer: return "house.fill"
        case .duskara: return "crown.fill"
        case .rivalPlayer: return "shield.fill"
        case .ai: return "circle.hexagonpath.fill"
        }
    }

    private var nodeSize: CGFloat {
        if isActive { return 27 }
        if town.isDuskara { return 29 }
        return isSelected ? 25 : 20
    }
}

// Slow expanding ring under the active town so the player's "you are here"
// reads at a glance.
private struct PulsingRing: View {
    let color: Color
    @State private var expanded = false

    var body: some View {
        Circle()
            .stroke(color.opacity(expanded ? 0 : 0.75), lineWidth: 2)
            .frame(width: 30, height: 30)
            .scaleEffect(expanded ? 1.8 : 0.85)
            .onAppear {
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    expanded = true
                }
            }
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

// Same colors the 3D town uses (WorldPalette.village): tileGround plains,
// forestMoss woods, sandy skirt coasts, and open-sea water, so both views
// read as one game.
private extension TerrainKind {
    var mapColor: Color {
        switch self {
        case .plains: return Color(red: 0.47, green: 0.60, blue: 0.36)
        case .forest: return Color(red: 0.29, green: 0.47, blue: 0.34)
        case .mountains: return Color(red: 0.62, green: 0.60, blue: 0.54)
        case .desert: return Color(red: 0.85, green: 0.75, blue: 0.52)
        case .coast: return Color(red: 0.93, green: 0.83, blue: 0.58)
        // Matches the map's open-sea backdrop; water cells are not painted
        // over it, so any mismatch here would resurrect the old border seam.
        case .water: return Color(red: 0.28, green: 0.56, blue: 0.62)
        }
    }
}

// Shared with WorldMapView's legend.
extension TownRole {
    var mapColor: Color {
        switch self {
        case .localPlayer: return Color(red: 0.28, green: 0.72, blue: 0.38)
        case .ai: return Color(red: 0.74, green: 0.67, blue: 0.50)
        case .rivalPlayer: return Color(red: 0.80, green: 0.24, blue: 0.20)
        case .duskara: return Color(red: 0.44, green: 0.34, blue: 0.72)
        }
    }
}
