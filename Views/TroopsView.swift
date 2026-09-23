import SwiftUI

/// Soldiers are the one thing left to move by hand — each island's army is its
/// defense. Gold, food and skill need no moving: every island spends from the
/// shared stockpile.
struct TroopsView: View {
    @Bindable var viewModel: GameViewModel
    @State private var movesAll = true

    private var fraction: Double { movesAll ? 1 : 0.5 }

    var body: some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Troops")
                        .font(DuskaraTheme.Fonts.heading)
                        .foregroundStyle(DuskaraTheme.ink)
                    Text("\(viewModel.activeTown.name) holds \(viewModel.activeArmyStrength) power")
                        .font(DuskaraTheme.Fonts.caption)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                }
                Spacer()
                Picker("Amount", selection: $movesAll) {
                    Text("Half").tag(false)
                    Text("All").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 110)
            }

            ForEach(viewModel.transferDestinations) { town in
                row(town)
            }

            Button {
                viewModel.pullAllTroops()
            } label: {
                Label("Pull every island's troops here", systemImage: "arrow.down.to.line")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
            .disabled(viewModel.transferDestinations.allSatisfy { $0.armyStrength == 0 })
        }
        .padding(DuskaraTheme.spacingL)
        .frame(width: 380)
        .background(DuskaraTheme.sheetBackground)
        .environment(\.colorScheme, .dark)
    }

    private func row(_ town: Town) -> some View {
        HStack(spacing: DuskaraTheme.spacingS) {
            Text(town.name)
                .font(DuskaraTheme.Fonts.body)
                .foregroundStyle(DuskaraTheme.ink)
            Spacer()
            Label("\(town.armyStrength)", systemImage: "shield.fill")
                .font(DuskaraTheme.Fonts.numberSmall)
                .foregroundStyle(DuskaraTheme.mutedInk)
            Button("Pull") {
                viewModel.moveTroops(from: town.id, to: viewModel.state.activeTownID, fraction: fraction)
            }
            .buttonStyle(DuskaraButtonStyle())
            .fixedSize()
            .disabled(town.armyStrength == 0)
            .accessibilityLabel("Pull troops from \(town.name)")
            Button("Send") {
                viewModel.moveTroops(from: viewModel.state.activeTownID, to: town.id, fraction: fraction)
            }
            .buttonStyle(DuskaraButtonStyle())
            .fixedSize()
            .disabled(viewModel.activeArmyStrength == 0)
            .accessibilityLabel("Send troops to \(town.name)")
        }
        .padding(DuskaraTheme.spacingS)
        .background(DuskaraTheme.card, in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS))
    }
}
