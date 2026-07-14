import SwiftUI

struct VictoryView: View {
    let day: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Victory")
                .font(DuskaraTheme.Fonts.title)
                .foregroundStyle(.white)
            Text("Duskara fell on Day \(day).")
                .font(DuskaraTheme.Fonts.heading)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
    }
}

struct GameFeedbackToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DuskaraTheme.Fonts.subheading)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DuskaraTheme.hudFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
            .shadow(color: .black.opacity(0.26), radius: 14, y: 7)
            .padding(.horizontal, 18)
    }
}

struct NewsFeedPanel: View {
    let events: [NewsEvent]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("World News")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Spacer()
                Button("Close", action: onClose)
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.warmGold)
                    .buttonStyle(.plain)
            }
            if events.isEmpty {
                Text("No world events yet.")
                    .font(DuskaraTheme.Fonts.body)
                    .foregroundStyle(DuskaraTheme.mutedInk)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Day \(event.day)")
                                    .font(DuskaraTheme.Fonts.caption)
                                    .foregroundStyle(DuskaraTheme.mutedInk)
                                Text(event.message)
                                    .font(DuskaraTheme.Fonts.body)
                                    .foregroundStyle(DuskaraTheme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.20), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }
}
