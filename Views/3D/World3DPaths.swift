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
        plaza.position.y = 0.010
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
        let path = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.08, 0.006, length + tileSize * 0.08),
            material: material,
            cornerRadius: tileSize * 0.025
        )
        path.position = SIMD3<Float>((start.x + end.x) / 2, 0.008, (start.y + end.y) / 2)
        path.orientation = simd_quatf(angle: atan2(delta.x, delta.y), axis: SIMD3<Float>(0, 1, 0))
        pathRoot.addChild(path)
    }
}
