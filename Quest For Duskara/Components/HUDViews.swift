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
        VStack(spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(town.name)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                    HStack(spacing: 10) {
                        Label("Day \(day)", systemImage: "sun.max.fill")
                        Label("Power \(armyStrength)", systemImage: "shield.fill")
                        Label("\(freePeople)/\(capacity)", systemImage: "person.2.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.86))
                }
                Spacer()
            }
            ProgressView(value: progress)
                .tint(.yellow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ResourceKind.allCases) { kind in
                        ResourcePill(kind: kind, amount: town.resources[kind], income: income[kind])
                    }
                }
            }
        }
        .padding(12)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
    }
}

struct BottomBarView: View {
    let onBuild: () -> Void
    let onWorld: () -> Void
    let onNextDay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBuild) {
                Label("Build", systemImage: "hammer.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            Button(action: onNextDay) {
                Label("Next Day", systemImage: "forward.end.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            Button(action: onWorld) {
                Label("World", systemImage: "map.fill")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

struct DuskaraButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(prominent ? .white : DuskaraTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(prominent ? DuskaraTheme.accent : DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
