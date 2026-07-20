import SwiftUI

struct TerritoryRenderer: View {
    let world: WorldMapState
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
            let isTrade = SeaRoute.isTradeRoute(townA, townB) || SeaRoute.isTradeRoute(townB, townA)
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
            let projection = WorldMapProjection(size: proxy.size)

            ZStack {
                WorldTerrainLayer(world: world, nodes: nodes)
                TerritoryRegionLayer(
                    world: world,
                    territory: territory,
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
    var laneLayer: some View {
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
                    WorldTownMarkerView(
                        town: town,
                        isActive: node.townID == activeTownID,
                        isSelected: node.townID == selectedTownID,
                        canAct: canActOnTown(node.townID),
                        onAction: { onActOnTown(node.townID) }
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
