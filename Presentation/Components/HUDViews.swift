import SwiftUI

struct TopHUDView: View {
    let town: Town
    let day: Int
    let progress: Double
    let income: [ResourceKind: Int]
    let armyStrength: Int
    let freePeople: Int
    let capacity: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(town.name)
                        .font(DuskaraTheme.Fonts.heading)
                        .foregroundStyle(.white.opacity(0.96))
                    HStack(spacing: 12) {
                        HUDMetric(systemImage: "sun.max.fill", value: "Day \(day)")
                        HUDMetric(systemImage: "shield.fill", value: "\(armyStrength)")
                        HUDMetric(systemImage: "person.2.fill", value: "\(freePeople)/\(capacity)")
                    }
                }
                Spacer(minLength: 10)
                dayDial
            }

            ProgressView(value: progress)
                .tint(DuskaraTheme.warmGold)
                .scaleEffect(x: 1, y: 0.72)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(ResourceKind.allCases) { kind in
                        ResourcePill(kind: kind, amount: town.resources[kind], income: income[kind])
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DuskaraTheme.hudGlassFill, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 18, bottomLeading: 14, bottomTrailing: 18, topTrailing: 14)))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 18, bottomLeading: 14, bottomTrailing: 18, topTrailing: 14))
                .stroke(DuskaraTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    private var dayDial: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(DuskaraTheme.warmGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "sun.max.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(DuskaraTheme.warmGold)
        }
        .frame(width: 34, height: 34)
        .animation(.smooth(duration: 0.28), value: progress)
    }
}

// Icon stays small and dim; the number carries the weight.
private struct HUDMetric: View {
    let systemImage: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.60))
            Text(value)
                .font(DuskaraTheme.Fonts.number)
                .foregroundStyle(.white.opacity(0.94))
                .contentTransition(.numericText())
        }
    }
}

struct BottomBarView: View {
    let onBuild: () -> Void
    let onWorld: () -> Void
    let onNextDay: () -> Void

    // Compact floating panel: the buttons hug their labels instead of
    // stretching across the window.
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBuild) {
                Label("Build", systemImage: "hammer.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            Button(action: onNextDay) {
                Label("Next", systemImage: "forward.end.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            Button(action: onWorld) {
                Label("World", systemImage: "map.fill")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DuskaraTheme.hudFill, in: Capsule())
        .overlay(Capsule().stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}

struct DuskaraButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DuskaraTheme.Fonts.subheading)
            .foregroundStyle(prominent ? .white : DuskaraTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(buttonFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(prominent ? 0.22 : 0.34), lineWidth: 1))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 4 : 9, y: configuration.isPressed ? 2 : 5)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }

    private var buttonFill: AnyShapeStyle {
        if prominent {
            AnyShapeStyle(LinearGradient(
                colors: [DuskaraTheme.accent, Color(red: 0.55, green: 0.30, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.33, green: 0.28, blue: 0.22), Color(red: 0.24, green: 0.20, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}
