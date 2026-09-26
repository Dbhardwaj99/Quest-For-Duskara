import RealityKit
import AppKit

extension World3DRenderer {
    func updateSettlementPaths(town: Town) {
        let signature = town.buildings
            .map { "\($0.coordinate.x),\($0.coordinate.y),\($0.kind.rawValue)" }
            .sorted().joined(separator: "|")
        guard signature != pathSignature else { return }
        pathSignature = signature
        pathRoot.children.forEach { $0.removeFromParent() }

        let material = matte(blend(palette.walkedDirt, with: palette.tileGround, amount: 0.24), roughness: 0.98)
        let plaza = World3DRenderResources.makeSphere(
            radius: tileSize * 0.17,
            material: material,
            scale: SIMD3<Float>(1.3, 0.025, 1.1)
        )
        plaza.position.y = groundHeight(at: .zero) + 0.010
        pathRoot.addChild(plaza)

        for building in town.buildings {
            let end = position(for: building.coordinate)
            guard simd_length(SIMD2<Float>(end.x, end.z)) > 0.001 else { continue }
            let coordinate = building.coordinate
            let bend = (Float(stablePercent(coordinate, salt: 1681) - 50) / 50) * tileSize * 0.11
            let length = simd_length(SIMD2<Float>(end.x, end.z))
            let mid = SIMD2<Float>(end.x, end.z) * 0.52
                + SIMD2<Float>(-end.z, end.x) / length * bend
            addPathSegment(from: .zero, to: mid, material: material)
            addPathSegment(from: mid, to: SIMD2<Float>(end.x, end.z), material: material)
        }
        World3DMeshBatcher.flatten(pathRoot)
    }

    private func addPathSegment(from start: SIMD2<Float>, to end: SIMD2<Float>, material: SimpleMaterial) {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.01 else { return }
        let side = SIMD2<Float>(-delta.y, delta.x) / length * (tileSize * 0.045)
        let steps = max(2, Int(ceil(length / (tileSize * 0.25))))
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for index in 0...steps {
            let point = start + delta * (Float(index) / Float(steps))
            for edge in [point + side, point - side] {
                positions.append(SIMD3<Float>(edge.x, groundHeight(at: edge) + 0.007, edge.y))
            }
            if index < steps {
                let i = UInt32(index * 2)
                indices.append(contentsOf: [i, i + 2, i + 1, i + 1, i + 2, i + 3])
            }
        }
        var mesh = MeshDescriptor(name: "world3d_terrain_path")
        mesh.positions = MeshBuffer(positions)
        mesh.normals = MeshBuffer(Array(repeating: SIMD3<Float>(0, 1, 0), count: positions.count))
        mesh.primitives = .triangles(indices)
        pathRoot.addChild(ModelEntity(mesh: try! MeshResource.generate(from: [mesh]), materials: [material]))
    }
}
