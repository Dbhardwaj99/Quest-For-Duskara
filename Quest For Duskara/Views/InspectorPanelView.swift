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
        .padding(12)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }

    private func placementStatus(for kind: BuildingKind) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
                .font(.title3)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text("Placing \(kind.title)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text("Green plots are valid. Red plots do not satisfy cost, people, occupancy, or biome rules.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel", action: viewModel.cancelPlacement)
                .buttonStyle(DuskaraButtonStyle())
                .frame(width: 96)
        }
    }

    private func emptyPlotStatus(_ coordinate: GridCoordinate) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "square.dashed")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
            VStack(alignment: .leading, spacing: 3) {
                Text("Empty Plot")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text("Plot \(coordinate.x + 1), \(coordinate.y + 1) is ready for construction.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button("Build") { viewModel.isBuildMenuPresented = true }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
                .frame(width: 96)
        }
    }

    private var defaultStatus: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.82))
            Text("Tap a building for details, or open Build to place a new structure.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
            Spacer()
        }
    }
}
