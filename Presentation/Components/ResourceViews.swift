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
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 20, height: 20)
            .shadow(color: kind.color.opacity(0.24), radius: 5, y: 2)

            if let amount {
                Text("\(amount)")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(DuskaraTheme.ink)
                    .contentTransition(.numericText())
            }

            if let income, income != 0 {
                Text(income > 0 ? "+\(income)" : "\(income)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(income > 0 ? Color(red: 0.25, green: 0.48, blue: 0.20) : Color(red: 0.58, green: 0.22, blue: 0.18))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.42), in: Capsule())
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.89, blue: 0.72).opacity(0.92), Color(red: 0.74, green: 0.66, blue: 0.48).opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: Capsule()
        )
        .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1))
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(values.positiveEntries, id: \.0) { kind, amount in
                    ResourcePill(kind: kind, amount: amount)
                }
                if values.positiveEntries.isEmpty {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
