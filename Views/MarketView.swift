import SwiftUI

/// Harbor Market: surplus sold and shortfalls bought for gold, one click a
/// trade. It stays open between clicks — trades come in runs.
struct MarketView: View {
    @Bindable var viewModel: GameViewModel
    @State private var lot = 100

    var body: some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Harbor Market")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Text(summary)
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.isMarketOpen {
                Picker("Lot", selection: $lot) {
                    Text("100").tag(100)
                    Text("1,000").tag(1_000)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                row(.food)
                row(.skill)

                let surplus = viewModel.surplusFood
                Button {
                    viewModel.trade(.food, lot: surplus, buying: false)
                } label: {
                    Label(
                        surplus > 0
                            ? "Sell surplus food  +\(viewModel.marketPrice(of: .food, lot: surplus, buying: false) ?? 0) gold"
                            : "No surplus food to sell",
                        systemImage: "leaf.fill"
                    )
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
                .disabled(surplus == 0)
                .opacity(surplus == 0 ? 0.55 : 1)

                Text("Surplus keeps ten days of rations. Conquering a free city closes its trade route.")
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summary: String {
        guard let fee = viewModel.marketFeePercent else {
            return "No free city trades with you. An island with a Pier needs a sea lane to a neutral island."
        }
        return "Trading with \(viewModel.tradePartners.map(\.name).joined(separator: ", ")) · \(fee)% fee"
    }

    private func row(_ kind: ResourceKind) -> some View {
        HStack(spacing: DuskaraTheme.spacingS) {
            ResourcePill(kind: kind, amount: viewModel.spendingTown.resources[kind])
            Spacer()
            tradeButton(kind, buying: false)
            tradeButton(kind, buying: true)
        }
    }

    private func tradeButton(_ kind: ResourceKind, buying: Bool) -> some View {
        let price = viewModel.marketPrice(of: kind, lot: lot, buying: buying) ?? 0
        let enabled = viewModel.canTrade(kind, lot: lot, buying: buying)
        return Button(buying ? "Buy −\(price)g" : "Sell +\(price)g") {
            viewModel.trade(kind, lot: lot, buying: buying)
        }
        .buttonStyle(DuskaraButtonStyle())
        .fixedSize()
        .disabled(enabled == false)
        .opacity(enabled ? 1 : 0.5)
        .help("\(buying ? "Buy" : "Sell") \(lot) \(kind.title.lowercased()) for \(price) gold")
    }
}
