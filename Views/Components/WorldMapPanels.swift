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

}
