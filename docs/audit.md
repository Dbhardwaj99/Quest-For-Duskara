# Terrain, Water, and Building Fidelity Audit

Date: 2026-07-02

Scope audited:

- `Rendering3D/Renderer/World3DRenderer.swift`
- `Rendering3D/Entities/World3DTileEntity.swift`
- `Rendering3D/Camera/World3DCameraController.swift`
- `Rendering3D/Resources/World3DTheme.swift`

No code changes were made as part of this audit.

## Executive Summary

The current renderer does not enforce a true 3x3 island. It renders the playable 3x3 tile grid through `World3DTileEntity.makeTile(...)`, then adds a larger static scaffold around it: a ground plate, skirt, terrain ring, backdrop bases, and forest/mountain backdrop masses. The water is also not an infinite sea; it is four finite rectangular strips around the enlarged scaffold. At tilted/rotated camera angles, those finite strips can expose edges or read as a bounded patch.

Building fidelity is better than the prompt's baseline: House, Farm, Factory/Lab, and Barracks already have secondary props, roof slats, trim pieces, and per-building silhouettes. The remaining issue is consistency and readability, not total absence of detail. Factory still routes through `addLab(...)`, and the building helpers depend on the shared palette fields in `WorldPalette`.

## Exact Function Map

### Outer Terrain / Extra Land

Primary scaffold entry:

- `World3DRenderer.rebuildScaffold(layout:gridSize:)` at `Rendering3D/Renderer/World3DRenderer.swift:135`
  - Calls `addDuskBackdrop(...)`
  - Calls `addGroundPlate(...)`
  - Calls `addTerrainRing(...)`
  - Calls `addBiomeBackdrop(...)`

Extra land sources:

- `addGroundPlate(for:)` at `World3DRenderer.swift:150`
  - Creates a large earth box sized from `terrainWidth(for:)` and `terrainDepth(for:)`.
  - This is a continuous base under and beyond the playable grid.
- `addTerrainSkirt(width:depth:)` at `World3DRenderer.swift:165`
  - Adds four side boxes around the board footprint.
  - This reinforces the plinth/island mass outside the 9 tiles.
- `addTerrainRing(layout:gridSize:)` at `World3DRenderer.swift:300`
  - Iterates `-terrainRingDepth ..< gridSize + terrainRingDepth`.
  - Skips real grid coordinates, then adds non-playable terrain tiles around the board.
  - This is the main visible outer terrain ring.
- `terrainWidth(for:)` and `terrainDepth(for:)` at `World3DRenderer.swift:686`
  - Use `gridSize + terrainRingDepth * 2 + 2`, so the static board footprint is larger than the playable grid even when the grid is 3x3.
- `addBiomeBackdrop(layout:gridSize:)` at `World3DRenderer.swift:438`
  - Adds backdrop entities at coordinates from `backdropCoordinate(...)`, including y `-2`, y `gridSize.rows + 1`, x `-2`, and x `gridSize.columns + 1`.
- `addBackdropBase(for:to:coordinate:side:)` at `World3DRenderer.swift:503`
  - Adds a terrain-colored base under each backdrop mass.
  - This makes the distant mountain/forest masses read as attached land instead of skybox-style silhouettes.

Playable tile source:

- `World3DTileEntity.makeTile(...)` at `Rendering3D/Entities/World3DTileEntity.swift:19`
  - This creates the actual selectable tile entities.
  - `World3DRenderer.render(adapter:)` positions these for only the adapter's tile snapshots.

### Water Plane / Sea

Water entry:

- `addDuskBackdrop(for:)` at `World3DRenderer.swift:191`
  - Calls `addSurroundingWater(boardWidth:boardDepth:)`.

Finite water generation:

- `addSurroundingWater(boardWidth:boardDepth:)` at `World3DRenderer.swift:212`
  - Creates four box strips: `backWater`, `frontWater`, `leftWater`, `rightWater`.
  - Uses `outerWidth = boardWidth + tileSize * 5.2` and `outerDepth = boardDepth + tileSize * 5.2`.
  - Uses an inner cutout around the board, so it is not one continuous infinite sea.
- `addWaterSheen(width:depth:y:)` at `World3DRenderer.swift:259`
  - Adds four small sheen boxes positioned relative to the finite water dimensions.

Camera clipping:

- `World3DCameraController.install(...)` at `Rendering3D/Camera/World3DCameraController.swift:46`
  - Uses `PerspectiveCameraComponent(near: 0.01, far: 28, fieldOfViewInDegrees: 35)`.
  - The far clip is probably not the first issue for the current water size; the immediate issue is finite water geometry. If water is enlarged substantially, keep `far: 28` in the verification checklist.

### Building Templates

Building dispatch:

- `World3DTileEntity.addBuilding(...)` at `World3DTileEntity.swift:628`
  - Adds shared dirt patch and plinth.
  - Routes:
    - `.house` -> `addHouse(...)`
    - `.farm` -> `addFarm(...)`
    - `.factory` -> `addLab(...)`
    - `.barracks` -> `addBarracks(...)`

Templates:

- `addHouse(...)` at `World3DTileEntity.swift:662`
  - Already has overhanging roof mass, roof cap, slats, timber frame, side shed, chimney cap, shutters, door, fence, props, and lantern.
  - Gap: door lacks a true frame/step, and most trim is concentrated on one visible face.
- `addFarm(...)` at `World3DTileEntity.swift:691`
  - Already has crop rows, small barn, roof slats, timber frame, door, fences, wood pile, scarecrow, cart, and sack.
  - Gap: barn is small and front-detail heavy; foundation and entry step are minimal.
- `addLab(...)` at `World3DTileEntity.swift:761`
  - Used for `.factory`.
  - Already has tower, cap, glass, chimney-like stack, roof, slats, rods, debris, and alchemy props.
  - Gap: naming and silhouette no longer match the current Factory gameplay role. It reads as a lab/magic tower, not a factory.
- `addBarracks(...)` at `World3DTileEntity.swift:784`
  - Already has broad body, roof, roof cap, corner posts/towers, banners, door/window, weapon rack, training props, shield rack, and fire pit.
  - Gap: door/window framing and base course could be stronger; roof is still a simple block slab.

Unused legacy templates:

- `addWoodMill(...)` at `World3DTileEntity.swift:714`
- `addCoalMine(...)` at `World3DTileEntity.swift:740`

These are currently not reachable from `BuildingKind` dispatch in `addBuilding(...)`.

## Theme and Cache Risk

`WorldPalette` is a flat named-color bag at `Rendering3D/Resources/World3DTheme.swift:55`. Building geometry currently references named palette fields such as `plaster`, `terracotta`, `darkTimber`, `strawRoof`, `slateRoof`, `labStone`, and `arcaneBlue`.

Important correction: there is no building mesh cache keyed by building geometry. `World3DTileEntity.templateCache` only caches reusable tree/mountain template entities by `TemplateKey(kind:tileSizeBucket:theme:)`. Building templates are generated directly through `addBuilding(...)`.

Risk profile:

- Removing outer terrain will affect environmental palette fields: `earth`, `skirt`, `terrainForestDark`, `terrainForestLight`, `terrainMountain`, `terrainPlains`, `terrainRiver`, `baseForest`, `baseMountain`, `basePlains`, and `baseRiver`.
- Enlarging water should preserve `waterOpen`, `waterShadow`, `waterSheen`, and `tileWater`.
- Building-detail changes should not break palette lookup if they reuse existing named colors.
- Adding many new palette fields would increase theme maintenance across all `WorldPalette` variants. Avoid that unless the new geometry cannot read with existing fields.

## Findings

### 1. True 3x3 Island Is Not Enforced

The playable grid may be 3x3, but the rendered land is larger. `addTerrainRing(...)` explicitly creates non-playable terrain around the grid. `addGroundPlate(...)` and `addTerrainSkirt(...)` create a larger continuous plinth under that area. `addBiomeBackdrop(...)` then places backdrop masses on terrain-colored bases outside the grid.

Impact:

- The island reads as 5x5-plus terrain rather than only 9 tiles.
- Forest/mountain silhouettes look physically attached to the same land mass.
- `cameraBounds(for:)` uses the inflated terrain width/depth, so camera behavior is also scoped around the larger scaffold.

### 2. Water Is Finite Strip Geometry

`addSurroundingWater(...)` does not create a large/infinite water plane. It creates four shallow boxes around the board, with an inner cutout. This explains why the water can look clipped or bounded behind the island.

Impact:

- Water edges can be visible at rotation/zoom.
- The sea does not fill the viewport independently of board size.
- Sheen placement is tied to the finite water dimensions.

### 3. Backdrop Masses Are Not Skybox-Style

`addBiomeBackdrop(...)` places forest/mountain masses at off-grid coordinates and `addBackdropBase(...)` gives each one a terrain base. That anchors the backdrop to local ground, not to distant atmosphere.

Impact:

- Distant scenery reads like attached terrain.
- Removing the terrain ring alone will not fully solve the visual attachment; backdrop bases must also be removed or replaced.

### 4. Building Fidelity Is Partially Already Implemented

The current building templates already include several requested details. The audit prompt's "simple box + roof" description is outdated for this branch.

Remaining fidelity gaps:

- Factory uses `addLab(...)`, so naming and shape are off for the current economy.
- Door/window frames are inconsistent across templates.
- Entry steps/stoops are mostly missing.
- Roofs have overhang blocks and slats, but not true ridge beams or eave strips consistently.
- Some templates place most detail on the front face, so rotation can expose simpler sides.

## Proposed Diff Plan

### Phase 1: Enforce The True 3x3 Island

Smallest safe change:

1. Stop calling `addTerrainRing(layout:gridSize:)` from `rebuildScaffold(...)`.
2. Stop calling `addBiomeBackdrop(layout:gridSize:)` from `rebuildScaffold(...)`, or gate it behind a new clearly named debug/atmosphere flag defaulted off.
3. Change `terrainWidth(for:)` and `terrainDepth(for:)` to use only playable grid dimensions:
   - `tileCount = gridSize.columns`
   - `tileCount = gridSize.rows`
4. Keep `addGroundPlate(...)` and `addTerrainSkirt(...)`, but resize them to the playable grid only, so they become the 3x3 island underside rather than a larger plinth.

Skipped for first pass: new skybox silhouettes. Add later only if the game looks too empty after removing attached terrain.

### Phase 2: Make Water Fill The View

Smallest safe change:

1. Replace the four-strip water layout in `addSurroundingWater(...)` with one large, shallow water box or plane centered under the scene.
2. Size it independently from board dimensions, for example `tileSize * 60` or larger.
3. Put it below the island top and above the table shadow, preserving `waterOpen`/`waterShadow` usage.
4. Retarget `addWaterSheen(...)` to the large water dimensions or reduce sheens to a few camera-visible accents.
5. Verify against `PerspectiveCameraComponent(far: 28)` only after resizing. If a large water plane still clips visually, raise far clip modestly.

Do not overbuild a custom shader yet. A single large water plane/box is enough to test the composition.

### Phase 3: Building Fidelity Pass

Smallest safe change:

1. Add reusable micro-helpers only if they remove repeated geometry:
   - `addDoorFrame(...)`
   - `addWindowFrame(...)`
   - `addEntryStep(...)`
   - `addRidgeBeam(...)`
2. Reuse existing palette fields:
   - Timber: `darkTimber`, `railWood`, `timber`
   - Stone/foundation: `plinthStone`, `warmStone`, `deepStone`
   - Roofs: `terracotta`, `terracottaDark`, `strawRoof`, `slateRoof`
3. Apply helpers to the four reachable templates only:
   - `addHouse(...)`
   - `addFarm(...)`
   - `addLab(...)` as the current Factory visual, or rename it to `addFactory(...)` if the shape is also adjusted.
   - `addBarracks(...)`
4. Leave `addWoodMill(...)` and `addCoalMine(...)` alone unless those buildings return to gameplay.

Recommended template-specific changes:

- House: add door frame and stoop; add two thin eave strips under the roof; add a roof ridge beam.
- Farm: add barn foundation strip and small entry step; add side wall trim so the barn reads from rotation.
- Factory: rename `addLab(...)` to `addFactory(...)` after changing silhouette, or keep `addLab(...)` if the magic-lab visual is intentional. Add a clearer production cue using existing `warmGold`, `smokeStone`, `slateRoof`, and `arcaneBlue`.
- Barracks: add stronger door frame, base course, and roof ridge/eave strips.

## Verification Checklist

Static checks:

- Confirm `rebuildScaffold(...)` no longer calls terrain ring/backdrop land generation for normal gameplay.
- Confirm `terrainWidth(for:)`/`terrainDepth(for:)` represent only playable tile footprint.
- Confirm `cameraBounds(for:)` still allows useful orbit/pinch behavior with the smaller board bounds.
- Confirm building template changes use existing `WorldPalette` fields or update all theme variants if new fields are added.

Visual checks:

- Launch town view at the default 3x3 board.
- Rotate through all camera yaw angles.
- Zoom in and out.
- Confirm no land exists beyond the 9 playable tiles and island edge/skirt.
- Confirm water fills the full viewport with no visible edge.
- Confirm backdrop masses, if retained, read as distant silhouettes rather than attached terrain.
- Inspect House, Farm, Factory, and Barracks from at least two camera angles.

## Recommended First Patch

Do this in one small patch:

1. Remove `addTerrainRing(...)` and `addBiomeBackdrop(...)` from normal `rebuildScaffold(...)`.
2. Make `terrainWidth(for:)` and `terrainDepth(for:)` use the playable grid only.
3. Replace four water strips with one large water plane/box.

Then visually verify. Building fidelity should be a second patch because it touches many small geometry calls and is easier to regress visually.
