import SwiftUI

struct ResourcePill: View {
    let kind: ResourceKind
    let amount: Int?
    var income: Int? = nil
    /// Changes once per day; each change floats the day's `income` up off the
    /// pill, so the tick reads as a payout rather than a silent number change.
    var tick: Int? = nil
    /// When the current tick's number started rising; nil once it has gone.
    @State private var floatStart: Date?

    private static let gain = Color(red: 0.56, green: 0.84, blue: 0.44)
    private static let loss = Color(red: 0.94, green: 0.48, blue: 0.40)
    private static let floatDuration = 1.2

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(kind.color.gradient)
                Circle()
                    .stroke(.white.opacity(0.36), lineWidth: 1)
                Text(kind.symbol)
                    .font(DuskaraTheme.Fonts.label)
                    .foregroundStyle(.white)
            }
            .frame(width: 20, height: 20)
            .shadow(color: kind.color.opacity(0.24), radius: 5, y: 2)

            if let amount {
                Text("\(amount)")
                    .font(DuskaraTheme.Fonts.number)
                    .foregroundStyle(DuskaraTheme.ink)
                    .contentTransition(.numericText())
            }

            if let income, income != 0 {
                Text(income > 0 ? "+\(income)" : "\(income)")
                    .font(DuskaraTheme.Fonts.numberSmall)
                    .foregroundStyle(income > 0 ? Self.gain : Self.loss)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.32), in: Capsule())
                    .contentTransition(.numericText())
            }
        }
        .overlay(alignment: .top) {
            // Nothing shows until the first tick. A 60 Hz timeline that only
            // exists while the number rises: a keyframe animation would run at
            // the display's full 120 Hz.
            if let floatStart, let income, income != 0 {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                    let rise = min(1, context.date.timeIntervalSince(floatStart) / Self.floatDuration)
                    Text(income > 0 ? "+\(income)" : "\(income)")
                        .font(DuskaraTheme.Fonts.number)
                        .foregroundStyle(income > 0 ? Self.gain : Self.loss)
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        .offset(y: -20 * rise)
                        .opacity(1 - rise)
                }
                .allowsHitTesting(false)
            }
        }
        .onChange(of: tick) { floatStart = .now }
        .task(id: floatStart) {
            guard floatStart != nil,
                  (try? await Task.sleep(for: .seconds(Self.floatDuration))) != nil else { return }
            floatStart = nil
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color(red: 0.33, green: 0.28, blue: 0.22), Color(red: 0.24, green: 0.20, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .animation(.smooth(duration: 0.22), value: amount)
        .animation(.smooth(duration: 0.22), value: income)
    }
}

struct ResourceCostRow: View {
    let title: String
    let values: [ResourceKind: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.mutedInk)
            FlowLayout(spacing: 6) {
                ForEach(values.positiveEntries, id: \.0) { kind, amount in
                    ResourcePill(kind: kind, amount: amount)
                }
                if values.positiveEntries.isEmpty {
                    Text("None")
                        .font(DuskaraTheme.Fonts.caption)
                        .foregroundStyle(DuskaraTheme.mutedInk)
                }
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
