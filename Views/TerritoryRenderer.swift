import SwiftUI

struct TerritoryRenderer: View {
    let world: WorldMapState
    let gridSize: GridSize
    let theme: WorldTheme
    let contrast: Double
    let travelProgress: Double
    let travelDuration: Double
    var isActive = true
    let territory: TerritoryState
    let towns: [Town]
    let nodes: [WorldTownNode]
    let connections: [TownConnection]
    let activeTownID: UUID
    let selectedTownID: UUID?
    /// Counter-scale for markers/landmarks so they stay readable instead of
    /// ballooning while the terrain zooms.
    var markerScale: CGFloat = 1
    let onSelectTown: (UUID) -> Void
    let canActOnTown: (UUID) -> Bool
    let onActOnTown: (UUID) -> Void
    /// The number on each shield: effective defense for islands you could
    /// attack — what an attack actually has to beat — and garrison for yours.
    var badgeValue: (Town) -> Int = \.armyStrength
    /// A line under a selected target's button comparing your armies.
    var attackNote: (UUID) -> String? = { _ in nil }
    var canRally: (UUID) -> Bool = { _ in false }
    var onRally: (UUID) -> Void = { _ in }

    var townByID: [UUID: Town] {
        Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0) })
    }

    // Every sea lane, tagged with whether it is a live trade route (player
    // pier town <-> neutral free city) and whether a ship sails it.
    var seaRoutes: [SeaRoute] {
        let byID = townByID
        let nodeByTown = Dictionary(uniqueKeysWithValues: nodes.map { ($0.townID, MapPoint(x: $0.x, y: $0.y)) })
        return connections.compactMap { connection in
            guard let from = nodeByTown[connection.from],
                  let to = nodeByTown[connection.to],
                  let townA = byID[connection.from],
                  let townB = byID[connection.to] else { return nil }
            let isTrade = GameRules.isTradeLane(townA, townB) || GameRules.isTradeLane(townB, townA)
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

    var body: some View {
        GeometryReader { proxy in
            let active = nodes.first { $0.townID == activeTownID }
            let camera = WorldMapCamera(size: proxy.size, aspectRatio: world.layout.aspectRatio,
                                        activePoint: SIMD2(Float(active?.x ?? 0.5), Float(active?.y ?? 0.5)),
                                        travelProgress: travelProgress)
            let labelCamera = WorldMapCamera(size: camera.size, aspectRatio: camera.aspectRatio,
                                             activePoint: camera.activePoint)
            let projection = WorldMapProjection(size: proxy.size, camera: labelCamera)
            ZStack {
                World3DMapView(towns: towns, nodes: nodes, routes: seaRoutes, gridSize: gridSize,
                               camera: camera, theme: theme, contrast: contrast, travelDuration: travelDuration, isActive: isActive)
                    .allowsHitTesting(false)
                if isActive {
                    ZStack {
                        laneLayer(projection: projection)
                        SeaTrafficLayer(routes: seaRoutes, camera: labelCamera, showsShips: false)
                        townMarkerLayer(projection: projection)
                    }
                    .opacity(travelProgress)
                    .animation(.easeInOut(duration: 0.14).delay(travelProgress > 0 ? travelDuration : 0), value: travelProgress)
                }
            }
        }
    }

    // Faint curved sea lanes between neighboring islands. Purely decorative:
    // any city can be attacked, but the lanes hint at the archipelago's
    // shape. Trade routes are drawn (animated) by SeaTrafficLayer instead.
    func laneLayer(projection: WorldMapProjection) -> some View {
        Canvas { context, size in
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

    func landmarkLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(world.landmarks) { landmark in
                WorldLandmarkView(landmark: landmark)
                    .scaleEffect(markerScale)
                    .position(projection.point(for: landmark.position))
            }
        }
    }

    func townMarkerLayer(projection: WorldMapProjection) -> some View {
        ZStack {
            ForEach(nodes) { node in
                if let town = townByID[node.townID] {
                    let isSelected = node.townID == selectedTownID
                    let center = projection.point(for: MapPoint(x: node.x, y: node.y))
                    Color.clear
                        .frame(width: 92, height: 72)
                        .contentShape(Ellipse())
                        .position(center)
                        .onTapGesture { onSelectTown(node.townID) }
                    WorldTownMarkerView(
                        town: town,
                        badge: badgeValue(town),
                        isActive: node.townID == activeTownID,
                        isSelected: isSelected,
                        showsGlyph: false,
                        canAct: canActOnTown(node.townID),
                        onAction: { onActOnTown(node.townID) },
                        note: isSelected ? attackNote(node.townID) : nil,
                        onRally: isSelected && canRally(node.townID) ? { onRally(node.townID) } : nil
                    )
                    .scaleEffect(markerScale)
                    .position(x: center.x, y: center.y + 34)
                    .onTapGesture { onSelectTown(node.townID) }
                    .zIndex(node.townID == selectedTownID ? 3 : 2)
                }
            }
        }
    }

}
