import SwiftUI

struct TutorialView: View {
    let onFinish: () -> Void

    @State private var pageIndex: Int? = 0

    private let pages = TutorialPage.all

    private var currentIndex: Int {
        pageIndex ?? 0
    }

    private var isLastPage: Bool {
        currentIndex >= pages.count - 1
    }

    var body: some View {
        VStack(spacing: DuskaraTheme.spacingL) {
            HStack {
                Spacer()
                Button("Skip", action: onFinish)
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                    .accessibilityLabel("Skip tutorial")
            }
            .padding(.horizontal, DuskaraTheme.spacingXL)
            .padding(.top, DuskaraTheme.spacingL)

            carousel

            pageDots

            controls
                .frame(maxWidth: 560)
                .padding(.horizontal, DuskaraTheme.spacingXL)
                .padding(.bottom, DuskaraTheme.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
    }

    // ScrollView paging instead of TabView(.page): the page tab style does
    // not exist on macOS.
    private var carousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    TutorialPageView(page: page)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageIndex)
        .scrollIndicators(.hidden)
    }

    private var pageDots: some View {
        HStack(spacing: DuskaraTheme.spacingS) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? DuskaraTheme.warmGold : .white.opacity(0.28))
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.smooth(duration: 0.2), value: currentIndex)
    }

    private var controls: some View {
        HStack(spacing: DuskaraTheme.spacingM) {
            Button {
                withAnimation { pageIndex = max(0, currentIndex - 1) }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DuskaraButtonStyle())
            .disabled(currentIndex == 0)
            .opacity(currentIndex == 0 ? 0.45 : 1)

            if isLastPage {
                Button(action: onFinish) {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
            } else {
                Button {
                    withAnimation { pageIndex = min(pages.count - 1, currentIndex + 1) }
                } label: {
                    Label("Next", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
            }
        }
    }
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            Spacer(minLength: 0)

            Image(systemName: page.systemImage)
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(DuskaraTheme.warmGold)
                .frame(width: 128, height: 128)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.16), lineWidth: 1))

            VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
                Text(page.title)
                    .font(.title.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                Text(page.body)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 520, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DuskaraTheme.spacingXL)
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
    }
}

private struct TutorialPage {
    let title: String
    let body: String
    let systemImage: String

    static let all: [TutorialPage] = [
        TutorialPage(
            title: "Welcome to Duskara",
            body: "Quest for Duskara is a strategy game set across an archipelago of island cities. You rule one island. Thirty-nine more wait beyond the water — including Duskara, the dark stronghold itself.",
            systemImage: "map.fill"
        ),
        TutorialPage(
            title: "Your Goal",
            body: "Grow your settlement, raise an army, and conquer your way across the isles. The campaign is won the day Duskara's crown falls to you.",
            systemImage: "crown.fill"
        ),
        TutorialPage(
            title: "Build Your City",
            body: "Tap Build to place structures on your town board. Houses add people, Piers bring in gold from sea trade, Farms grow food, Factories produce skill, and Barracks unlock soldier training. Buildings can be upgraded to grow stronger.",
            systemImage: "hammer.fill"
        ),
        TutorialPage(
            title: "Resources",
            body: "Gold and skill pay for construction and training. Food feeds your soldiers every day — run out and your army starts to disband. People staff your buildings, so keep housing ahead of demand.",
            systemImage: "leaf.fill"
        ),
        TutorialPage(
            title: "Combat",
            body: "Train archers and knights at the Barracks. From the World Map you can sail against any city in the archipelago — but your attack only succeeds if your army overpowers the defender's garrison and defenses.",
            systemImage: "shield.fill"
        ),
        TutorialPage(
            title: "Expansion",
            body: "Captured cities join your empire. Visit them to build and train there, and transfer gold, food, or soldiers between your cities to reinforce the front.",
            systemImage: "flag.fill"
        ),
        TutorialPage(
            title: "Winning",
            body: "Cities deeper in the archipelago defend themselves more fiercely, and Duskara most of all. Build your strength island by island — then take the stronghold. Good luck, commander.",
            systemImage: "sparkles"
        )
    ]
}

#Preview {
    TutorialView(onFinish: { })
}
