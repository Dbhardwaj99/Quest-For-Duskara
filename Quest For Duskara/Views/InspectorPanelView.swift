import SwiftUI

struct InspectorPanelView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let building = viewModel.selectedBuilding,
               let definition = viewModel.definition(for: building.kind) {
                buildingInspector(building, definition: definition)
            } else if let coordinate = viewModel.selectedCoordinate {
                emptyPlotInspector(coordinate)
            } else {
                Text("Tap a plot or building to inspect it.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(12)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }

    private func buildingInspector(_ building: BuildingInstance, definition: BuildingDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                BuildingArtView(building: building)
                    .frame(width: 62, height: 62)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(building.kind.title)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    Text("Level \(building.level) of \(definition.maxLevel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(definition.summary)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(2)
                }
                Spacer()
                Button(action: viewModel.upgradeSelectedBuilding) {
                    Label("Upgrade", systemImage: "arrow.up.circle.fill")
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
                .frame(width: 118)
                .disabled(!viewModel.canUpgrade(building))
                .opacity(viewModel.canUpgrade(building) ? 1 : 0.52)
            }

            HStack(alignment: .top, spacing: 12) {
                ResourceCostRow(title: "Production", values: viewModel.buildingIncome(building))
                if building.level < definition.maxLevel {
                    ResourceCostRow(title: "Upgrade Cost", values: viewModel.upgradeCost(building))
                }
            }

            if building.kind == .barracks {
                SoldierTrainingView(viewModel: viewModel)
            }
        }
    }

    private func emptyPlotInspector(_ coordinate: GridCoordinate) -> some View {
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
}

private struct SoldierTrainingView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Training")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.82))
            HStack(spacing: 10) {
                ForEach(SoldierKind.allCases) { soldier in
                    if let definition = viewModel.definition(for: soldier) {
                        Button {
                            viewModel.train(soldier)
                        } label: {
                            VStack(spacing: 4) {
                                Label(soldier.title, systemImage: soldier == .archer ? "arrow.up.right" : "shield.fill")
                                    .font(.caption.weight(.bold))
                                Text("+\(definition.power) power")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(DuskaraButtonStyle())
                    }
                }
            }
        }
    }
}
