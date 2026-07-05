import SwiftUI

struct ResourcePill: View {
    let kind: ResourceKind
    let amount: Int?
    var income: Int? = nil

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
                    .foregroundStyle(income > 0 ? Color(red: 0.56, green: 0.84, blue: 0.44) : Color(red: 0.94, green: 0.48, blue: 0.40))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.32), in: Capsule())
                    .contentTransition(.numericText())
            }
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
