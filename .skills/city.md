# City / Town

## Purpose

Document the local 3×3 town board, buildings, placement, and presentation flow.

## Responsibilities

`Town` stores a town's name, resources, buildings, biome layout, faction, Duskara flag, and army data. `BuildingSystem` handles construction/upgrades. `PlacementValidationSystem` and `BiomeSystem` validate coordinates. `TownSystem` derives population/capacity. SwiftUI selects intent; RealityKit renders the board.

## Data flow

`BuildMenuView → GameViewModel.beginPlacement → World3DStateAdapter.tilePlacementState → World3DRenderer overlays → selectCell → GameAction.build → GameReducer → BuildingSystem → GameState`.

## Rules

- The default grid is 3 columns by 3 rows.
- A new town starts with a House in the center and a Pier on the bottom edge.
- A plot must be in bounds and unoccupied.
- A Pier is unique per town and must be on the town edge.
- Construction checks balance-defined cost and free people, then adds the building and any people-on-build.
- Upgrade cost uses the next level multiplier and respects `maxLevel`.
- Building production is derived from definition and level and is applied during daily simulation.

## Models and APIs

`BuildingKind`, `BuildingDefinition`, `BuildingInstance`, `PlacementRule`, `GridCoordinate`, `GridSize`, `TilePlacementState`, `BuildingSystem.build`, `upgrade`, `income`, `PlacementValidationSystem.canPlace`, and `validCoordinates`.

## Constraints and performance

Do not bypass placement validation or mutate buildings from UI/rendering. The board is small; validation scans all 3×3 coordinates. Rendering must update changed tiles incrementally.

## Extension points

Add a building case, balance definition, display metadata, placement rule, tests, and renderer asset/visual if needed. Preserve existing serialized raw values.

## Known limitations / TODO / Requires Confirmation

- `BiomeSystem` currently maps edge placement to board edges; it does not inspect the town's biome values for Pier placement.
- Building production does not visibly consume the declared workforce during income; only construction/training validation uses free people. Confirm intended economy before changing.
