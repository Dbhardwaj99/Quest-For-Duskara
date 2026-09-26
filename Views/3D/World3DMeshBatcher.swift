import RealityKit
import AppKit

/// Collapses a subtree's static decoration into one multi-part mesh: the same
/// triangles and materials, drawn as one entity with a part per material
/// instead of hundreds of tiny ModelEntities. RealityKit's per-frame work
/// scales with entity count, and grass tufts, pebbles and leaves dominated it.
///
/// Boundaries: an entity named `world3d_…` is batched on its own, its merged
/// mesh parented under it so moving or rescaling it still works. Anything
/// named `animatedName`, or carrying authored animations, is left untouched.
@MainActor
enum World3DMeshBatcher {
    /// Name for entities whose transform animates (drift, orbit, cruise).
    static let animatedName = "world3d_animated"

    private struct Geometry {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
    }

    private struct MaterialKey: Hashable {
        let tint: SIMD4<Float>
        let roughness: MaterialScalarParameter
        let metallic: MaterialScalarParameter
    }

    private struct Batch {
        var keys: [MaterialKey] = []
        var buckets: [MaterialKey: (material: SimpleMaterial, geometry: Geometry)] = [:]
        var merged: [Entity] = []
        var meshes: [ObjectIdentifier: (mesh: MeshResource, parts: [(materialIndex: Int, geometry: Geometry)]?)] = [:]
    }

    static func flatten(_ root: Entity) {
        var batch = Batch()
        collect(from: root, root: root, into: &batch)
        // One entity gains nothing from merging.
        guard batch.merged.count > 1 else { return }

        var descriptors: [MeshDescriptor] = []
        var materials: [any RealityKit.Material] = []
        for key in batch.keys {
            guard let bucket = batch.buckets[key] else { continue }
            var descriptor = MeshDescriptor(name: "world3d_batch")
            descriptor.positions = MeshBuffer(bucket.geometry.positions)
            descriptor.normals = MeshBuffer(bucket.geometry.normals)
            descriptor.primitives = .triangles(bucket.geometry.indices)
            descriptor.materials = .allFaces(UInt32(materials.count))
            descriptors.append(descriptor)
            materials.append(bucket.material)
        }
        // On failure the scene just stays unbatched.
        guard let mesh = try? MeshResource.generate(from: descriptors) else { return }
        let merged = ModelEntity(mesh: mesh, materials: materials)
        root.addChild(merged)
        #if DEBUG
        // Self-check: merging must not move geometry. Per-entity bounds of
        // rotated pieces are loose boxes, so the merged (tight) box must sit
        // inside their union without collapsing.
        let expected = batch.merged.dropFirst().reduce(batch.merged[0].visualBounds(recursive: false, relativeTo: root)) {
            $0.union($1.visualBounds(recursive: false, relativeTo: root))
        }
        let actual = merged.visualBounds(recursive: false, relativeTo: root)
        let slack = SIMD3<Float>(repeating: 1e-3)
        assert(all(actual.min .>= expected.min - slack) && all(actual.max .<= expected.max + slack)
               && all(actual.extents .>= expected.extents * 0.5),
               "World3DMeshBatcher moved geometry: \(expected) vs \(actual)")
        #endif
        for entity in batch.merged {
            entity.components.remove(ModelComponent.self)
        }
        prune(root)
    }

    private static func collect(from entity: Entity, root: Entity, into batch: inout Batch) {
        for child in entity.children {
            if child.name == animatedName || child.availableAnimations.isEmpty == false { continue }
            if child.name.hasPrefix("world3d_") {
                flatten(child)
                continue
            }
            if child.isEnabled, let model = child.components[ModelComponent.self] {
                append(model, of: child, root: root, into: &batch)
            }
            collect(from: child, root: root, into: &batch)
        }
    }

    private static func append(_ model: ModelComponent, of entity: Entity, root: Entity, into batch: inout Batch) {
        // Opaque, untextured SimpleMaterials only: transparent parts need
        // per-entity sorting, and anything else (the ocean) has its own shader.
        var materials: [(key: MaterialKey, material: SimpleMaterial)] = []
        for case let material as SimpleMaterial in model.materials {
            guard material.color.texture == nil,
                  let tint = material.color.tint.usingColorSpace(.deviceRGB),
                  tint.alphaComponent >= 1 else { return }
            let rgba = SIMD4<Float>(Float(tint.redComponent), Float(tint.greenComponent), Float(tint.blueComponent), 1)
            materials.append((MaterialKey(tint: rgba, roughness: material.roughness, metallic: material.metallic), material))
        }
        guard materials.isEmpty == false, materials.count == model.materials.count else { return }

        let id = ObjectIdentifier(model.mesh)
        if batch.meshes[id] == nil {
            batch.meshes[id] = (model.mesh, parts(of: model.mesh))
        }
        guard let parts = batch.meshes[id]?.parts else { return }

        let transform = entity.transformMatrix(relativeTo: root)
        let linear = simd_float3x3(
            SIMD3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z),
            SIMD3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z),
            SIMD3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        )
        let determinant = linear.determinant
        guard abs(determinant) > 1e-12 else { return }
        // Non-uniform scale (every box here) needs the inverse transpose.
        let normalMatrix = linear.inverse.transpose
        let mirrored = determinant < 0

        for (materialIndex, geometry) in parts {
            let (key, material) = materials[min(materialIndex, materials.count - 1)]
            if batch.buckets[key] == nil {
                batch.buckets[key] = (material, Geometry())
                batch.keys.append(key)
            }
            var bucket = batch.buckets[key]!.geometry
            let base = UInt32(bucket.positions.count)
            for position in geometry.positions {
                let world = transform * SIMD4<Float>(position, 1)
                bucket.positions.append(SIMD3(world.x, world.y, world.z))
            }
            for normal in geometry.normals {
                bucket.normals.append(simd_normalize(normalMatrix * normal))
            }
            for triangle in stride(from: 0, to: geometry.indices.count - 2, by: 3) {
                let a = geometry.indices[triangle], b = geometry.indices[triangle + 1], c = geometry.indices[triangle + 2]
                bucket.indices.append(contentsOf: mirrored ? [base + a, base + c, base + b] : [base + a, base + b, base + c])
            }
            batch.buckets[key]!.geometry = bucket
        }
        batch.merged.append(entity)
    }

    /// Every part of the mesh in its own space, or nil if any part is in a
    /// layout this doesn't handle (then the entity just isn't merged).
    private static func parts(of mesh: MeshResource) -> [(materialIndex: Int, geometry: Geometry)]? {
        let contents = mesh.contents
        var models: [String: MeshResource.Model] = [:]
        for model in contents.models {
            models[model.id] = model
        }
        var result: [(materialIndex: Int, geometry: Geometry)] = []
        for instance in contents.instances {
            guard let model = models[instance.model] else { continue }
            for part in model.parts {
                guard var geometry = geometry(of: part) else { return nil }
                if instance.transform != matrix_identity_float4x4 {
                    let m = instance.transform
                    let linear = simd_float3x3(
                        SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                        SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                        SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z)
                    )
                    let normalMatrix = linear.inverse.transpose
                    geometry.positions = geometry.positions.map { let p = m * SIMD4($0, 1); return SIMD3(p.x, p.y, p.z) }
                    geometry.normals = geometry.normals.map { simd_normalize(normalMatrix * $0) }
                }
                result.append((part.materialIndex, geometry))
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func geometry(of part: MeshResource.Part) -> Geometry? {
        let positions = part.positions.elements
        guard positions.isEmpty == false, part.positions.rate == .vertex else { return nil }
        let indices = part.triangleIndices?.elements ?? Array(0..<UInt32(positions.count))
        guard indices.count.isMultiple(of: 3) else { return nil }

        switch (part.normals?.rate, part.normals?.elements) {
        case (.vertex?, let normals?) where normals.count == positions.count:
            return Geometry(positions: positions, normals: normals, indices: indices)
        case (.faceVarying?, let normals?) where normals.count == indices.count:
            // One normal per triangle corner: un-index so corners keep theirs.
            return Geometry(
                positions: indices.map { positions[Int($0)] },
                normals: normals,
                indices: Array(0..<UInt32(indices.count))
            )
        default:
            return nil
        }
    }

    /// Drops the transform-only husks merging leaves behind. Named entities
    /// (boundaries, animated pieces) and anything else special stay.
    private static func prune(_ entity: Entity) {
        for child in Array(entity.children) where child.name.isEmpty {
            prune(child)
            let plain = type(of: child) == Entity.self || type(of: child) == ModelEntity.self
            if plain, child.children.isEmpty, child.components[ModelComponent.self] == nil {
                child.removeFromParent()
            }
        }
    }
}
