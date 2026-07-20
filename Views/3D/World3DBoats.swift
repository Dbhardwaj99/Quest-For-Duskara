import RealityKit
import AppKit


extension World3DRenderer {
    // MARK: - Boats

    // A boat that cruises waypoint-to-waypoint around the coastline and
    // occasionally puts in at the town pier. Legs are single transform
    // animations; a 1 Hz timer only picks the next waypoint, so the cost is
    // negligible.
    struct BoatCruiser {
        let entity: Entity
        let speed: Float          // world units per second
        let radiusScale: Float
        var angle: Float          // current position angle around the island
        var nextLegAt: Date
        var isVisitingDock = false
        var lastDockTime = Date.distantPast
    }

    func spawnBoats(boardWidth: Float, boardDepth: Float, waterY: Float) {
        boatCruisers.removeAll()
        boatWaterY = waterY
        boatBaseRadius = SIMD2<Float>(
            boardWidth / 2 + tileSize * 2.3,
            boardDepth / 2 + tileSize * 2.3
        )

        // Two small boats and one larger trader, each with its own pace,
        // route radius, and starting point.
        let specs: [(scale: Float, speed: Float, angle: Float, radiusScale: Float)] = [
            (1.0, 0.075, 0.6, 1.0),
            (0.85, 0.060, 2.8, 1.18),
            (1.55, 0.048, 4.5, 1.45)
        ]
        for spec in specs {
            let boat = makeBoat(scale: spec.scale)
            boat.position = cruiseWaypoint(angle: spec.angle, radiusScale: spec.radiusScale)
            staticRoot.addChild(boat)
            boatCruisers.append(BoatCruiser(
                entity: boat,
                speed: spec.speed,
                radiusScale: spec.radiusScale,
                angle: spec.angle,
                nextLegAt: Date().addingTimeInterval(Double.random(in: 0...2))
            ))
        }

        if boatTimer == nil {
            boatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                let renderer = self
                Task { @MainActor in renderer?.tickBoats() }
            }
        }
    }

    func tickBoats() {
        let now = Date()
        for index in boatCruisers.indices where now >= boatCruisers[index].nextLegAt {
            startNextLeg(boatIndex: index, now: now)
        }
    }

    func startNextLeg(boatIndex: Int, now: Date) {
        var boat = boatCruisers[boatIndex]
        var dwell = TimeInterval(Float.random(in: 0.5...2.5))
        let target: SIMD3<Float>

        if boat.isVisitingDock {
            // Done at the pier; head back out and resume the route.
            boat.isVisitingDock = false
            boat.angle += Float.random(in: 0.5...0.85)
            target = cruiseWaypoint(angle: boat.angle, radiusScale: boat.radiusScale)
        } else if let dock = pierDockPoint,
                  now.timeIntervalSince(boat.lastDockTime) > 45,
                  abs(angleDelta(atan2(dock.x, dock.z) - boat.angle)) < 0.55,
                  Int.random(in: 0..<3) == 0 {
            // Passing the pier side of the island: put in for a short stop.
            target = dock
            dwell = TimeInterval(Float.random(in: 4...9))
            boat.isVisitingDock = true
            boat.lastDockTime = now
        } else {
            boat.angle += Float.random(in: 0.45...0.8)
            target = cruiseWaypoint(angle: boat.angle, radiusScale: boat.radiusScale)
        }

        let current = boat.entity.position
        let duration = TimeInterval(max(2, simd_distance(current, target) / boat.speed))
        var transform = boat.entity.transform
        transform.translation = target
        transform.rotation = simd_quatf(angle: atan2(target.x - current.x, target.z - current.z), axis: SIMD3<Float>(0, 1, 0))
        boat.entity.move(to: transform, relativeTo: boat.entity.parent, duration: duration, timingFunction: .easeInOut)
        boat.nextLegAt = now.addingTimeInterval(duration + dwell)
        boatCruisers[boatIndex] = boat
    }

    // Waypoints sit on a jittered ellipse around the island; the minimum
    // radius keeps every leg's straight line clear of the coastline.
    func cruiseWaypoint(angle: Float, radiusScale: Float) -> SIMD3<Float> {
        let jitter = Float.random(in: 0.94...1.14)
        return SIMD3<Float>(
            sin(angle) * boatBaseRadius.x * radiusScale * jitter,
            boatWaterY,
            cos(angle) * boatBaseRadius.y * radiusScale * jitter
        )
    }

    func updatePierDockPoint(town: Town) {
        guard let pier = town.buildings.first(where: { $0.kind == .pier }) else {
            pierDockPoint = nil
            return
        }
        let center = position(for: pier.coordinate)
        // Same nearest-edge priority the pier model uses to face the sea.
        let left = pier.coordinate.x
        let right = gridSize.columns - 1 - pier.coordinate.x
        let top = pier.coordinate.y
        let bottom = gridSize.rows - 1 - pier.coordinate.y
        let minimum = min(left, right, top, bottom)
        let outward: SIMD3<Float>
        if bottom == minimum {
            outward = SIMD3<Float>(0, 0, 1)
        } else if top == minimum {
            outward = SIMD3<Float>(0, 0, -1)
        } else if right == minimum {
            outward = SIMD3<Float>(1, 0, 0)
        } else {
            outward = SIMD3<Float>(-1, 0, 0)
        }
        var point = center + outward * (tileSize * 1.75)
        point.y = boatWaterY
        pierDockPoint = point
    }

}
