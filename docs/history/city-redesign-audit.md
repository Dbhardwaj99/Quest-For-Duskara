# City Redesign Audit

## Summary

The city grid change from 5x5 to 3x3 is mostly centralized through `GameBalance.gridSize` and existing grid loops already read from that value. The minimum functional change is to update the default grid size and verify the 3D renderer/camera still frames the smaller board.

The resource redesign is broader. `Wood`, `Coal`, and `Tech` are enum cases in `ResourceKind`, are seeded into starting/world resources, appear in building costs, production, capture penalties, setup allocation, HUD/resource panels, world-map transfer UI, and soldier training costs. Introducing `Skills` and a `Factory` requires updating the resource/building enums, balance definitions, UI display metadata, 2D building art, 3D building art, and any hard-coded resource lists.

To preserve behavior with the smallest change set, the current `soldiers` resource can remain the internal storage field for Army, but its user-facing title should become `Army` if the redesign requires the visible resource list to say Army. Renaming the enum case or raw value would increase save compatibility risk.

## Grid Size Changes (5x5 -> 3x3)

- `Core/Models/GameConfig.swift`
  - `GameBalance.duskDefault.gridSize` is hard-coded as `GridSize(columns: 5, rows: 5)` at line 21.
  - Minimum change: set this to `GridSize(columns: 3, rows: 3)`.

- `Core/Models/BiomeModels.swift`
  - `GridSize` and `GridCoordinate` define the shared grid model.
  - `GridSize.contains(_:)` is size-agnostic and should work for 3x3 without logic changes.

- `Core/Systems/PlacementValidationSystem.swift`
  - `canPlace` uses `balance.gridSize.contains` for bounds.
  - `validCoordinates` loops `0..<balance.gridSize.rows` and `0..<balance.gridSize.columns`.
  - No hard-coded 5x5 logic, but valid placement density changes because only 9 plots remain.

- `Core/Systems/BiomeSystem.swift`
  - Edge/biome adjacency checks use `gridSize.columns - 1` and `gridSize.rows - 1`.
  - No hard-coded 5x5 logic.
  - With 3x3, a larger share of plots touch a biome border, so biome adjacency requirements become easier to satisfy.

- `Presentation/ViewModels/GameViewModel.swift`
  - `normalizeBuildingsToCurrentGrid()` clamps/moves saved building coordinates into the current `balance.gridSize`.
  - `nearestOpenCoordinate` loops over `balance.gridSize`.
  - Direct 3x3 dependency: saved 5x5 towns with more than 9 buildings cannot all be remapped because there may be no open coordinate left. The existing code leaves any unplaceable building at its old out-of-bounds coordinate.

- `Core/Systems/EnemyAISystem.swift`
  - `preferredCoordinate` computes the town center as `GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)`.
  - No hard-coded 5x5 logic. For 3x3 the center remains `(1, 1)`.

- `Core/Systems/WorldMapSystem.swift`
  - `starterBuildings(for:balance:)` computes center from `balance.gridSize` and places the starter farm at `center.y + 1`.
  - For 3x3 this becomes `(1, 2)`, which is valid.
  - The 5-column world map at `nodePosition`/`makeConnections` is world-map topology, not city grid. It should not be changed for this city redesign.

- `Rendering3D/Adapters/World3DAdapter.swift`
  - `gridSize` reads `balance.gridSize`.
  - `allTileSnapshots()` loops over `gridSize.rows` and `gridSize.columns`.
  - No hard-coded 5x5 logic.

- `Rendering3D/Renderer/World3DRenderer.swift`
  - Initial private `gridSize` defaults to `GridSize(columns: 5, rows: 5)` before first render.
  - `render(adapter:)` replaces it with `adapter.gridSize`, so this is low risk but should be updated to 3x3 for consistency.
  - Board size, camera bounds, terrain ring, selection, tile positions, backdrop segment counts, and scaffold signatures are all calculated from `GridSize`.

- `Rendering3D/Renderer/World3DTownViewController.swift`
  - Camera bounds are requested from `sourceViewModel.balance.gridSize`.
  - No direct hard-coded 5x5 city grid dependency found.

- `Presentation/Views/BuildMenuView.swift`
  - Uses SF Symbol `square.grid.3x3.fill` for the generic placement rule text.
  - This is visual only and already matches the new grid size.

## Resource Changes

### Wood

- Defined in:
  - `Core/Models/ResourceModels.swift`: `ResourceKind.wood`, title `Wood`, symbol `W`.
  - `Gameplay/Resources/ResourceDisplay.swift`: color for `.wood`.

- Produced in:
  - `Core/Models/GameConfig.swift`: `.woodMill` has `baseProduction: [.wood: 18]`.
  - `Core/Systems/BuildingSystem.swift`: `.woodMill` production is scaled by `town.forestSideCount`.

- Consumed in:
  - `GameConfig` building costs:
    - `house`: `.wood: 30`
    - `farm`: `.wood: 35`
    - `woodMill`: `.wood: 20`
    - `coalMine`: `.wood: 25`
    - `lab`: `.wood: 25`
    - `barracks`: `.wood: 40`
  - Upgrade costs inherit these base costs through `BuildingDefinition.cost(for:)`.

- Other dependencies that would break:
  - `GameConfig.baseStartingResources` seeds `.wood`.
  - `GameConfig.captureResourceLossRates` includes `.wood`.
  - `WorldMapSystem.makeTowns` seeds `.wood` based on forest layouts.
  - `GameViewModel.startingResourceKinds` includes `.wood` for setup allocation.
  - `BuildingDetailsSheetView` hard-codes `.wood` in the barracks available resources row.
  - Any old save file containing `.wood` as a resource dictionary key will fail if the enum case is removed without migration.

### Coal

- Defined in:
  - `Core/Models/ResourceModels.swift`: `ResourceKind.coal`, title `Coal`, symbol `C`.
  - `Gameplay/Resources/ResourceDisplay.swift`: color for `.coal`.

- Produced in:
  - `Core/Models/GameConfig.swift`: `.coalMine` has `baseProduction: [.coal: 16]`.
  - `Core/Systems/BuildingSystem.swift`: `.coalMine` production is scaled by `town.mountainSideCount`.

- Consumed in:
  - `GameConfig` building costs:
    - `house`: `.coal: 10`
    - `farm`: `.coal: 10`
    - `woodMill`: `.coal: 12`
    - `coalMine`: `.coal: 10`
    - `lab`: `.coal: 25`
    - `barracks`: `.coal: 30`
  - Upgrade costs inherit these base costs through `BuildingDefinition.cost(for:)`.

- Other dependencies that would break:
  - `GameConfig.baseStartingResources` seeds `.coal`.
  - `GameConfig.captureResourceLossRates` includes `.coal`.
  - `WorldMapSystem.makeTowns` seeds `.coal` based on mountain layouts.
  - `GameViewModel.startingResourceKinds` includes `.coal` for setup allocation.
  - `BuildingDetailsSheetView` hard-codes `.coal` in the barracks available resources row.
  - Any old save file containing `.coal` as a resource dictionary key will fail if the enum case is removed without migration.

### Tech

- Defined in:
  - `Core/Models/ResourceModels.swift`: `ResourceKind.tech`, title `Tech`, symbol `T`.
  - `Gameplay/Resources/ResourceDisplay.swift`: color for `.tech`.

- Produced in:
  - `Core/Models/GameConfig.swift`: `.lab` has `baseProduction: [.tech: 7]`.

- Consumed in:
  - `GameConfig.soldierDefinitions`:
    - `archer`: `.tech: 5`
    - `knight`: `.tech: 15`
  - Upgrade/building costs do not directly consume Tech in the current code.

- Other dependencies that would break:
  - `GameConfig.baseStartingResources` seeds `.tech`.
  - `GameConfig.captureResourceLossRates` includes `.tech`.
  - `WorldMapSystem.makeTowns` seeds `.tech`.
  - `GameViewModel.startingResourceKinds` includes `.tech` for setup allocation.
  - `BuildingDetailsSheetView` hard-codes `.tech` in the barracks available resources row.
  - Soldier training becomes impossible or uncompilable if `.tech` is removed before training costs are changed to `.skills` or another remaining resource.
  - Any old save file containing `.tech` as a resource dictionary key will fail if the enum case is removed without migration.

### Skills

- New definition required in:
  - `Core/Models/ResourceModels.swift`: add `ResourceKind.skills` with title `Skills` and symbol.
  - `Gameplay/Resources/ResourceDisplay.swift`: add a color for `.skills`.

- Production required in:
  - `Core/Models/GameConfig.swift`: add `Factory` building definition with `baseProduction: [.skills: <amount>]`.
  - `Core/Systems/BuildingSystem.swift`: no new production logic is required if Factory production is flat like Lab production. Only add special scaling if intentionally required.

- Consumption likely required in:
  - `GameConfig.soldierDefinitions`: replace Tech training costs with Skills to preserve the current Tech-gated training behavior.
  - Building costs should be rewritten to use only remaining resources: Gold, Food, People, Skills, Army. The minimum direct requirement is to remove Wood/Coal from all costs and replace Tech soldier costs.

## Building Dependencies

- `woodMill`
  - Defined in `BuildingKind` and titled `Wood Mill`.
  - Balance definition produces Wood and requires forest adjacency.
  - Production scaling exists in `BuildingSystem.modifiedProduction`.
  - Placement failure copy exists in `FeedbackOverlaySystem`.
  - 2D art exists in `BuildingArtView`.
  - 3D art exists in `World3DTileEntity.addWoodMill` and in the `addBuilding` switch.
  - Asset gallery icon exists in `World3DAssetGalleryView`.
  - If Wood is removed, this building should be removed from buildable definitions at minimum. Removing the enum case entirely requires updating all exhaustive switches and save compatibility.

- `coalMine`
  - Defined in `BuildingKind` and titled `Coal Mine`.
  - Balance definition produces Coal and requires mountain adjacency.
  - Production scaling exists in `BuildingSystem.modifiedProduction`.
  - Placement failure copy exists in `FeedbackOverlaySystem`.
  - 2D art exists in `BuildingArtView`.
  - 3D art exists in `World3DTileEntity.addCoalMine` and in the `addBuilding` switch.
  - Asset gallery icon exists in `World3DAssetGalleryView`.
  - If Coal is removed, this building should be removed from buildable definitions at minimum. Removing the enum case entirely requires updating all exhaustive switches and save compatibility.

- `lab`
  - Defined in `BuildingKind` and titled `Lab`.
  - Balance definition produces Tech.
  - Enemy AI includes `.lab` in `infrastructurePriority`.
  - 2D art exists in `BuildingArtView`.
  - 3D art exists in `World3DTileEntity.addLab` and in the `addBuilding` switch.
  - Asset gallery icon exists in `World3DAssetGalleryView`.
  - Minimum redesign choice: either replace Lab with Factory everywhere, or leave Lab as an unbuildable legacy enum case and add Factory as the new buildable Skills producer. Reusing Lab as Factory would be a larger semantic mismatch and is not recommended if the requested building is specifically Factory.

- `factory`
  - New `BuildingKind.factory` case required.
  - New title/color/art/icon cases required wherever `BuildingKind` is exhaustively switched.
  - New `GameConfig.buildingDefinitions[.factory]` required with only remaining resource costs and Skills production.
  - If Factory has no biome rule, no placement validation changes are needed.

- Other buildings with removed-resource costs:
  - `house`, `farm`, and `barracks` all currently consume Wood and/or Coal.
  - Their `baseCost` values must be rewritten to remaining resources.
  - Their upgrade costs automatically change because upgrade cost is derived from `baseCost * level`.

- Soldier training dependency:
  - `archer` and `knight` currently consume Tech.
  - Their costs must change to Skills or another remaining resource, otherwise training breaks when Tech is removed.

## UI Impact

- `Presentation/Views/StartSetupView.swift`
  - Shows starting bonus allocation via `viewModel.startingResourceKinds`.
  - Indirectly affected by removing Wood/Coal/Tech and deciding whether Skills participates in the bonus pool.

- `Presentation/ViewModels/GameViewModel.swift`
  - `startingResourceKinds` is hard-coded to `[.gold, .wood, .coal, .tech]`.
  - Feedback text for transfers uses `kind.title`; if `.soldiers` remains internal but becomes visible Army, title should change in `ResourceKind`.

- `Presentation/Components/HUDViews.swift`
  - Top HUD resource strip uses `ResourceKind.allCases`.
  - Removing/adding enum cases changes the visible strip automatically, but the `ResourceKind` title/symbol/color must be complete.

- `Presentation/Views/BuildMenuView.swift`
  - Build resources header uses `ResourceKind.allCases`.
  - Build cards use `BuildingKind.allCases` and `viewModel.definition(for:)`; old buildings with no definition are hidden, but enum removal requires switch updates elsewhere.
  - Cost and production rows use resource dictionaries and will reflect the new resources automatically.
  - Placement rule labels still support biome rules, but Factory likely needs no new placement UI if it uses `.none`.

- `Presentation/Views/BuildingDetailsSheetView.swift`
  - Building detail cost/production rows are dictionary-driven.
  - Barracks training sheet hard-codes `[ResourceKind.gold, .wood, .coal, .tech, .food]`; this must become the remaining relevant resources, likely `[.gold, .food, .people, .skills]` or a list derived from training costs.
  - Training cost rows update automatically once soldier definitions use Skills.

- `Presentation/Components/ResourceViews.swift`
  - `ResourcePill` depends on `ResourceKind.symbol` and `ResourceKind.color`.
  - No structural change required beyond adding Skills/removing old cases.

- `Gameplay/Resources/ResourceDisplay.swift`
  - Exhaustive `ResourceKind.color` switch must remove Wood/Coal/Tech and add Skills.
  - Exhaustive `BuildingKind.color` switch must add Factory and remove or preserve old building cases depending on the chosen save strategy.

- `Presentation/Components/BuildingArtView.swift`
  - Exhaustive `BuildingKind` switch must add Factory art.
  - Remove or preserve Wood Mill, Coal Mine, and Lab art depending on whether their enum cases remain for legacy saves/gallery.

- `Rendering3D/Entities/World3DTileEntity.swift`
  - Exhaustive `BuildingKind` switch in `addBuilding` must add Factory 3D rendering.
  - Removing old building enum cases also requires removing the corresponding switch cases and optionally unused renderer helpers.

- `Presentation/Views/World3DAssetGalleryView.swift`
  - Uses `BuildingKind.allCases` for preview assets and has an exhaustive icon switch.
  - Factory needs an icon. Removed buildings disappear automatically only if removed from `allCases` or enum cases.

- `Presentation/Views/WorldMapView.swift`
  - Resource display uses `ResourceKind.allCases`.
  - Transfer picker uses `ResourceKind.allCases.filter { $0 != .people }`, so Skills becomes transferable automatically and Wood/Coal/Tech disappear if enum cases are removed.
  - This is a direct resource dependency, not a world-map redesign.

- `Gameplay/World/WorldModels.swift`
  - `specializationSummary` currently says `Wood-rich settlement` and `Coal-rich settlement` based on forest/mountain sides.
  - This UI copy should change if Wood/Coal are removed. The underlying biome counts can remain because terrain/biomes are not part of the redesign.

- `Core/Systems/FeedbackOverlaySystem.swift`
  - Placement failure copy mentions Wood Mills and Coal Mines. If those buildings are removed from play, this copy can be removed or left only for legacy enum cases.

## Risks

- Removing `ResourceKind.wood`, `.coal`, or `.tech` without save migration can make existing saved games fail to decode because saved resource dictionaries can contain those enum keys.

- Removing `BuildingKind.woodMill`, `.coalMine`, or `.lab` without save migration can make existing saved games fail to decode because saved building instances can contain those raw values.

- A 3x3 town has only 9 plots. Existing saved 5x5 towns with more than 9 buildings cannot be fully normalized into the smaller grid by the current `normalizeBuildingsToCurrentGrid()` behavior.

- If Wood and Coal are removed from costs without rebalancing replacement costs, building affordability and pacing can change sharply. This affects core progression because House, Farm, and Barracks all currently depend on Wood/Coal.

- If Tech is removed before soldier costs are changed, Archer and Knight training will either fail to compile or become impossible depending on how the enum removal is staged.

- Enemy AI currently prioritizes `.lab`. If Lab is removed/replaced and AI priority is not updated to `.factory`, enemy towns lose the current tech/skills-producing infrastructure behavior.

- If Factory is added to `BuildingKind` without updating all exhaustive switches, the project will not compile. Required switches include titles, colors, 2D art, 3D art, and asset gallery icons.

- If `soldiers` is renamed at the enum/raw-value level to `army`, existing combat, transfer, save fallback, and army-strength synchronization paths need direct updates. Keeping the internal case and changing only the displayed title is lower risk.

## Recommended Implementation Order

1. Decide save compatibility strategy for old resource and building raw values.
   - Lowest risk for existing saves: keep legacy enum cases temporarily but remove them from active balance/build menus, then sanitize or migrate saved resources/buildings.
   - Cleanest new-game model: remove enum cases and add explicit save migration/legacy decode handling in the same change.

2. Change the grid default to 3x3.
   - Update `GameConfig.duskDefault.gridSize`.
   - Update `World3DRenderer` initial default grid size for consistency.
   - Verify starter buildings and saved-building normalization with the 9-plot limit.

3. Update `ResourceKind` and resource presentation.
   - Remove or deprecate Wood/Coal/Tech.
   - Add Skills title, symbol, and color.
   - Change visible Soldiers title to Army if required while preserving internal storage if possible.

4. Update balance data in `GameConfig`.
   - Remove Wood/Coal/Tech from starting resources and capture loss rates.
   - Rewrite House/Farm/Barracks costs to remaining resources.
   - Replace Tech soldier costs with Skills.
   - Remove Wood Mill/Coal Mine/Lab definitions from buildable balance.
   - Add Factory definition with Skills production.

5. Update world state seeding that directly references removed resources.
   - `WorldMapSystem.makeTowns` should seed only remaining resources.
   - Keep world topology unchanged.

6. Update direct building/resource logic.
   - Remove Wood Mill/Coal Mine production scaling from `BuildingSystem` if those buildings are no longer active.
   - Update `EnemyAISystem.infrastructurePriority` from `.lab` to `.factory` if AI should preserve the current producer-building behavior.
   - Update or remove obsolete placement failure copy in `FeedbackOverlaySystem`.

7. Update UI hard-coded lists and exhaustive switches.
   - `GameViewModel.startingResourceKinds`.
   - Barracks available resources in `BuildingDetailsSheetView`.
   - `ResourceDisplay` resource/building colors.
   - `BuildingKind.title`.
   - `BuildingArtView`.
   - `World3DTileEntity`.
   - `World3DAssetGalleryView`.
   - Wood/Coal specialization copy in `WorldModels`/`WorldMapView`.

8. Build and smoke-test the direct city flows.
   - New game setup.
   - 3x3 town rendering and camera framing.
   - Build House/Farm/Barracks/Factory.
   - Advance day and confirm Skills production.
   - Train Archer/Knight using Skills.
   - Open world map and transfer remaining transferable resources.
