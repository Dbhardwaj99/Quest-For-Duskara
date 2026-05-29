# Quest for Duskara Design Notes

This document describes the current RealityKit-first game architecture and the gameplay systems that support it.

## Product Direction

Quest for Duskara is a portrait-mode medieval strategy simulation. The player founds a settlement, builds a resource economy, trains soldiers, conquers connected towns, and transfers resources across the controlled realm.

The current game is built around one gameplay presentation: SwiftUI interface layers over a RealityKit town board.

## Core Loop

1. The player starts a game and allocates the starting bonus stockpile.
2. `GameViewModel.startGame()` commits the initial resources and enters town play.
3. The RealityKit town board renders the active town from `GameState`.
4. Buildings are placed on valid plots through shared placement validation.
5. Each game day, simulation systems apply income, time progress, and persistence.
6. The player opens the world map to conquer towns or transfer resources.
7. Loading a save restores `GameState` and presents the same RealityKit town view.

## Current Architecture

- `App/` owns app launch and root navigation.
- `Core/Models/` stores shared value types, actions, placement state, resources, biomes, and balance configuration.
- `Core/Systems/` owns deterministic gameplay rules.
- `Core/Persistence/` stores and loads renderer-agnostic save data.
- `Gameplay/` groups domain-specific building, resource, world, and combat types.
- `Presentation/` owns SwiftUI screens, reusable controls, theme, and `GameViewModel`.
- `Rendering3D/` owns the RealityKit runtime: renderer, camera, entities, render resources, and state adapter.

`GameViewModel` is the app-facing coordinator. It exposes observable state to SwiftUI, forwards user intent to systems, and saves after committed state changes. Game rules should stay in systems unless they are pure presentation coordination.

## World Simulation

`GameState` is the persistent source of truth. It stores the current day, elapsed day time, town list, world nodes, world connections, and active town ID.

`WorldMapSystem` creates the initial world, determines adjacency, and resolves conquest. `SimulationSystem` advances days and applies building income to each controlled town. `TimeSystem` converts elapsed seconds into day progress and determines when the next day begins.

## Resource Systems

`ResourceSystem` applies spending and production through `ResourceWallet`. Resource display metadata lives in `Gameplay/Resources/ResourceDisplay.swift` so UI can render consistent icons, names, and colors without knowing game rules.

Resource changes should be committed through systems and then saved through `GameViewModel.saveCurrentGame()`.

## Building Systems

`BuildingSystem` handles construction and upgrades. `PlacementValidationSystem` owns tile validation, including biome-adjacency rules through `BiomeSystem`.

The placement flow is:

1. `BuildMenuView` calls `GameViewModel.beginPlacement(for:)`.
2. `World3DStateAdapter` asks `tilePlacementState(for:)` while producing tile snapshots.
3. `World3DRenderer` renders placement overlays on valid and invalid plots.
4. Tapping a tile in `World3DTownViewController` calls `selectCell(_:)`.
5. `GameViewModel` commits the build through `BuildingSystem` or shows feedback from `FeedbackOverlaySystem`.

## Camera Controls

`World3DCameraController` installs RealityKit camera controls on the ARView. One-finger pan rotates the town board, pinch zooms, and inertia is handled with a display link. The controller exposes `isInteracting` so render sync can avoid fighting active gestures.

Camera bounds are derived from the current grid size by `World3DRenderer.cameraBounds(for:)`.

## Rendering Pipeline

`World3DTownView` bridges SwiftUI to `World3DTownViewController`. The controller creates an ARView in non-AR mode, installs camera gestures, tracks FPS diagnostics, and routes taps to `GameViewModel`.

`World3DStateAdapter` converts the current town into `World3DTileSnapshot` values. `World3DRenderer` consumes those snapshots, rebuilds terrain scaffolding when the biome layout or grid changes, updates changed tile entities, applies selection state, and reports diagnostics. `World3DRenderResources` centralizes mesh, material, quality, and diagnostics helpers. `World3DTileEntity` builds tile, terrain, building, overlay, forest, and mountain entities.

## Save and Load Architecture

`GameSaveStore` encodes `SavedGame` as JSON in the app documents directory. The save payload contains `GameState` and a day label. It does not contain renderer, camera, navigation, sheet, or debug state.

Root navigation is intentionally simple:

- Start Game creates a fresh `GameViewModel` and opens `GameView`.
- Load Game decodes `GameState`, initializes `GameViewModel(savedState:)`, and opens `GameView`.
- Asset Gallery opens `World3DAssetGalleryView` from the menu and is not part of gameplay flow.

## Presentation Design

SwiftUI owns presentation surfaces around the renderer:

- `GameView` composes the RealityKit town, HUD, bottom bar, feedback toast, build sheet, details sheet, and world map cover.
- `BuildMenuView` selects building placement.
- `BuildingDetailsSheetView` handles upgrades and barracks training.
- `WorldMapView` handles conquest and transfer interactions.
- `World3DAssetGalleryView` is a developer/debugging tool for inspecting render assets.

Normal gameplay feedback should use in-game toast state, not system alerts. Alerts are reserved for menu-level confirmation.

## Performance Notes

RealityKit work should stay incremental. `World3DRenderer` compares snapshots and updates only changed tiles where possible. Terrain scaffolding is rebuilt only when the grid or biome layout changes. Render resources are cached and can adapt quality based on diagnostics and device conditions.

Avoid adding per-frame SwiftUI state churn, rebuilding the whole ARView for ordinary model changes, or placing gameplay rules inside render entities.

## Planned Gameplay Roadmap

- More building roles, upgrade effects, and biome dependencies.
- Persistent decorative terrain and town beautification where it affects gameplay.
- Research, logistics, weather, and random events.
- Enemy town progression and richer conquest results.
- Combat visualization inside the 3D renderer.
- Larger maps with continued RealityKit performance tuning.
