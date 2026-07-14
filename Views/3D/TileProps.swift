import RealityKit
import AppKit


extension World3DTileEntity {
    static func addThemeGroundDecor(to root: Entity, tileSize: Float, coordinate: GridCoordinate, around: SIMD2<Float>) {
        switch WorldTheme.current {
        case .desert:
            let x = around.x + jitter(coordinate, salt: 961) * 0.08
            let z = around.y + jitter(coordinate, salt: 967) * 0.08
            guard abs(x) < 0.44, abs(z) < 0.44 else { return }
            addCactus(to: root, tileSize: tileSize, coordinate: coordinate, position: SIMD2<Float>(x, z), salt: 968)
        case .mountains:
            // Snow patches instead of mushrooms.
            for index in 0..<2 {
                let x = around.x + jitter(coordinate, salt: 961 + index) * 0.10
                let z = around.y + jitter(coordinate, salt: 967 + index) * 0.10
                guard abs(x) < 0.44, abs(z) < 0.44 else { continue }
                addGroundPatch(
                    to: root,
                    tileSize: tileSize,
                    center: SIMD2<Float>(x, z),
                    size: SIMD2<Float>(0.14, 0.10),
                    color: Palette.peakCap,
                    rotation: randomAngle(coordinate, salt: 971 + index)
                )
            }
        case .village, .forest:
            for index in 0..<3 {
                let x = around.x + jitter(coordinate, salt: 961 + index) * 0.08
                let z = around.y + jitter(coordinate, salt: 967 + index) * 0.08
                guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
                addCylinder(to: root, radius: 0.011 * tileSize, height: 0.045 * tileSize, position: SIMD3<Float>(x, 0.034, z) * tileSize, color: Palette.plaster, roughness: 0.88)
                addCone(to: root, radius: 0.026 * tileSize, height: 0.032 * tileSize, position: SIMD3<Float>(x, 0.068, z) * tileSize, color: Palette.mushroomCap, roughness: 0.82)
            }
        }
    }

    static func addLeafScatter(to root: Entity, tileSize: Float, coordinate: GridCoordinate, around: SIMD2<Float>) {
        for index in 0..<detailCount(5, minimum: 2) {
            let x = around.x + jitter(coordinate, salt: 971 + index) * 0.28
            let z = around.y + jitter(coordinate, salt: 977 + index) * 0.28
            guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
            let leaf = addBox(to: root, size: SIMD3<Float>(0.040, 0.007, 0.022) * tileSize, position: SIMD3<Float>(x, 0.017, z) * tileSize, color: index.isMultiple(of: 2) ? Palette.leafHighlight : Palette.forestDeep, roughness: 0.95, cornerRadius: tileSize * 0.004)
            leaf.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 981 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    static func addTimberFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float, color: NSColor) {
        let z = center.z
        let postHeight = height
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x - width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x + width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.42, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width * 0.78, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y - height * 0.30, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        let diagonal = addBox(to: root, size: SIMD3<Float>(0.024, height * 0.72, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.02, z + 0.002) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        diagonal.orientation = simd_quatf(angle: 0.55, axis: SIMD3<Float>(0, 0, 1))
    }

    /// Two posts + lintel around a door opening on a z-facing wall.
    static func addDoorFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float) {
        for side: Float in [-1, 1] {
            addBox(to: root, size: SIMD3<Float>(0.028, height + 0.02, 0.030) * tileSize, position: SIMD3<Float>(center.x + side * (width * 0.5 + 0.016), center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
        }
        addBox(to: root, size: SIMD3<Float>(width + 0.09, 0.028, 0.030) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.5 + 0.014, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
    }

    /// Pane + posts + sill; `sideways` puts the pane on an x-facing wall.
    static func addWindowFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float, sideways: Bool = false) {
        let paneSize = sideways ? SIMD3<Float>(0.032, height, width) : SIMD3<Float>(width, height, 0.032)
        addBox(to: root, size: paneSize * tileSize, position: center * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.004)
        let lateral: SIMD3<Float> = sideways ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
        for side: Float in [-1, 1] {
            addBox(to: root, size: SIMD3<Float>(0.024, height + 0.03, 0.024) * tileSize, position: (center + lateral * (side * (width * 0.5 + 0.014))) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.003)
        }
        let sillSize = sideways ? SIMD3<Float>(0.034, 0.022, width + 0.07) : SIMD3<Float>(width + 0.07, 0.022, 0.034)
        addBox(to: root, size: sillSize * tileSize, position: SIMD3<Float>(center.x, center.y - height * 0.5 - 0.012, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
    }

    /// Two stacked stone slabs forming a stoop in front of a door.
    static func addEntryStep(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float) {
        addBox(to: root, size: SIMD3<Float>(width, 0.030, 0.10) * tileSize, position: center * tileSize, color: Palette.plinthStone, roughness: 0.94, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(width * 0.78, 0.028, 0.062) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.026, center.z - 0.022) * tileSize, color: Palette.warmStone, roughness: 0.94, cornerRadius: tileSize * 0.006)
    }

    /// Beam running the roof peak along x.
    static func addRidgeBeam(to root: Entity, tileSize: Float, center: SIMD3<Float>, length: Float, color: NSColor, orientation: simd_quatf? = nil) {
        let beam = addBox(to: root, size: SIMD3<Float>(length, 0.034, 0.050) * tileSize, position: center * tileSize, color: color, roughness: 0.88, cornerRadius: tileSize * 0.008)
        if let orientation { beam.orientation = orientation }
    }

    /// Thin strips under the front/back roof overhangs.
    static func addEaveStrips(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, depth: Float, orientation: simd_quatf? = nil) {
        for side: Float in [-1, 1] {
            let eave = addBox(to: root, size: SIMD3<Float>(width, 0.024, 0.032) * tileSize, position: SIMD3<Float>(center.x, center.y, center.z + side * depth * 0.5) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
            if let orientation { eave.orientation = orientation }
        }
    }

    static func addShutters(to root: Entity, tileSize: Float, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.026, 0.14, 0.024) * tileSize, position: SIMD3<Float>(center.x - 0.078, center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.88, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(0.026, 0.14, 0.024) * tileSize, position: SIMD3<Float>(center.x + 0.078, center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.88, cornerRadius: tileSize * 0.003)
    }

    static func addLantern(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        addBox(to: root, size: SIMD3<Float>(0.020, 0.070, 0.020) * tileSize, position: position * tileSize, color: Palette.darkTimber, roughness: 0.84, cornerRadius: tileSize * 0.003)
        let glow = addBox(to: root, size: SIMD3<Float>(0.055, 0.060, 0.042) * tileSize, position: SIMD3<Float>(position.x, position.y - 0.055, position.z) * tileSize, color: Palette.lanternGlow, roughness: 0.36, cornerRadius: tileSize * 0.010)
        glow.orientation = simd_quatf(angle: jitter(coordinate, salt: salt) * 0.12, axis: SIMD3<Float>(0, 1, 0))
    }

    static func addCrate(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        let crate = addBox(to: root, size: SIMD3<Float>(0.105, 0.095, 0.105) * tileSize, position: position * tileSize, color: Palette.cutWood, roughness: 0.90, cornerRadius: tileSize * 0.008)
        crate.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.118, 0.018, 0.018) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.008, position.z) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.002)
    }

    static func addSack(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        let sack = addBox(to: root, size: SIMD3<Float>(0.11, 0.09, 0.095) * tileSize, position: position * tileSize, color: Palette.sackCloth, roughness: 0.95, cornerRadius: tileSize * 0.020)
        sack.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.055, 0.018, 0.055) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.055, position.z) * tileSize, color: Palette.railWood, roughness: 0.9, cornerRadius: tileSize * 0.004)
    }

    static func addScarecrow(to root: Entity, tileSize: Float, coordinate: GridCoordinate, position: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.026, 0.25, 0.026) * tileSize, position: position * tileSize, color: Palette.railWood, roughness: 0.90, cornerRadius: tileSize * 0.003)
        let arm = addBox(to: root, size: SIMD3<Float>(0.20, 0.024, 0.024) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.08, position.z) * tileSize, color: Palette.railWood, roughness: 0.90, cornerRadius: tileSize * 0.003)
        arm.orientation = simd_quatf(angle: jitter(coordinate, salt: 1021) * 0.08, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.085, 0.07, 0.030) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.105, position.z + 0.010) * tileSize, color: Palette.bannerRed, roughness: 0.82, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.095, 0.026, 0.070) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.165, position.z) * tileSize, color: Palette.strawRoof, roughness: 0.94, cornerRadius: tileSize * 0.006)
    }

    static func addCart(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        let tray = addBox(to: root, size: SIMD3<Float>(0.20, 0.070, 0.13) * tileSize, position: center * tileSize, color: Palette.barnWood, roughness: 0.88, cornerRadius: tileSize * 0.008)
        tray.orientation = simd_quatf(angle: jitter(coordinate, salt: 1031) * 0.18, axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.035, 0.060, 0.035) * tileSize, position: SIMD3<Float>(center.x - 0.085, center.y - 0.020, center.z + 0.075) * tileSize, color: Palette.darkTimber, roughness: 0.90, cornerRadius: tileSize * 0.010)
        addBox(to: root, size: SIMD3<Float>(0.035, 0.060, 0.035) * tileSize, position: SIMD3<Float>(center.x + 0.085, center.y - 0.020, center.z + 0.075) * tileSize, color: Palette.darkTimber, roughness: 0.90, cornerRadius: tileSize * 0.010)
    }

    static func addShieldRack(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.025, 0.24, 0.030) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.003)
        for index in 0..<2 {
            let shield = addBox(to: root, size: SIMD3<Float>(0.075, 0.095, 0.025) * tileSize, position: SIMD3<Float>(center.x + Float(index) * 0.075, center.y + 0.04, center.z) * tileSize, color: index.isMultiple(of: 2) ? Palette.bannerRed : Palette.warmGold, roughness: 0.70, cornerRadius: tileSize * 0.014)
            shield.orientation = simd_quatf(angle: jitter(coordinate, salt: 1091 + index) * 0.08, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    static func addFirePit(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(center.x, center.z), radius: 0.055, count: 5, scale: 0.35)
        addBox(to: root, size: SIMD3<Float>(0.060, 0.080, 0.040) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.06, center.z) * tileSize, color: Palette.lanternGlow, roughness: 0.38, cornerRadius: tileSize * 0.010)
        let flame = addBox(to: root, size: SIMD3<Float>(0.035, 0.11, 0.035) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.10, center.z) * tileSize, color: Palette.bannerRed, roughness: 0.58, cornerRadius: tileSize * 0.008)
        flame.orientation = simd_quatf(angle: 0.32 + jitter(coordinate, salt: 1101) * 0.08, axis: SIMD3<Float>(0, 0, 1))
    }

}
