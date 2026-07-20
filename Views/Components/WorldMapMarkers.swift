import SwiftUI

struct WorldTownMarkerView: View {
    let town: Town
    let isActive: Bool
    let isSelected: Bool
    let canAct: Bool
    let onAction: () -> Void

    @State var isHovered = false

    var body: some View {
        VStack(spacing: 3) {
            ClayTownGlyph(
                color: town.faction.mapColor,
                isActive: isActive,
                isDuskara: town.isDuskara
            )
            Text(town.name)
                .font(isSelected ? DuskaraTheme.Fonts.caption : DuskaraTheme.Fonts.label)
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.88))
                .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(width: 72)
            infoBadge
            if isSelected {
                Button(town.isPlayerControlled ? "Visit" : "Attack", action: onAction)
                    .buttonStyle(.plain)
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DuskaraTheme.accent, in: Capsule())
                    .disabled(!canAct)
                    .opacity(canAct ? 1 : 0.45)
            }
        }
        .padding(5)
        .background(isSelected ? DuskaraTheme.hudFill.opacity(0.82) : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.white.opacity(isSelected ? 0.28 : 0), lineWidth: 1)
        )
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

    var infoBadge: some View {
        Label("\(town.armyStrength)", systemImage: town.isDuskara ? "crown.fill" : "shield.fill")
        .labelStyle(.titleAndIcon)
        .font(DuskaraTheme.Fonts.label)
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.black.opacity(0.45), in: Capsule())
    }
}

private struct ClayTownGlyph: View {
    let color: Color
    let isActive: Bool
    let isDuskara: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            if isActive {
                PulsingRing(color: color)
                    .offset(y: -1)
            }

            Ellipse()
                .fill(.black.opacity(0.30))
                .frame(width: 42, height: 15)
                .blur(radius: 3)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [color, color.opacity(0.66)], startPoint: .top, endPoint: .bottom))
                .frame(width: 42, height: 29)
                .rotation3DEffect(.degrees(58), axis: (x: 1, y: 0, z: 0))
                .shadow(color: .black.opacity(0.34), radius: 4, y: 4)
                .offset(y: -3)

            HStack(alignment: .bottom, spacing: 2) {
                clayBuilding(height: 13)
                clayBuilding(height: isDuskara ? 25 : 20)
                clayBuilding(height: 15)
            }
            .offset(y: -8)
        }
        .frame(width: 52, height: 42)
    }

    private func clayBuilding(height: CGFloat) -> some View {
        VStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 11, height: 4)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(red: 0.92, green: 0.84, blue: 0.69))
                .frame(width: 9, height: height)
        }
        .shadow(color: .black.opacity(0.30), radius: 2, x: 1, y: 2)
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
            .frame(width: 38, height: 38)
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
