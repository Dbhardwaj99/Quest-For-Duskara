import SwiftUI

struct SeaRoute: Identifiable {
    let id: String
    let from: MapPoint
    let to: MapPoint
    let isTrade: Bool
    let hasShip: Bool
    let seed: Int

    static func isTradeRoute(_ pierTown: Town, _ partner: Town) -> Bool {
        pierTown.isPlayerControlled
            && pierTown.buildings.contains { $0.kind == .pier }
            && partner.faction == .neutral
    }

    // Hasher's per-launch seed would reshuffle ships every run; this stays
    // stable so each lane keeps its curve, pace, and phase.
    static func stableHash(_ value: String) -> Int {
        var hash = 5381
        for scalar in value.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return abs(hash)
    }

    // Lanes bow gently to one side so crossings read as shipping arcs, not
    // a straight wire diagram.
    func controlPoint(projection: WorldMapProjection) -> CGPoint {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(1, hypot(dx, dy))
        let side: CGFloat = seed.isMultiple(of: 2) ? 1 : -1
        let bulge = min(30, length * 0.16) * side
        return CGPoint(x: mid.x - dy / length * bulge, y: mid.y + dx / length * bulge)
    }

    func path(projection: WorldMapProjection) -> Path {
        var path = Path()
        path.move(to: projection.point(for: from))
        path.addQuadCurve(to: projection.point(for: to), control: controlPoint(projection: projection))
        return path
    }

    func point(at t: CGFloat, projection: WorldMapProjection) -> CGPoint {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let control = controlPoint(projection: projection)
        let inverse = 1 - t
        return CGPoint(
            x: inverse * inverse * start.x + 2 * inverse * t * control.x + t * t * end.x,
            y: inverse * inverse * start.y + 2 * inverse * t * control.y + t * t * end.y
        )
    }

    func heading(at t: CGFloat, projection: WorldMapProjection) -> CGFloat {
        let start = projection.point(for: from)
        let end = projection.point(for: to)
        let control = controlPoint(projection: projection)
        let dx = 2 * (1 - t) * (control.x - start.x) + 2 * t * (end.x - control.x)
        let dy = 2 * (1 - t) * (control.y - start.y) + 2 * t * (end.y - control.y)
        return atan2(dy, dx)
    }
}

// Animated layer: flowing gold trade lanes, little ships shuttling between
// islands, and slow cloud shadows. One Canvas redrawn at ~24 fps; everything
// else on the map stays static.
struct SeaTrafficLayer: View {
    let routes: [SeaRoute]

    static let tradeGold = Color(red: 0.94, green: 0.78, blue: 0.42)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { timeline in
            Canvas { context, size in
                let projection = WorldMapProjection(size: size)
                let time = timeline.date.timeIntervalSinceReferenceDate

                drawCloudShadows(context: context, size: size, time: time)

                for route in routes where route.isTrade {
                    // Dashes flow along the lane so trade reads as movement
                    // even between ship crossings.
                    context.stroke(
                        route.path(projection: projection),
                        with: .color(Self.tradeGold.opacity(0.55)),
                        style: StrokeStyle(
                            lineWidth: 1.6,
                            lineCap: .round,
                            dash: [5, 7],
                            dashPhase: CGFloat(route.seed % 12) - CGFloat(time * 10)
                        )
                    )
                }

                for route in routes where route.hasShip {
                    drawShip(route: route, projection: projection, time: time, context: context)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // Ships shuttle back and forth with an eased turnaround at each pier.
    func drawShip(route: SeaRoute, projection: WorldMapProjection, time: TimeInterval, context: GraphicsContext) {
        let period = Double(16 + route.seed % 7 * 2)
        let phase = Double(route.seed % 100) / 100
        let raw = ((time / period) + phase).truncatingRemainder(dividingBy: 1)
        let outbound = raw < 0.5
        let linear = CGFloat(outbound ? raw * 2 : 2 - raw * 2)
        let t = linear * linear * (3 - 2 * linear)

        let position = route.point(at: t, projection: projection)
        var heading = route.heading(at: t, projection: projection)
        if outbound == false { heading += .pi }

        context.drawLayer { layer in
            layer.translateBy(x: position.x, y: position.y)
            layer.rotate(by: Angle(radians: heading + .pi / 2))

            var wake = Path()
            wake.move(to: CGPoint(x: -1.6, y: 5))
            wake.addLine(to: CGPoint(x: -2.8, y: 11))
            wake.move(to: CGPoint(x: 1.6, y: 5))
            wake.addLine(to: CGPoint(x: 2.8, y: 11))
            layer.stroke(wake, with: .color(.white.opacity(0.35)), lineWidth: 1)

            var hull = Path()
            hull.move(to: CGPoint(x: 0, y: -6))
            hull.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 3.6, y: -2))
            hull.addLine(to: CGPoint(x: -3, y: 4))
            hull.addQuadCurve(to: CGPoint(x: 0, y: -6), control: CGPoint(x: -3.6, y: -2))
            layer.fill(hull, with: .color(Color(red: 0.45, green: 0.32, blue: 0.23)))

            var sail = Path()
            sail.move(to: CGPoint(x: 0, y: -4.5))
            sail.addLine(to: CGPoint(x: 2.8, y: 1.5))
            sail.addLine(to: CGPoint(x: 0, y: 1.5))
            sail.closeSubpath()
            layer.fill(sail, with: .color(route.isTrade ? Self.tradeGold : .white.opacity(0.92)))
        }
    }

    // Big soft shadows sliding across the sea sell scale and motion for
    // almost nothing: three radial-gradient ellipses per frame.
    func drawCloudShadows(context: GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<3 {
            let speed = 0.006 + Double(index) * 0.003
            let x = ((time * speed + Double(index) * 0.37).truncatingRemainder(dividingBy: 1.3) - 0.15) * size.width
            let y = size.height * (0.18 + Double(index) * 0.28)
            let radius = size.width * (0.10 + CGFloat(index) * 0.03)
            let center = CGPoint(x: x, y: y)
            let rect = CGRect(x: center.x - radius * 1.6, y: center.y - radius, width: radius * 3.2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [.black.opacity(0.07), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius * 1.6
                )
            )
        }
    }
}

// Water cells are never painted — the shared sea shows through — so the
// terrain canvas has no visible rectangle edge. Islands get a shallow-water
// shelf, one cohesive sand silhouette with a soft drop shadow, then the
// per-cell terrain colors on top.
