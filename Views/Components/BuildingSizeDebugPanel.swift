#if DEBUG
import SwiftUI

/// Debug-only: live size sliders for the crafted building models, so the right
/// scale gets dialled in against the real board instead of guessed in Blender.
/// Moving a slider rescales every placed building of that kind immediately;
/// kinds the town has not built yet have nothing to rescale, which is fine.
struct BuildingSizeDebugPanel: View {
    @Binding var scales: [BuildingKind: Float]

    var body: some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
            HStack {
                Text("Building Size")
                    .font(DuskaraTheme.Fonts.heading)
                Spacer()
                Button("Reset") {
                    scales.removeAll()
                    BuildingScale.overrides.removeAll()
                }
                .font(DuskaraTheme.Fonts.caption)
            }

            ForEach(BuildingKind.allCases) { kind in
                let value = binding(for: kind)
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text(kind.title)
                            .font(DuskaraTheme.Fonts.body)
                        Spacer()
                        Text(String(format: "%.2f", value.wrappedValue))
                            .font(DuskaraTheme.Fonts.numberSmall)
                            .foregroundStyle(DuskaraTheme.warmGold)
                    }
                    Slider(value: value, in: BuildingScale.range)
                }
            }
        }
        .foregroundStyle(DuskaraTheme.ink)
        .padding(DuskaraTheme.spacingL)
        .frame(width: 250)
    }

    private func binding(for kind: BuildingKind) -> Binding<Float> {
        Binding(
            get: { scales[kind] ?? BuildingScale.standard },
            set: { newValue in
                scales[kind] = newValue
                BuildingScale.overrides[kind] = newValue
            }
        )
    }
}
#endif
