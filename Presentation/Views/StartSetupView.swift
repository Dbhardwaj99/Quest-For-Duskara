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

			VStack(alignment: .center, spacing: 14) {
				Text("Choose Difficulty")
					.font(.headline.weight(.bold))
				
				
				ForEach(viewModel.difficulty) { mode in
					BonusAllocationRow(
						resourceKind: viewModel.startingResourceKinds,
						difficulty: mode,
						onSelected: {
							viewModel.adjustBonusPresets(for: mode)
							viewModel.startGame()
						}
					)
				}
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
	let resourceKind: [ResourceKind]
	let difficulty: Difficulty
	let onSelected: () -> Void

	var body: some View {
		Button(action: onSelected) {
			VStack(spacing: 8) {
				HStack {
					Text(difficulty.description)
						.font(.title2)
						.foregroundStyle(.secondary)
					
					Spacer()
				}
				HStack {
					Text("Bonus: ")
					ScrollView(.horizontal, showsIndicators: false) {
						HStack {
							ForEach(resourceKind) { kind in
								HStack {
									ResourcePill(kind: kind, amount: -100)
									Text("+ \(difficulty.modebalance[kind] ?? 0)")
										.font(.caption.monospacedDigit().weight(.semibold))
										.foregroundStyle(.green)
								}
							}
						}
					}
				}
			}
			.foregroundStyle(DuskaraTheme.ink)
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 23)
					.fill(Color.red.opacity(0.15))
			)
		}
		.buttonStyle(DuskaraButtonStyle(prominent: true))
	}
}
