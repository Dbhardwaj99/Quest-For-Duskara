import RealityKit
import AppKit


extension World3DRenderer {
    // MARK: - Soldier pieces

    // Static board-game pieces for the trained roster: up to 3 archers and 3
    // knights clustered on a grass tile beside the barracks. No collisions,
    // no per-frame logic; rebuilt only when counts, anchor, or theme change.
    func updateSoldierPieces(town: Town, snapshots: [World3DTileSnapshot]) {
        let archers = min(town.soldierRoster[.archer], 3)
        let knights = min(town.soldierRoster[.knight], 3)
        let anchor = soldierAnchorCoordinate(town: town, snapshots: snapshots)
        let signature = "\(archers)|\(knights)|\(anchor?.x ?? -1),\(anchor?.y ?? -1)|\(WorldTheme.current.rawValue)"
        guard signature != soldierSignature else { return }
        soldierSignature = signature

        soldierRoot.children.forEach { $0.removeFromParent() }
        guard archers + knights > 0, let anchor else { return }

        var base = position(for: anchor)
        base.y += tileElevation(for: anchor)

        // Archers form the front rank, knights the back, like chess pieces.
        for (kind, count, rowZ) in [(SoldierKind.archer, archers, Float(0.13)), (.knight, knights, Float(-0.13))] {
            for slot in 0..<count {
                let piece = makeSoldierPiece(kind: kind)
                piece.position = base + SIMD3<Float>(
                    (Float(slot) - Float(count - 1) / 2) * tileSize * 0.26,
                    0,
                    rowZ * tileSize
                )
                piece.orientation = simd_quatf(angle: Float(slot) * 0.22 - 0.18, axis: SIMD3<Float>(0, 1, 0))
                soldierRoot.addChild(piece)
            }
        }
    }

    func soldierAnchorCoordinate(town: Town, snapshots: [World3DTileSnapshot]) -> GridCoordinate? {
        var grass = Set<GridCoordinate>()
        for snapshot in snapshots where snapshot.content == .grass {
            grass.insert(snapshot.coordinate)
        }
        if let barracks = town.buildings.first(where: { $0.kind == .barracks }) {
            let c = barracks.coordinate
            let neighbors = [
                GridCoordinate(x: c.x, y: c.y + 1),
                GridCoordinate(x: c.x + 1, y: c.y),
                GridCoordinate(x: c.x, y: c.y - 1),
                GridCoordinate(x: c.x - 1, y: c.y)
            ]
            if let open = neighbors.first(where: grass.contains) { return open }
        }
        // No barracks (or it is boxed in): muster on the grass tile nearest
        // the board center.
        let centerX = Float(gridSize.columns - 1) / 2
        let centerY = Float(gridSize.rows - 1) / 2
        return grass.min {
            let a = (Float($0.x) - centerX, Float($0.y) - centerY)
            let b = (Float($1.x) - centerX, Float($1.y) - centerY)
            return a.0 * a.0 + a.1 * a.1 < b.0 * b.0 + b.1 * b.1
        }
    }

    // Blocky chess-piece figure: plinth, tunic body, head, plus a helmet and
    // shield for knights or a bow and quiver for archers.
    func makeSoldierPiece(kind: SoldierKind) -> Entity {
        let piece = Entity()
        let s = tileSize
        let skin = NSColor(red: 0.91, green: 0.75, blue: 0.58, alpha: 1)
        let tunic = kind == .knight ? palette.bannerRed : palette.forestMoss

        let plinth = World3DRenderResources.makeCylinder(
            radius: s * 0.058,
            height: s * 0.022,
            material: matte(palette.plinthStone, roughness: 0.94)
        )
        plinth.position.y = s * 0.011
        piece.addChild(plinth)

        let body = World3DRenderResources.makeBox(
            size: SIMD3<Float>(0.072, 0.095, 0.052) * s,
            material: matte(tunic, roughness: 0.86),
            cornerRadius: s * 0.012
        )
        body.position.y = s * 0.070
        piece.addChild(body)

        let head = World3DRenderResources.makeBox(
            size: SIMD3<Float>(repeating: 0.042) * s,
            material: matte(skin, roughness: 0.88),
            cornerRadius: s * 0.008
        )
        head.position.y = s * 0.139
        piece.addChild(head)

        switch kind {
        case .knight:
            let helmet = World3DRenderResources.makeBox(
                size: SIMD3<Float>(0.050, 0.020, 0.050) * s,
                material: matte(palette.paleStone, roughness: 0.60),
                cornerRadius: s * 0.006
            )
            helmet.position.y = s * 0.166
            piece.addChild(helmet)

            let shield = World3DRenderResources.makeBox(
                size: SIMD3<Float>(0.014, 0.058, 0.046) * s,
                material: matte(palette.warmGold, roughness: 0.70),
                cornerRadius: s * 0.010
            )
            shield.position = SIMD3<Float>(0.048, 0.072, 0) * s
            piece.addChild(shield)
        case .archer:
            let bow = World3DRenderResources.makeBox(
                size: SIMD3<Float>(0.010, 0.105, 0.014) * s,
                material: matte(palette.bark, roughness: 0.88),
                cornerRadius: s * 0.005
            )
            bow.position = SIMD3<Float>(-0.048, 0.082, 0.012) * s
            bow.orientation = simd_quatf(angle: 0.16, axis: SIMD3<Float>(0, 0, 1))
            piece.addChild(bow)

            let quiver = World3DRenderResources.makeBox(
                size: SIMD3<Float>(0.020, 0.055, 0.020) * s,
                material: matte(palette.darkTimber, roughness: 0.90),
                cornerRadius: s * 0.005
            )
            quiver.position = SIMD3<Float>(0.018, 0.095, -0.034) * s
            quiver.orientation = simd_quatf(angle: 0.20, axis: SIMD3<Float>(1, 0, 0))
            piece.addChild(quiver)
        }
        return piece
    }

    func angleDelta(_ value: Float) -> Float {
        var delta = value.truncatingRemainder(dividingBy: .pi * 2)
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }
        return delta
    }

    func makeBoat(scale: Float) -> Entity {
        let boat = Entity()
        // Hull and rig live on an inner bobber so the boat rocks gently
        // while the outer entity travels.
        let bobber = Entity()
        boat.addChild(bobber)

        let hull = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.16, tileSize * 0.055, tileSize * 0.38) * scale,
            material: matte(NSColor(red: 0.44, green: 0.31, blue: 0.22, alpha: 1), roughness: 0.86),
            cornerRadius: tileSize * 0.02 * scale
        )
        bobber.addChild(hull)

        let mast = World3DRenderResources.makeCylinder(
            radius: tileSize * 0.012 * scale,
            height: tileSize * 0.30 * scale,
            material: matte(NSColor(red: 0.42, green: 0.30, blue: 0.22, alpha: 1), roughness: 0.90)
        )
        mast.position.y = tileSize * 0.17 * scale
        bobber.addChild(mast)

        let sail = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.016, tileSize * 0.20, tileSize * 0.15) * scale,
            material: matte(NSColor(red: 0.94, green: 0.92, blue: 0.86, alpha: 1), roughness: 0.92),
            cornerRadius: tileSize * 0.008
        )
        sail.position = SIMD3<Float>(0, tileSize * 0.19, tileSize * 0.075) * scale
        bobber.addChild(sail)

        // Tiny blocky sailors standing in the hull; they ride the bobber, so
        // the existing bob animation is all the motion they need. The larger
        // trader gets a second crew member.
        let skin = NSColor(red: 0.91, green: 0.75, blue: 0.58, alpha: 1)
        var crewSpots: [(z: Float, tunic: NSColor)] = [
            (-0.11, NSColor(red: 0.36, green: 0.42, blue: 0.55, alpha: 1))
        ]
        if scale > 1.2 {
            crewSpots.append((0.14, NSColor(red: 0.56, green: 0.36, blue: 0.28, alpha: 1)))
        }
        for spot in crewSpots {
            let body = World3DRenderResources.makeBox(
                size: SIMD3<Float>(0.034, 0.052, 0.026) * (tileSize * scale),
                material: matte(spot.tunic, roughness: 0.88),
                cornerRadius: tileSize * 0.006 * scale
            )
            body.position = SIMD3<Float>(0, 0.054, spot.z) * (tileSize * scale)
            bobber.addChild(body)

            let head = World3DRenderResources.makeBox(
                size: SIMD3<Float>(repeating: 0.024) * (tileSize * scale),
                material: matte(skin, roughness: 0.88),
                cornerRadius: tileSize * 0.004 * scale
            )
            head.position = SIMD3<Float>(0, 0.092, spot.z) * (tileSize * scale)
            bobber.addChild(head)
        }

        addDriftAnimation(
            to: bobber,
            offset: SIMD3<Float>(0, 0.010 * scale, 0),
            duration: Double.random(in: 2.2...3.4)
        )
        return boat
    }

    // Placement settle: the tile eases down from slightly above with a soft
    // vertical squash, like a wooden piece pressed gently onto the board.
    func playSettleAnimation(on entity: Entity) {
        let settled = entity.transform
        var lifted = settled
        lifted.translation.y += tileSize * 0.14
        lifted.scale = SIMD3<Float>(0.92, 1.06, 0.92)
        entity.transform = lifted
        let animation = FromToByAnimation<Transform>(
            from: lifted,
            to: settled,
            duration: 0.45,
            timing: .easeOut,
            bindTarget: .transform
        )
        if let resource = try? AnimationResource.generate(with: animation) {
            entity.playAnimation(resource)
        } else {
            entity.transform = settled
        }
    }

    // Slow autoreversing drift; GPU-side, so no per-frame CPU work.
    func addDriftAnimation(to entity: Entity, offset: SIMD3<Float>, duration: TimeInterval) {
        var to = entity.transform
        to.translation += offset
        let animation = FromToByAnimation<Transform>(
            from: entity.transform,
            to: to,
            duration: duration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )
        if let resource = try? AnimationResource.generate(with: animation) {
            entity.playAnimation(resource.repeat())
        }
    }

}
