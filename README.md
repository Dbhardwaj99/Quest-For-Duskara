# Quest for Duskara

Quest for Duskara is a native macOS strategy game about founding island towns, managing resources, training soldiers, and sailing against rival cities before dusk overtakes the realm. The world is an archipelago: every city sits on its own procedurally generated island, and the campaign is won by conquering Duskara. The primary game experience is a RealityKit-rendered town board wrapped by SwiftUI HUD, menus, sheets, and world-map controls.

## Technology Stack

- Swift and SwiftUI for app flow, HUD, menus, and gameplay sheets.
- Observation for app-facing state in `GameViewModel`.
- RealityKit in non-AR mode for the interactive town renderer.
- AppKit view-controller hosting where RealityKit needs gesture and lifecycle control.
- Codable JSON persistence through `GameSaveStore` (autosave; every launch starts a new game).
- Deterministic system types for simulation, combat, territory ownership, enemy AI, and persistence-safe state changes.

## Architecture Overview

The project is organized around the runtime boundaries used by the game:

- `App/`: app entry point and root navigation.
- `Core/Models/`: value models and balance configuration shared across systems.
- `Core/Systems/`: deterministic gameplay rules for simulation, building, placement, resources, time, transfer, combat, territory, enemy AI, and conquest.
- `Core/Persistence/`: save support for renderer-agnostic `GameState`.
- `Gameplay/`: domain models and display metadata for buildings, resources, combat, and world data.
- `Presentation/`: SwiftUI screens, components, theme, and `GameViewModel`.
- `Rendering3D/`: RealityKit renderer, camera controller, tile entities, render resources, and state adapter.
- `Assets/`: app asset catalog.
- `docs/`: design notes, contributor guidance, and screenshots.

## World Generation

`WorldGenerator` places one node per town, then `TerrainGenerator` grows an irregular island around each node using shared deterministic hash noise (`WorldNoise`). Open water separates every island; territory (`TerritoryGenerator`) is assigned to land cells only. The `TownConnection` graph remains as data: it scales town defenses by their depth in the archipelago and renders as faint sea lanes on the world map.

## RealityKit Rendering

`GameView` is the only gameplay presentation. It embeds `World3DTownView`, which hosts `World3DTownViewController`. The controller owns an ARView configured in non-AR mode, installs `World3DCameraController`, and asks `World3DRenderer` to render snapshots produced by `World3DStateAdapter`.

The renderer builds the terrain scaffold, open sea, town tiles, buildings, selection state, placement overlays, and adaptive render resources. SwiftUI remains responsible for HUD, build sheets, building details, feedback toasts, and the world map.

## Gameplay Snapshot

- A first-launch tutorial carousel explains the game; it can be skipped and never appears again.
- Start setup offers difficulty presets that seed the first town's gold and skill stockpile.
- Town boards are 3x3. Every town starts with a House and a Pier.
- Resources are gold, food, people, skill, and soldiers.
- Active buildings are House, Pier, Farm, Factory, and Barracks. The Pier brings in gold from sea trade and must be built on the town's edge, by the water.
- Barracks train archers and knights; soldiers consume daily food upkeep.
- The world map shows the archipelago, island territories, faction ownership, and resource transfers between controlled towns.
- Any city in the world can be attacked by sea; attacks succeed only when the attacking army overpowers the defender's effective defense.
- Capturing a town changes its faction, applies resource loss, and reconciles territory ownership.

## Save Behavior

The game autosaves `GameState` continuously, but the menu currently exposes only Start Game: every launch begins a new campaign.

## Build Instructions

1. Open `Quest For Duskara.xcodeproj` in Xcode.
2. Select the `Quest For Duskara` app scheme.
3. Build and run the native macOS app.

## Screenshots

Current reference screenshot:

- `docs/screen.png`

Add new screenshots to `docs/` when UI or renderer changes materially.

## Development Roadmap

- Expand town-building variety and biome-specific rules.
- Persist decorative terrain state where it becomes gameplay relevant.
- Add richer conquest outcomes and enemy town progression.
- Restore save loading once mid-campaign resume is worth supporting.
- Add research, events, weather, and logistics systems.
- Continue tuning RealityKit performance for larger maps and older devices.
