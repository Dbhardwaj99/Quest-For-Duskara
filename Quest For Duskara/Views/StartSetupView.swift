import SwiftUI

struct StartSetupView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 18)
            VStack(spacing: 8) {
                Text("Quest for Duskara")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Found your first settlement by distributing the bonus stockpile.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 14) {
                HStack {
                    Text("Bonus Pool")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Text("\(viewModel.remainingBonus)")
                        .font(.title2.monospacedDigit().weight(.black))
                        .foregroundStyle(viewModel.remainingBonus == 0 ? .green : DuskaraTheme.accent)
                }

                ForEach(viewModel.startingResourceKinds) { kind in
                    BonusAllocationRow(
                        kind: kind,
                        base: viewModel.balance.baseStartingResources[kind, default: 0],
                        bonus: viewModel.bonusAllocation[kind, default: 0],
                        total: viewModel.startingTotal(for: kind),
                        canDecrease: viewModel.bonusAllocation[kind, default: 0] > 0,
                        canIncrease: viewModel.remainingBonus > 0,
                        onDecrease: { viewModel.adjustBonus(for: kind, by: -10) },
                        onIncrease: { viewModel.adjustBonus(for: kind, by: 10) }
                    )
                }

                Button(action: viewModel.startGame) {
                    Label("Found Duskara", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
                .disabled(viewModel.remainingBonus != 0)
                .opacity(viewModel.remainingBonus == 0 ? 1 : 0.55)
            }
            .padding(16)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 18)
            Spacer(minLength: 18)
        }
        .background(DuskaraTheme.background.ignoresSafeArea())
    }
}

private struct BonusAllocationRow: View {
    let kind: ResourceKind
    let base: Int
    let bonus: Int
    let total: Int
    let canDecrease: Bool
    let canIncrease: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                ResourcePill(kind: kind, amount: total)
                Spacer()
                Text("Base \(base) + \(bonus)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button(action: onDecrease) {
                    Image(systemName: "minus.circle.fill")
                }
                .disabled(!canDecrease)
                .font(.title3)

                Slider(
                    value: Binding(
                        get: { Double(bonus) },
                        set: { _ in }
                    ),
                    in: 0...100
                )
                .tint(kind.color)
                .allowsHitTesting(false)

                Button(action: onIncrease) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(!canIncrease)
                .font(.title3)
            }
        }
        .foregroundStyle(DuskaraTheme.ink)
    }
}
