import SwiftUI

struct BuildingDetailsSheetView: View {
    @Bindable var viewModel: GameViewModel
    let buildingID: UUID
    @State private var isConfirmingDemolish = false

    private var building: BuildingInstance? {
        viewModel.activeTown.buildings.first { $0.id == buildingID }
    }

    private func demolishMessage(for building: BuildingInstance) -> String {
        guard let definition = viewModel.definition(for: building.kind) else { return "" }
        let refund = "\((definition.cost(for: 1)[.gold] ?? 0) / 2) gold comes back."
        let residents = (1...max(1, building.level)).reduce(0) { $0 + definition.peopleOnBuild(for: $1) }
        return residents > 0 ? "\(refund) Its \(residents) residents leave with it." : refund
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let building, let definition = viewModel.definition(for: building.kind) {
                    VStack(alignment: .leading, spacing: DuskaraTheme.spacingXL) {
                        HStack(alignment: .center, spacing: 14) {
                            BuildingArtView(building: building)
                                .frame(width: 86, height: 86)
                                .background(building.kind.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(building.kind.title)
                                    .font(DuskaraTheme.Fonts.title)
                                    .foregroundStyle(DuskaraTheme.ink)
                                HStack(spacing: 2) {
                                    ForEach(0..<definition.maxLevel, id: \.self) { index in
                                        Image(systemName: index < building.level ? "star.fill" : "star")
                                            .foregroundStyle(index < building.level ? DuskaraTheme.warmGold : DuskaraTheme.mutedInk)
                                    }
                                }
                                Text(definition.summary)
                                    .font(DuskaraTheme.Fonts.body)
                                    .foregroundStyle(DuskaraTheme.mutedInk)
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
                                .font(DuskaraTheme.Fonts.subheading)
                                .foregroundStyle(.green)
                        }

                        if building.kind == .barracks {
                            BarracksTrainingSheetSection(viewModel: viewModel)
                        }

                        if building.kind == .pier {
                            MarketView(viewModel: viewModel)
                                .padding(12)
                                .background(DuskaraTheme.card, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
                        }

                        Button(role: .destructive) {
                            isConfirmingDemolish = true
                        } label: {
                            Label("Demolish", systemImage: "hammer.circle")
                                .font(DuskaraTheme.Fonts.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                        .confirmationDialog("Demolish this \(building.kind.title)?", isPresented: $isConfirmingDemolish) {
                            Button("Demolish", role: .destructive, action: viewModel.demolishSelectedBuilding)
                        } message: {
                            Text(demolishMessage(for: building))
                        }
                    }
                    .padding(16)
                }
            }
            .background(DuskaraTheme.sheetBackground)
            .navigationTitle("Building")
        }
        .overlay(alignment: .topTrailing) {
            Button {
                viewModel.buildingPresentation = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close building details")
            .padding(.top, 4)
            .padding(.trailing, 10)
        }
    }
}

private struct BarracksTrainingSheetSection: View {
    @Bindable var viewModel: GameViewModel

    private let readyGreen = Color(red: 0.56, green: 0.84, blue: 0.44)
    private let blockedRed = Color(red: 0.96, green: 0.52, blue: 0.44)

    var body: some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingL) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Text("Current Soldiers: \(viewModel.activeTown.armyStrength)")
                    .font(DuskaraTheme.Fonts.body.monospacedDigit())
                    .foregroundStyle(DuskaraTheme.mutedInk)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Available Resources")
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.mutedInk)
                FlowLayout(spacing: 6) {
                    ForEach([ResourceKind.gold, .skill, .food], id: \.self) { kind in
                        ResourcePill(kind: kind, amount: viewModel.spendingTown.resources[kind])
                    }
                }
            }

            ForEach(SoldierKind.allCases) { soldier in
                if let definition = viewModel.definition(for: soldier) {
                    if soldier != SoldierKind.allCases.first {
                        Divider().overlay(DuskaraTheme.glassStroke)
                    }
                    trainingGroup(soldier, definition: definition)
                }
            }
        }
        .padding(DuskaraTheme.spacingM)
        .background(DuskaraTheme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // One soldier reads as one block: name + status up top, stats, then
    // cost — so "Ready to train" can never look attached to the next unit.
    private func trainingGroup(_ soldier: SoldierKind, definition: SoldierDefinition) -> some View {
        let unavailableReason = viewModel.trainingUnavailableReason(for: soldier)
        return VStack(alignment: .leading, spacing: DuskaraTheme.spacingS) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: soldier == .archer ? "arrow.up.right" : "shield.fill")
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
                    .background(DuskaraTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(soldier.title)
                            .font(DuskaraTheme.Fonts.subheading)
                            .foregroundStyle(DuskaraTheme.ink)
                        Text(unavailableReason == nil ? "Ready to train" : "Unavailable")
                            .font(DuskaraTheme.Fonts.label)
                            .foregroundStyle(unavailableReason == nil ? readyGreen : blockedRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((unavailableReason == nil ? readyGreen : blockedRed).opacity(0.14), in: Capsule())
                    }
                    Text("+\(definition.power) power · \(definition.peopleRequired) people · \(definition.dailyFoodUpkeep) food/day")
                        .font(DuskaraTheme.Fonts.caption)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                    if let unavailableReason {
                        Text(unavailableReason)
                            .font(DuskaraTheme.Fonts.caption)
                            .foregroundStyle(blockedRed)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Button("Train") { viewModel.train(soldier) }
                    .buttonStyle(DuskaraButtonStyle(prominent: true))
                    .frame(width: 92)
                    .disabled(unavailableReason != nil)
                    .opacity(unavailableReason == nil ? 1 : 0.55)
            }
            ResourceCostRow(title: "Training Cost", values: definition.trainingCost)
        }
    }
}
