# Rendering

## Purpose

Document the SwiftUI/AppKit/RealityKit boundary and the performance-sensitive renderer.

## Responsibilities

`World3DTownView` bridges SwiftUI to `World3DTownViewController`. The controller owns `ARView` lifecycle, camera installation, taps, sync, and FPS sampling. `World3DStateAdapter` converts a `Town` into `World3DTileSnapshot` values. `World3DRenderer` builds static terrain/ocean and incrementally updates tile content, overlays, soldiers, boats, and diagnostics. `World3DTileEntity` builds tile geometry and bundled building models. `World3DRenderResources` caches meshes/materials/collision shapes. `World3DOcean` and `OceanShaders.metal` provide water motion.

## Data flow

`GameState → World3DStateAdapter → tile snapshots → World3DRenderer → RealityKit entities`. User taps travel back through the controller to `GameViewModel.selectCell`.

## Design rules

The renderer consumes snapshots and configuration; it must not mutate gameplay state, save files, or navigation. Procedural details use stable coordinate-based variation. Bundled USDZ assets are loaded by building kind when available.

## Performance constraints

Cache reusable meshes/materials, avoid rebuilding `ARView`, rebuild terrain only when grid/biome structure changes, update changed tiles only, and use adaptive low/medium/high quality based on FPS, thermal state, and memory.

## Public APIs and models

`World3DTileSnapshot`, `World3DStateAdapter`, `World3DRenderer.render`, `World3DCameraController`, `World3DRenderResources`, and `World3DDiagnostics`.

## Extension points

Add snapshot content first, then adapter projection and tile/entity rendering. Add assets to `Assets/` and the Xcode resource phase. Keep materials in palette/cache systems.

## Known limitations / TODO / Requires Confirmation

- Several renderer files are far above the preferred 300-line size; split only after preserving private helper access and validating a complete Metal/Xcode build.
- The available environment lacks the Metal toolchain required to compile `OceanShaders.metal`, so renderer verification must be repeated on a complete toolchain.
