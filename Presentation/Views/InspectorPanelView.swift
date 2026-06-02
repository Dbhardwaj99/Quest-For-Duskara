import SwiftUI

struct InspectorPanelView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        HStack(spacing: 12) {
            if let kind = viewModel.placementBuildingKind {
                placementStatus(for: kind)
            } else if let coordinate = viewModel.selectedCoordinate,
                      viewModel.activeTown.buildings.contains(where: { $0.coordinate == coordinate }) == false {
                emptyPlotStatus(coordinate)
            } else {
                defaultStatus
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 15, bottomLeading: 20, bottomTrailing: 15, topTrailing: 20)))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 15, bottomLeading: 20, bottomTrailing: 15, topTrailing: 20))
                .stroke(DuskaraTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 16, y: 8)
    }

    private func placementStatus(for kind: BuildingKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(DuskaraTheme.warmGold)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Placing \(kind.title)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.96))
                Text("Suitable plots glow warmly. Blocked ground dims into the terrain.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button("Cancel", action: viewModel.cancelPlacement)
                .buttonStyle(DuskaraButtonStyle())
                .frame(width: 96)
        }
    }

    private func emptyPlotStatus(_ coordinate: GridCoordinate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.84))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Open Plot")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.96))
                Text("Plot \(coordinate.x + 1), \(coordinate.y + 1) is ready for construction.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 8)
            Button("Build") { viewModel.isBuildMenuPresented = true }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
                .frame(width: 96)
        }
    }

    private var defaultStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.12), in: Circle())
            Text("Tap a building for details, or open Build to place a new structure.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
    }
}
