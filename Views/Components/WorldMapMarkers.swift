import SwiftUI

struct WorldTownMarkerView: View {
    let town: Town
    let isActive: Bool
    let isSelected: Bool

    @State var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isActive {
                    PulsingRing(color: town.faction.mapColor)
                }
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
            infoBadge
        }
        .padding(4)
        .background(isSelected ? .black.opacity(0.30) : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .scaleEffect(isHovered ? 1.12 : 1)
        .animation(.smooth(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
        .help(helpText)
    }

    var helpText: String {
        if town.isPlayerControlled { return "\(town.name) — your city. Click to inspect, Visit to rule it." }
        if town.isDuskara { return "\(town.name) — the stronghold. Defeat its \(town.armyStrength) soldiers to win." }
        return "\(town.name) — garrison of \(town.armyStrength). Click to inspect or attack."
    }

    // Friendly cities show their stockpile; everyone else reveals only
    // soldier count.
    var infoBadge: some View {
        Group {
            if town.isPlayerControlled {
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

    var nodeIcon: String {
        if town.isPlayerControlled { return "house.fill" }
        if town.isDuskara { return "crown.fill" }
        if town.faction == .enemy { return "shield.fill" }
        return "circle.hexagonpath.fill"
    }

    var nodeSize: CGFloat {
        if isActive { return 27 }
        if town.isDuskara { return 29 }
        return isSelected ? 25 : 20
    }
}

// Slow expanding ring under the active town so the player's "you are here"
// reads at a glance.
struct PulsingRing: View {
    let color: Color
    @State var expanded = false

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

struct WorldLandmarkView: View {
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

    var icon: String {
        switch landmark.kind {
        case .ancientRuin: return "building.columns.fill"
        case .forestShrine: return "leaf.fill"
        case .mountainGate: return "mountain.2.fill"
        case .coastalHarbor: return "sailboat.fill"
        case .desertObelisk: return "triangle.fill"
        }
    }
}

struct WorldMapProjection {
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
extension TerrainKind {
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
extension TownFaction {
    var mapColor: Color {
        switch self {
        case .player: return Color(red: 0.28, green: 0.72, blue: 0.38)
        case .neutral: return Color(red: 0.74, green: 0.67, blue: 0.50)
        case .enemy: return Color(red: 0.80, green: 0.24, blue: 0.20)
        case .duskara: return Color(red: 0.44, green: 0.34, blue: 0.72)
        }
    }
}
