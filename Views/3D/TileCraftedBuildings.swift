import RealityKit
import AppKit


extension World3DTileEntity {
    static func addBuilding(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) {
        // Handcrafted Blender models (Assets/building_*.usdz) are the primary
        // visuals; the procedural builders below stay as a fallback so a
        // missing or broken asset can never leave an empty tile.
        if let crafted = makeCraftedBuilding(kind, tileSize: tileSize, coordinate: coordinate, gridSize: gridSize) {
            if kind != .pier {
                addGroundPatch(
                    to: root,
                    tileSize: tileSize,
                    center: SIMD2<Float>(jitter(coordinate, salt: 211) * 0.02, jitter(coordinate, salt: 212) * 0.02),
                    size: SIMD2<Float>(0.82, 0.76),
                    color: Palette.walkedDirt,
                    rotation: jitter(coordinate, salt: 213) * 0.35
                )
            }
            root.addChild(crafted)
            addLevelPips(level, to: root, tileSize: tileSize)
            return
        }

        // The pier is shoreline furniture, not a plinth building: it lays its
        // own boardwalk instead of the stone platform.
        guard kind != .pier else {
            addPier(level: level, to: root, tileSize: tileSize, coordinate: coordinate, gridSize: gridSize)
            return
        }

        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(jitter(coordinate, salt: 211) * 0.025, jitter(coordinate, salt: 212) * 0.025),
            size: SIMD2<Float>(0.76, 0.68),
            color: Palette.walkedDirt,
            rotation: jitter(coordinate, salt: 213) * 0.35
		)

        let plinth = addBox(
            to: root,
            size: SIMD3<Float>(0.68, 0.045, 0.62) * tileSize,
            position: SIMD3<Float>(jitter(coordinate, salt: 214) * 0.018, 0.022, jitter(coordinate, salt: 215) * 0.018) * tileSize,
            color: Palette.plinthStone,
            roughness: 0.92,
            cornerRadius: tileSize * 0.025
        )
        plinth.orientation = simd_quatf(angle: jitter(coordinate, salt: 216) * 0.08, axis: SIMD3<Float>(0, 1, 0))

        switch kind {
        case .house:
            addHouse(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .pier:
            break
        case .farm:
            addFarm(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .factory:
            addFactory(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .barracks:
            addBarracks(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        }

        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 3, around: SIMD2<Float>(0, 0), radius: 0.43)
    }

    static func makeCraftedBuilding(_ kind: BuildingKind, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) -> Entity? {
        guard let building = try? Entity.load(named: "building_\(kind.rawValue)") else { return nil }
        building.scale = SIMD3<Float>(repeating: tileSize * 0.7)
        applyCraftedPalette(to: building)
        playCraftedAnimations(in: building)
        if kind == .pier {
            let yaw = shorelineYaw(for: coordinate, gridSize: gridSize)
            // The authored pier's deck extends along its local -z axis, the
            // opposite of the procedural dock. Turn it around before moving
            // its anchor to the shoreline so the whole deck projects seaward.
            building.orientation = simd_quatf(angle: yaw + .pi, axis: SIMD3<Float>(0, 1, 0))
            building.position = SIMD3<Float>(sin(yaw), 0, cos(yaw)) * (tileSize * 0.5)
        }
        return building
    }

    static func applyCraftedPalette(to building: Entity) {
        func recolor(_ entity: Entity, inheritedColor: NSColor) {
            let color = craftedColor(for: entity.name, fallback: inheritedColor)
            if var model = entity.components[ModelComponent.self] {
                model.materials = model.materials.map { _ in material(color, roughness: 0.88) }
                entity.components.set(model)
            }
            entity.children.forEach { recolor($0, inheritedColor: color) }
        }

        recolor(building, inheritedColor: Palette.plaster)
    }

    static func craftedColor(for name: String, fallback: NSColor) -> NSColor {
        let name = name.lowercased()
        if name.contains("glow") || name.contains("lantern") || name.contains("gold") { return Palette.warmGold }
        if name.contains("straw") || name.contains("hay") { return Palette.strawRoof }
        if name.contains("slate") || name.contains("vault") || name.contains("keep_roof") { return Palette.slateRoof }
        if name.contains("terracotta") || name.contains("dusty") || name.contains("roof") || name.contains("shutter") { return Palette.terracotta }
        if name.contains("teal") || name.contains("workshop") { return Palette.labStone }
        if name.contains("fortified") || name.contains("keep") { return Palette.fortifiedClay }
        if name.contains("crop") || name.contains("field") || name.contains("plant") || name.contains("sage") { return Palette.cropGreen }
        if name.contains("timber") || name.contains("wood") || name.contains("plank") || name.contains("barrel") || name.contains("crate") || name.contains("rail") { return Palette.timber }
        if name.contains("stone") || name.contains("plinth") || name.contains("step") || name.contains("wall") { return Palette.plinthStone }
        if name.contains("plaster") || name.contains("cream") { return Palette.plaster }
        return fallback
    }

    static func playCraftedAnimations(in entity: Entity) {
        entity.availableAnimations.forEach { entity.playAnimation($0.repeat()) }
        entity.children.forEach { playCraftedAnimations(in: $0) }
    }

}
