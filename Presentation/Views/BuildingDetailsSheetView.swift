import SwiftUI

struct BuildingDetailsSheetView: View {
    @Bindable var viewModel: GameViewModel
    let buildingID: UUID

    private var building: BuildingInstance? {
        viewModel.activeTown.buildings.first { $0.id == buildingID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let building, let definition = viewModel.definition(for: building.kind) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .center, spacing: 14) {
                            BuildingArtView(building: building)
                                .frame(width: 86, height: 86)
                                .background(building.kind.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(building.kind.title)
                                    .font(.title2.weight(.black))
                                HStack(spacing: 2) {
                                    ForEach(0..<definition.maxLevel, id: \.self) { index in
                                        Image(systemName: index < building.level ? "star.fill" : "star")
                                            .foregroundStyle(index < building.level ? .yellow : .secondary)
                                    }
                                }
                                Text(definition.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        ResourceCostRow(title: "Daily Production", values: viewModel.buildingIncome(building))

                        if building.level < definition.maxLevel {
                            ResourceCostRow(title: "Upgrade Cost", values: viewModel.upgradeCost(building))
                            Button(action: viewModel.upgradeSelectedBuilding) {
                                Label("Upgrade to Level \(building.level + 1)", systemImage: "arrow.up.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .disabled(!viewModel.canUpgrade(building))
                            .opacity(viewModel.canUpgrade(building) ? 1 : 0.55)
                        } else {
                            Label("Fully upgraded", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.green)
                        }

                        if building.kind == .barracks {
                            BarracksTrainingSheetSection(viewModel: viewModel)
                        }
                    }
                    .padding(16)
                }
            }
            .background(DuskaraTheme.panel.opacity(0.30))
            .navigationTitle("Building")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.buildingPresentation = nil }
                }
            }
        }
    }
}

private struct BarracksTrainingSheetSection: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training")
                .font(.headline.weight(.heavy))
            Text("Current Soldiers: \(viewModel.activeTown.armyStrength)")
                .font(.subheadline.weight(.bold))
            VStack(alignment: .leading, spacing: 6) {
                Text("Available Resources")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach([ResourceKind.gold, .wood, .coal, .tech, .food], id: \.self) { kind in
                        ResourcePill(kind: kind, amount: viewModel.activeTown.resources[kind])
                    }
                }
            }
            ForEach(SoldierKind.allCases) { soldier in
                if let definition = viewModel.definition(for: soldier) {
                    let unavailableReason = viewModel.trainingUnavailableReason(for: soldier)
                    HStack(spacing: 12) {
                        Image(systemName: soldier == .archer ? "arrow.up.right" : "shield.fill")
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                            .background(DuskaraTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(soldier.title)
                                .font(.subheadline.weight(.bold))
                            Text("+\(definition.power) power · \(definition.peopleRequired) people · \(definition.dailyFoodUpkeep) food/day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Train") { viewModel.train(soldier) }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .frame(width: 92)
                            .disabled(unavailableReason != nil)
                            .opacity(unavailableReason == nil ? 1 : 0.55)
                    }
                    ResourceCostRow(title: "Training Cost", values: definition.trainingCost)
                    Text(unavailableReason ?? "Ready to train")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(unavailableReason == nil ? .green : .red)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 8))
    }

}
