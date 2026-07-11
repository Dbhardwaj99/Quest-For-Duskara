# Agent Handoff Notes

This file gives future coding agents the minimum context needed to work safely on Quest for Duskara.

The canonical AI-first documentation is now [`.skills/skills.md`](../.skills/skills.md). Read it first; this file remains a compact human-facing handoff and should stay consistent with it.

## Current State

Quest for Duskara is a SwiftUI and RealityKit macOS strategy game. The production gameplay path is RealityKit-first: menu actions open `GameView`, which embeds the 3D town renderer through `World3DTownView` and `World3DTownViewController`.

There is no alternate gameplay mode. Treat the RealityKit path as the application architecture. The current economy is intentionally compact: 3x3 town boards, resources of gold, food, people, skill, and soldiers, and active building types of House, Farm, Factory, and Barracks.

## Folder Ownership

- `App/`: app entry point, root navigation, and top-level route decisions.
- `Core/Models/`: shared value models and configuration.
- `Core/Systems/`: deterministic gameplay rules.
- `Core/Managers/`: focused coordination helpers.
- `Core/Persistence/`: save/load code.
- `Gameplay/Buildings/`: building domain models.
- `Gameplay/Resources/`: resource display metadata.
- `Gameplay/Combat/`: soldier and combat-domain models.
- `Gameplay/World/`: world-map models.
- `Presentation/ViewModels/`: observable app-facing state and command coordination.
- `Presentation/Views/`: SwiftUI screens and AppKit representable wrappers.
- `Presentation/Components/`: reusable SwiftUI controls.
- `Presentation/Theme/`: colors and app styling.
- `Rendering3D/`: RealityKit renderer, camera, entities, render resources, and adapter.

Keep new files inside the smallest matching ownership boundary.

## System Responsibilities

- `GameViewModel` coordinates UI intent, state selection, presentation flags, clock lifecycle, and save calls.
- `ResourceSystem` applies resource spending and deltas.
- `SimulationSystem` advances days and applies production.
- `BuildingSystem` builds and upgrades structures.
- `PlacementValidationSystem` owns build placement checks.
- `BiomeSystem` owns biome adjacency checks.
- `WorldMapSystem` creates towns, connections, and conquest behavior.
- `WorldGenerator`, `TerritoryGenerator`, `TerritorySystem`, and `TerritoryOwnership` create and reconcile world terrain, regions, and faction ownership.
- `TransferSystem` moves resources between owned towns.
- `SoldierTrainingSystem` trains soldier counts and army power.
- `ArmyUpkeepSystem`, `CombatSystem`, `EnemyAISystem`, and `OccupationSystem` handle food upkeep, battle outcomes, enemy turns, and capture penalties.
- `FeedbackOverlaySystem` maps failures to player-facing feedback text.
- `GameSaveStore` serializes `GameState` and day labels only.

Do not duplicate system rules in SwiftUI views or RealityKit entities.

## Naming Conventions

Use names that describe production architecture. Avoid names that imply temporary, alternate, or sample implementations. Gameplay screens should be named for their role (`GameView`, `WorldMapView`, `BuildMenuView`). RealityKit types may keep the `World3D` prefix where it identifies the renderer subsystem.

Swift style:

- PascalCase for types.
- camelCase for properties and methods.
- `@State private var` for SwiftUI local state.
- `let` for constants.
- Avoid force unwrapping.
- Prefer async/await over Combine.

## RealityKit Rendering Rules

`World3DTownViewController` owns the ARView lifecycle. `World3DRenderer` owns scene construction and incremental updates. `World3DStateAdapter` is the boundary between game state and render snapshots. `World3DTileEntity` owns entity composition for tile-level visuals. `World3DRenderResources` owns shared materials, meshes, quality selection, and diagnostics.

Renderer code should consume snapshots and renderer configuration. It should not mutate gameplay rules directly, write saves, or own app navigation.

## Simulation Update Flow

1. UI calls a `GameViewModel` command.
2. `GameViewModel` delegates rules to a system.
3. The system mutates `GameState` or returns a failure.
4. `GameViewModel` updates selection/presentation state and feedback.
5. Successful gameplay mutations call `saveCurrentGame()`.
6. SwiftUI updates `GameView`, and `World3DTownViewController.syncFromGameState()` asks the renderer to refresh snapshots.

Clock-driven day advancement follows the same path through `SimulationSystem` and persistence.

## Save and Load Expectations

Save data must remain presentation-agnostic. Do not encode camera position, ARView state, SwiftUI route state, sheet state, or developer-gallery state into `SavedGame`.

When save loading is implemented, it should initialize `GameViewModel(savedState:)`, set the phase to town play, start the clock, and present `GameView`. The current app writes saves but does not load them.

## Performance Constraints

- Keep RealityKit updates incremental; avoid rebuilding the full scene for ordinary tile changes.
- Cache reusable meshes and materials in `World3DRenderResources`.
- Avoid expensive derived state inside per-tile loops unless cached by town/grid revision.
- Do not rebuild the ARView from SwiftUI body changes.
- Avoid per-frame SwiftUI state writes for renderer diagnostics.
- Check diagnostics and build warnings after rendering changes.

## Common Extension Points

Add a resource:

1. Add a case to `ResourceKind`.
2. Add display metadata in `ResourceDisplay.swift`.
3. Add starting, difficulty preset, production, training, or capture-loss balance values in `Difficulty.swift` and `GameConfig.swift` as needed.
4. Update UI only if the new resource needs special handling.

Add a building:

1. Add a case to `BuildingKind`.
2. Add display metadata in `ResourceDisplay.swift`.
3. Add a `BuildingDefinition` in `GameConfig.swift`.
4. Add or update entity visuals in `World3DTileEntity` if the building needs distinct 3D treatment.
5. Add placement rules through `PlacementRule` and `PlacementValidationSystem`.

Add a biome:

1. Add a case to `BiomeKind`.
2. Add rendering in the terrain and backdrop portions of `World3DRenderer` or `World3DTileEntity`.
3. Add gameplay rules in `BiomeSystem` or `PlacementValidationSystem`.
4. Update world layouts in `WorldMapSystem`.

Add combat or conquest behavior:

1. Keep deterministic battle math in `CombatSystem`.
2. Keep capture side effects in `OccupationSystem`.
3. Reconcile town faction changes through `TerritorySystem.reconcileOwnership(in:)`.
4. Keep UI affordances in `WorldMapView` and command routing in `GameViewModel`.

## Validation

Use Xcode live diagnostics for touched files when possible, then run a full Xcode build. Verify menu navigation after route changes: Start Game, Load Game, and Asset Gallery should each open their intended destination without exposing alternate gameplay modes. For gameplay changes, also check a short loop: choose a difficulty, build/upgrade, train soldiers, open the world map, conquer an adjacent town, and transfer resources.
