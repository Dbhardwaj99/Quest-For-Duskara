import SwiftUI

extension WorldMapView {
    var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("World Map")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Text("Empire power \(viewModel.empireArmyStrength) · Active: \(viewModel.activeTown.name)")
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.mutedInk)
            }
            Button {
                viewModel.isWorldMapPresented = false
            } label: {
                Label("Town", systemImage: "chevron.backward")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
            .fixedSize()
            .accessibilityLabel("Return to town")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 14, y: 7)
    }

    var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Territories")
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.ink)
            HStack(spacing: 8) {
                LegendSwatch(color: TownFaction.player.mapColor, title: "You")
                LegendSwatch(color: TownFaction.neutral.mapColor, title: "Neutral")
                LegendSwatch(color: TownFaction.enemy.mapColor, title: "Enemy")
                LegendSwatch(color: TownFaction.duskara.mapColor, title: "Duskara")
            }
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color(red: 0.94, green: 0.78, blue: 0.42))
                            .frame(width: 5, height: 2)
                    }
                }
                Text("Trade route")
                    .font(DuskaraTheme.Fonts.label)
                    .foregroundStyle(DuskaraTheme.mutedInk)
            }
        }
        .padding(10)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
    }

    @ViewBuilder
    var selectedTownPanel: some View {
        if let selectedTownID, let town = viewModel.state.town(id: selectedTownID) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(town.name)
                            .font(DuskaraTheme.Fonts.heading)
                            .foregroundStyle(DuskaraTheme.ink)
                        Text(statusText(for: town))
                            .font(DuskaraTheme.Fonts.caption)
                            .foregroundStyle(DuskaraTheme.mutedInk)
                        if town.isPlayerControlled {
                            Text(town.specializationSummary)
                                .font(DuskaraTheme.Fonts.label)
                                .foregroundStyle(specializationColor(for: town))
                        }
                    }
                    Spacer()
                    if town.isPlayerControlled {
                        Button("Visit") { viewModel.switchToTown(town.id) }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .frame(width: 96)
                    } else {
                        Button("Attack") { viewModel.attackTown(town.id) }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .frame(width: 104)
                            .disabled(!viewModel.canAttack(town.id))
                            .opacity(viewModel.canAttack(town.id) ? 1 : 0.45)
                    }
                }

                // Friendly towns show their stockpile; enemy towns reveal
                // only their soldier count (already in the status line).
                if town.isPlayerControlled {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ResourceKind.allCases) { kind in
                                ResourcePill(kind: kind, amount: kind == .soldiers ? town.armyStrength : town.resources[kind])
                            }
                        }
                    }
                }

                if town.isPlayerControlled && town.id != viewModel.state.activeTownID {
                    TransferPanel(
                        kind: $transferKind,
                        amount: $transferAmount,
                        available: availableTransferAmount(for: transferKind),
                        onSend: { viewModel.transfer(transferKind, amount: transferAmount, to: town.id) }
                    )
                }
            }
            .padding(14)
            .frame(maxWidth: 480)
            .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 16, y: 8)
        }
    }

    func statusText(for town: Town) -> String {
        if town.isPlayerControlled { return "Controlled town · Army \(town.armyStrength)" }
        if town.isDuskara { return "Duskara stronghold · Soldiers \(town.armyStrength)" }
        if town.faction == .enemy { return "Enemy town · Soldiers \(town.armyStrength)" }
        return "Neutral town · Soldiers \(town.armyStrength)"
    }

    func availableTransferAmount(for kind: ResourceKind) -> Int {
        kind == .soldiers ? viewModel.activeTown.armyStrength : viewModel.activeTown.resources[kind]
    }

    func specializationColor(for town: Town) -> Color {
        if town.forestSideCount >= 3 { return Color(red: 0.55, green: 0.80, blue: 0.45) }
        if town.mountainSideCount >= 3 { return Color(red: 0.75, green: 0.77, blue: 0.80) }
        return DuskaraTheme.mutedInk
    }
}
