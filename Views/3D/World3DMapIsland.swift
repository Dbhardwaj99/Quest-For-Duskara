import RealityKit
import AppKit

extension World3DRenderer {
    /// A town at its native scale, ready to place in the shared archipelago.
    /// Uses the same seed, shoreline, terrain, districts, and paths as town view.
    func makeMapIsland(town: Town, gridSize: GridSize) -> Entity {
        self.gridSize = gridSize
        terrainSeed = World3DOcean.seed(for: town.id)
        pathSignature = ""

        let root = Entity()
        root.name = "world3d_map_island_\(town.id.uuidString)"
        addGroundPlate(for: gridSize, seed: terrainSeed)
        addIslandAccents(for: town, gridSize: gridSize, seed: terrainSeed)
        World3DMeshBatcher.flatten(staticRoot)
        updateSettlementPaths(town: town)
        for child in Array(staticRoot.children) + Array(pathRoot.children) {
            root.addChild(child)
        }

        for y in 0..<gridSize.rows {
            for x in 0..<gridSize.columns {
                let coordinate = GridCoordinate(x: x, y: y)
                let building = town.buildings.first { $0.coordinate == coordinate }
                let snapshot = World3DTileSnapshot(
                    coordinate: coordinate,
                    content: building.map { .building($0.kind, level: $0.level) } ?? .grass,
                    placementState: .normal
                )
                let tilePosition = position(for: coordinate)
                let elevation = tileElevation(for: coordinate)
                let tile = World3DTileEntity.makeTile(
                    snapshot: snapshot, tileSize: tileSize, gridSize: gridSize,
                    townID: town.id,
                    elevationAt: { offset in
                        self.groundHeight(at: SIMD2<Float>(tilePosition.x, tilePosition.z) + offset) - elevation
                    }
                )
                World3DMeshBatcher.flatten(tile)
                tile.position = tilePosition + SIMD3<Float>(0, elevation, 0)
                root.addChild(tile)
            }
        }
        addMapPennant(to: root, faction: town.faction)
        #if DEBUG
        assert(staticRoot.children.isEmpty && pathRoot.children.isEmpty,
               "Map island must own all its terrain and paths")
        assert(root.children.filter { $0.name.hasPrefix("world3d_tile_") }.count == gridSize.columns * gridSize.rows,
               "Map island must preserve every town plot")
        #endif
        return root
    }

    private func addMapPennant(to island: Entity, faction: TownFaction) {
        let color: NSColor = switch faction {
        case .player: NSColor(red: 0.28, green: 0.72, blue: 0.38, alpha: 1)
        case .neutral: NSColor(red: 0.85, green: 0.76, blue: 0.55, alpha: 1)
        case .enemy: NSColor(red: 0.80, green: 0.30, blue: 0.24, alpha: 1)
        case .duskara: NSColor(red: 0.48, green: 0.35, blue: 0.72, alpha: 1)
        }
        let halfExtents = SIMD2<Float>(terrainWidth(for: gridSize) / 2, terrainDepth(for: gridSize) / 2)
        let angle: Float = -0.55
        let radius = World3DOcean.coastRadius(angle: angle, islandHalfExtents: halfExtents,
                                             tileSize: tileSize, seed: terrainSeed) - tileSize * 0.37
        let point = SIMD2<Float>(sin(angle), cos(angle)) * radius
        let pennant = Entity()
        pennant.position = SIMD3<Float>(point.x, groundHeight(at: point), point.y)
        island.addChild(pennant)
        let height = tileSize * 0.83
        let pole = World3DRenderResources.makeCylinder(radius: tileSize * 0.018, height: height,
                                                       material: matte(palette.darkTimber, roughness: 0.9))
        pole.position.y = height / 2
        pennant.addChild(pole)
        var flag = MeshDescriptor(name: "world3d_map_pennant")
        flag.positions = MeshBuffer([
            SIMD3<Float>(0, height * 0.96, 0),
            SIMD3<Float>(tileSize * 0.42, height * 0.78, 0),
            SIMD3<Float>(0, height * 0.61, 0)
        ])
        flag.normals = MeshBuffer(Array(repeating: SIMD3<Float>(0, 0, 1), count: 3))
        flag.primitives = .triangles([0, 1, 2, 2, 1, 0])
        if let mesh = try? MeshResource.generate(from: [flag]) {
            pennant.addChild(ModelEntity(mesh: mesh, materials: [matte(color, roughness: 0.95)]))
        }
        World3DMeshBatcher.flatten(pennant)
    }
}
