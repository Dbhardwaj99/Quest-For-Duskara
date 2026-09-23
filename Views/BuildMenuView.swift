import SwiftUI

struct BuildMenuView: View {
    @Bindable var viewModel: GameViewModel

    /// Every town is founded with a Pier and may only ever have one, so listing
    /// it offers a build that always fails on `duplicatePier`. Keyed on the town
    /// actually having one rather than on the kind, so a town that somehow lost
    /// its Pier can still rebuild it. Upgrades live in the building's own sheet.
    private var buildableKinds: [BuildingKind] {
        BuildingKind.allCases.filter { kind in
            kind != .pier || viewModel.activeTown.buildings.contains { $0.kind == .pier } == false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.buildPlot == nil
                                 ? "Choose a building, then place it on a highlighted town plot."
                                 : "Choose a building for the plot you picked.")
                                .font(DuskaraTheme.Fonts.subheading)
                                .foregroundStyle(DuskaraTheme.ink)
                            if viewModel.priceScale > 1 {
                                Text("Prices ×\(viewModel.priceScale.formatted(.number.precision(.fractionLength(0...2)))) across your \(viewModel.playerTowns.count) islands — each beyond the first adds \(Int((viewModel.balance.priceStepPerIsland * 100).rounded()))%.")
                                    .font(DuskaraTheme.Fonts.caption)
                                    .foregroundStyle(DuskaraTheme.mutedInk)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        ForEach(buildableKinds) { kind in
                            if let definition = viewModel.definition(for: kind) {
                                BuildingMenuCard(
                                    kind: kind,
                                    definition: definition,
                                    shortfall: viewModel.shortfall(for: definition.cost(for: 1)),
                                    hasWorkers: viewModel.freePeople >= definition.peopleRequired
                                ) {
                                    viewModel.chooseFromBuildMenu(kind)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .background(DuskaraTheme.sheetBackground)
            .navigationTitle("Build")
            .toolbar {
                ToolbarItem(placement: .status) {
                    BuildResourcesHeader(
                        town: viewModel.spendingTown,
                        income: viewModel.empireIncome
                    )
                }
                // .keyboard never renders on macOS; use the sheet's action slot.
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.isBuildMenuPresented = false }
                }
            }
        }
    }
}

private struct BuildResourcesHeader: View {
    let town: Town
    let income: [ResourceKind: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resources")
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ResourceKind.allCases) { kind in
                        ResourcePill(kind: kind, amount: town.resources[kind], income: income[kind])
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, DuskaraTheme.spacingL)
        .padding(.vertical, 10)
    }
}

private struct BuildingMenuCard: View {
    let kind: BuildingKind
    let definition: BuildingDefinition
    /// What the shared stockpile still lacks; empty when the player can pay.
    let shortfall: [ResourceKind: Int]
    let hasWorkers: Bool
    let onBuild: () -> Void

    private static let blockedRed = Color(red: 0.96, green: 0.52, blue: 0.44)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                BuildingArtView(building: BuildingInstance(kind: kind, coordinate: GridCoordinate(x: 0, y: 0)))
                    .frame(width: 58, height: 58)
                    .background(kind.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(DuskaraTheme.Fonts.heading)
                        .foregroundStyle(DuskaraTheme.ink)
                    Text(definition.summary)
                        .font(DuskaraTheme.Fonts.caption)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: onBuild) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DuskaraTheme.accent)
                .disabled(shortfall.isEmpty == false)
                .opacity(shortfall.isEmpty ? 1 : 0.4)
                .accessibilityLabel("Build \(kind.title)")
            }

            ResourceCostRow(title: "Cost", values: definition.cost(for: 1))
            if shortfall.isEmpty == false {
                Label("Need \(shortfall.positiveEntries.map { "\($1) more \($0.title.lowercased())" }.joined(separator: " · "))",
                      systemImage: "hourglass")
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(Self.blockedRed)
            }
            if definition.peopleRequired > 0 {
                Label("Requires \(definition.peopleRequired) free people", systemImage: "person.fill")
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(hasWorkers ? DuskaraTheme.mutedInk : Self.blockedRed)
            }
            if definition.production(for: 1).isEmpty == false {
                ResourceCostRow(title: "Daily Production", values: definition.production(for: 1))
            }
            PlacementRuleView(rules: definition.placementRules)
        }
        .padding(12)
        .background(DuskaraTheme.card, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}

private struct PlacementRuleView: View {
    let rules: [PlacementRule]

    var body: some View {
        let filtered = rules.filter { $0 != .none }
        if filtered.isEmpty {
            Label("Can be built on any empty plot", systemImage: "square.grid.3x3.fill")
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.mutedInk)
        } else {
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, rule in
                switch rule {
                case .none:
                    EmptyView()
                case .onTownEdge:
                    Label("Must be built on the town's edge, by the water", systemImage: "water.waves")
                        .font(DuskaraTheme.Fonts.caption)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                }
            }
        }
    }
}
