import SwiftUI

struct BuildMenuView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a building, then place it on a highlighted town plot.")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DuskaraTheme.ink)

                    ForEach(BuildingKind.allCases) { kind in
                        if let definition = viewModel.definition(for: kind) {
                            BuildingMenuCard(kind: kind, definition: definition) {
                                viewModel.beginPlacement(for: kind)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(DuskaraTheme.panel.opacity(0.35))
            .navigationTitle("Build")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { viewModel.isBuildMenuPresented = false }
                }
            }
        }
    }
}

private struct BuildingMenuCard: View {
    let kind: BuildingKind
    let definition: BuildingDefinition
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                BuildingArtView(building: BuildingInstance(kind: kind, coordinate: GridCoordinate(x: 0, y: 0)))
                    .frame(width: 58, height: 58)
                    .background(kind.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.headline.weight(.heavy))
                    Text(definition.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(action: onBuild) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DuskaraTheme.accent)
            }

            ResourceCostRow(title: "Cost", values: definition.cost(for: 1))
            if definition.peopleRequired > 0 {
                Label("Requires \(definition.peopleRequired) free people", systemImage: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if definition.production(for: 1).isEmpty == false {
                ResourceCostRow(title: "Daily Production", values: definition.production(for: 1))
            }
            PlacementRuleView(rules: definition.placementRules)
        }
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PlacementRuleView: View {
    let rules: [PlacementRule]

    var body: some View {
        let filtered = rules.filter { $0 != .none }
        if filtered.isEmpty {
            Label("Can be built on any empty plot", systemImage: "square.grid.3x3.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, rule in
                switch rule {
                case .none:
                    EmptyView()
                case .adjacentToBiome(let biome):
                    Label("Must touch \(biome.title.lowercased()) border", systemImage: biome == .forest ? "tree.fill" : "mountain.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
