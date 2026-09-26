import RealityKit
import Foundation
import AppKit

extension World3DTileEntity {
    private struct Piece {
        let asset: String
        let x: Float
        let z: Float
        let size: Float
        let appearsAt: Int

        init(_ asset: String, _ x: Float, _ z: Float, _ size: Float, _ appearsAt: Int = 1) {
            self.asset = asset
            self.x = x
            self.z = z
            self.size = size
            self.appearsAt = appearsAt
        }
    }

    static var settlementTemplates: [String: Entity] = [:]

    static func makeSettlementDistrict(
        _ kind: BuildingKind, level: Int, tileSize: Float,
        coordinate: GridCoordinate, gridSize: GridSize, townID: UUID,
        elevationAt: (SIMD2<Float>) -> Float
    ) -> Entity? {
        let pieces = districtPieces(for: kind).filter { $0.appearsAt <= level }
        let root = Entity()
        root.name = "world3d_district_\(kind.rawValue)"
        root.scale = SIMD3<Float>(repeating: BuildingScale.scale(for: kind) / BuildingScale.standard(for: kind))

        let townSeed = World3DOcean.seed(for: townID)
        for (index, piece) in pieces.enumerated() {
            guard let model = settlementModel(piece.asset) else { return nil }
            tintRoof(in: model, kind: kind, level: level)
            let seedCoordinate = GridCoordinate(x: coordinate.x + townSeed % 4093, y: coordinate.y + index * 13)
            let dx = jitter(seedCoordinate, salt: 1301) * 0.025
            let dz = jitter(seedCoordinate, salt: 1309) * 0.025
            let center = SIMD2<Float>((piece.x + dx) * tileSize, (piece.z + dz) * tileSize)
            let elevation = kind == .pier ? 0 : elevationAt(center)
            if piece.asset != "jetty" {
                let foundation = World3DRenderResources.makeCylinder(
                    radius: piece.size * tileSize * 0.76,
                    height: tileSize * 0.055,
                    material: material(Palette.plinthStone, roughness: 0.96)
                )
                foundation.position = SIMD3<Float>(center.x, elevation - tileSize * 0.005, center.y)
                root.addChild(foundation)
                let pad = makeGroundPad(kind: kind, radius: piece.size * tileSize,
                                        coordinate: seedCoordinate)
                pad.position = SIMD3<Float>(center.x, elevation + tileSize * 0.019, center.y)
                root.addChild(pad)
            }
            model.position = SIMD3<Float>(center.x, piece.asset == "jetty" ? 0 : elevation + tileSize * 0.025, center.y)
            model.scale = SIMD3<Float>(repeating: piece.size * tileSize * 1.15)
            let yaw = kind == .pier
                ? (piece.asset == "jetty" ? Float.pi : 0)
                : atan2(piece.x, piece.z) + jitter(seedCoordinate, salt: 1321) * 0.15
            model.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(model)
        }

        if kind == .pier {
            let yaw = shorelineYaw(for: coordinate, gridSize: gridSize)
            root.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            root.position = SIMD3<Float>(sin(yaw), 0, cos(yaw)) * (tileSize * 0.50)
        }
        addDistrictProps(kind, level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        return root
    }

    private static func districtPieces(for kind: BuildingKind) -> [Piece] {
        switch kind {
        case .house:
            [Piece("cottage_a", -0.24, -0.18, 0.25),
             Piece("cottage_b", 0.23, 0.19, 0.24),
             Piece("shed", -0.02, 0.39, 0.17),
             Piece("townhouse", -0.25, 0.18, 0.23, 2),
             Piece("cottage_a", 0.24, -0.20, 0.24, 2),
             Piece("townhouse", -0.02, -0.39, 0.28, 3),
             Piece("cottage_a", 0.41, 0.40, 0.22, 3)]
        case .farm:
            [Piece("farmstead", 0.27, -0.24, 0.25),
             Piece("shed", -0.35, -0.32, 0.18),
             Piece("barn", 0.28, 0.25, 0.27, 2),
             Piece("granary", -0.30, 0.31, 0.23, 3)]
        case .factory:
            [Piece("workshop", -0.28, -0.28, 0.29),
             Piece("forge", 0.30, -0.30, 0.19),
             Piece("warehouse", 0.30, 0.26, 0.25, 2),
             Piece("foundry", -0.28, 0.28, 0.26, 3)]
        case .barracks:
            [Piece("barracks_hut", -0.30, -0.28, 0.29),
             Piece("armory", 0.30, -0.30, 0.20),
             Piece("barracks_hut", 0.28, 0.26, 0.27, 2),
             Piece("watchtower", -0.30, 0.29, 0.25, 3)]
        case .pier:
            [Piece("jetty", 0, 0.34, 0.44),
             Piece("boathouse", -0.32, -0.33, 0.22),
             Piece("harbor_store", 0.28, -0.32, 0.23, 2),
             Piece("jetty", -0.28, 0.45, 0.31, 3),
             Piece("beacon", -0.33, 0.13, 0.20, 3)]
        }
    }

    private static func settlementModel(_ name: String) -> Entity? {
        let key = "\(name)|\(WorldTheme.current.rawValue)|\(WorldContrast.level)"
        if let cached = settlementTemplates[key] { return cached.clone(recursive: true) }
        guard let model = try? Entity.load(named: "settlement_\(name)") else { return nil }
        applyCraftedPalette(to: model)
        settlementTemplates[key] = model
        return model.clone(recursive: true)
    }

    private static func makeGroundPad(kind: BuildingKind, radius: Float, coordinate: GridCoordinate) -> Entity {
        let count = 12
        var positions = [SIMD3<Float>(0, 0.006, 0)]
        for index in 0..<count {
            let angle = Float(index) / Float(count) * .pi * 2
            let wobble = 1 + jitter(coordinate, salt: 1711 + index) * 0.08
            positions.append(SIMD3<Float>(sin(angle) * radius * 0.86 * wobble,
                                          0.006,
                                          cos(angle) * radius * 0.73 * wobble))
        }
        var indices: [UInt32] = []
        for index in 0..<count {
            indices.append(contentsOf: [0, UInt32(index + 1), UInt32((index + 1) % count + 1)])
        }
        var mesh = MeshDescriptor(name: "settlement_ground_pad")
        mesh.positions = MeshBuffer(positions)
        mesh.normals = MeshBuffer(Array(repeating: SIMD3<Float>(0, 1, 0), count: positions.count))
        mesh.primitives = .triangles(indices)
        let color: NSColor = switch kind {
        case .house, .pier: Palette.walkedDirt
        case .farm: Palette.fieldDirt
        case .factory: Palette.stoneDust
        case .barracks: Palette.plinthStone
        }
        return ModelEntity(mesh: try! MeshResource.generate(from: [mesh]),
                           materials: [material(color, roughness: 0.98)])
    }

    private static func tintRoof(in model: Entity, kind: BuildingKind, level: Int) {
        func visit(_ entity: Entity, inherited: NSColor?) {
            let roof = entity.name.lowercased().hasPrefix("roof")
                ? roofShade(kind: kind, level: level, materialName: entity.name.lowercased())
                : inherited
            if let roof, var part = entity.components[ModelComponent.self] {
                part.materials = part.materials.map { _ in material(roof, roughness: 0.88) }
                entity.components.set(part)
            }
            entity.children.forEach { visit($0, inherited: roof) }
        }
        visit(model, inherited: nil)
    }

    private static func roofShade(kind: BuildingKind, level: Int, materialName: String) -> NSColor? {
        let tier = min(3, max(1, level)) - 1
        switch materialName {
        case "roofclay":
            return [Palette.roofHighlight, Palette.terracotta, Palette.terracottaDark][tier]
        case "roofstraw":
            return [Palette.strawRoof, Palette.cropGold, Palette.strawShadow][tier]
        case "roofslate":
            switch kind {
            case .factory: return [Palette.slateRoof, Palette.arcaneBlue, Palette.deepStone][tier]
            case .barracks: return [Palette.slateRoof, Palette.deepStone, Palette.terracottaDark][tier]
            case .pier: return [Palette.waterOpen, Palette.arcaneBlue, Palette.deepStone][tier]
            case .house, .farm: return [Palette.slateRoof, Palette.deepStone, Palette.arcaneBlue][tier]
            }
        default:
            return nil
        }
    }

    private static func addDistrictProps(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        switch kind {
        case .house:
            addLantern(to: root, tileSize: tileSize, position: SIMD3<Float>(0, 0.08, 0), coordinate: coordinate, salt: 1451)
            if level >= 2 {
                addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.39, 0.37), count: 5, horizontal: true)
            }
        case .farm:
            for row in 0..<(2 + level * 2) {
                let z = -0.17 + Float(row) * 0.05
                let crop = addBox(to: root,
                    size: SIMD3<Float>(0.28, 0.055, 0.038) * tileSize,
                    position: SIMD3<Float>(-0.04, 0.03, z) * tileSize,
                    color: row.isMultiple(of: 2) ? Palette.cropGold : Palette.cropGreen,
                    roughness: 0.95, cornerRadius: tileSize * 0.015)
                crop.orientation = simd_quatf(angle: jitter(coordinate, salt: 1401 + row) * 0.09, axis: SIMD3<Float>(0, 1, 0))
            }
            if level == 3 { addSheep(to: root, tileSize: tileSize, at: SIMD2<Float>(0.29, 0.37), wander: SIMD2<Float>(0.07, 0), duration: 8, yaw: 0.4) }
        case .factory:
            addCrate(to: root, tileSize: tileSize, position: SIMD3<Float>(0.03, 0.05, -0.35), coordinate: coordinate, salt: 1421)
            if level >= 2 { addChimneySmoke(to: root, tileSize: tileSize, above: SIMD3<Float>(0.22, 0.42, 0.12)) }
        case .barracks:
            let yard = Entity()
            yard.position = SIMD3<Float>(0.32, 0, -0.23) * tileSize
            root.addChild(yard)
            addTrainingProps(to: yard, tileSize: tileSize, coordinate: coordinate)
            if level >= 2 { addBanner(to: root, tileSize: tileSize, coordinate: coordinate, polePosition: SIMD3<Float>(0.3, 0.20, -0.30), side: 1) }
        case .pier:
            addBarrel(to: root, tileSize: tileSize, position: SIMD3<Float>(0.26, 0.06, -0.28), salt: 1431, coordinate: coordinate)
            if level >= 2 { addCrate(to: root, tileSize: tileSize, position: SIMD3<Float>(0.06, 0.06, -0.32), coordinate: coordinate, salt: 1439) }
        }
    }
}
