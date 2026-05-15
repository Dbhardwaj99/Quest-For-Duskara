import SwiftUI

struct ResourcePill: View {
    let kind: ResourceKind
    let amount: Int
    var income: Int? = nil

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(kind.color)
                .frame(width: 18, height: 18)
                .overlay(Text(kind.symbol).font(.caption2.bold()).foregroundStyle(.white))
            Text("\(amount)")
                .font(.caption.bold())
                .foregroundStyle(DuskaraTheme.ink)
            if let income, income != 0 {
                Text(income > 0 ? "+\(income)" : "\(income)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(income > 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.78), in: Capsule())
        .animation(.snappy, value: amount)
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
