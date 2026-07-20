import SwiftUI

// Cartoon wave arcs living inside the pannable/zoomable map content, so the
// sea moves with the terrain instead of sitting behind it as a fixed sheet.
// Row phase and radius wobble slightly so the grid doesn't read as a grid.
struct SeaWavesLayer: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 58
            var row = 0
            var y: CGFloat = spacing * 0.4
            while y < size.height + spacing {
                let wobble = sin(CGFloat(row) * 2.17)
                var x: CGFloat = (row.isMultiple(of: 2) ? 0 : spacing / 2) + wobble * spacing * 0.22 - spacing
                var column = 0
                while x < size.width + spacing {
                    defer {
                        x += spacing * (0.86 + 0.28 * abs(sin(CGFloat(row * 7 + column) * 1.31)))
                        column += 1
                    }
                    // Occasional missing arc keeps the swell irregular.
                    if (row * 13 + column * 7) % 5 == 0 { continue }
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: x, y: y + wobble * 4),
                        radius: spacing * (0.20 + 0.07 * abs(wobble)),
                        startAngle: .degrees(25),
                        endAngle: .degrees(155),
                        clockwise: false
                    )
                    context.stroke(
                        arc,
                        with: .color(.white.opacity(row.isMultiple(of: 3) ? 0.06 : 0.09)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
                y += spacing * 0.75
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

// Decorative eight-point compass rose, bottom-left, in the parchment style
// of the HUD.
struct CompassRose: View {
    var body: some View {
        ZStack {
            CompassStar(innerRatio: 0.20)
                .fill(.white.opacity(0.22))
                .rotationEffect(.degrees(45))
                .frame(width: 34, height: 34)
            CompassStar(innerRatio: 0.24)
                .fill(.white.opacity(0.55))
                .frame(width: 46, height: 46)
            Text("N")
                .font(DuskaraTheme.Fonts.label)
                .foregroundStyle(.white.opacity(0.75))
                .offset(y: -32)
        }
        .frame(width: 56, height: 72, alignment: .bottom)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct CompassStar: Shape {
    var innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

struct LegendSwatch: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(DuskaraTheme.Fonts.label)
                .foregroundStyle(DuskaraTheme.mutedInk)
        }
    }
}
