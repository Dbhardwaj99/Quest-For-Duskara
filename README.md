# Quest for Duskara

Quest for Duskara is a portrait-oriented iOS strategy game about founding towns, managing resources, training soldiers, and expanding across a connected world map before dusk overtakes the realm. The primary game experience is a RealityKit-rendered town board wrapped by SwiftUI HUD, menus, sheets, and world-map controls.

## Technology Stack

- Swift and SwiftUI for app flow, HUD, menus, and gameplay sheets.
- Observation for app-facing state in `GameViewModel`.
- RealityKit in non-AR mode for the interactive town renderer.
- UIKit view-controller hosting where RealityKit needs gesture and lifecycle control.
- Codable JSON persistence through `GameSaveStore`.

## Architecture Overview

The project is organized around the runtime boundaries used by the game:

- `App/`: app entry point and root navigation.
- `Core/Models/`: value models and balance configuration shared across systems.
- `Core/Systems/`: deterministic gameplay rules for simulation, building, placement, resources, time, transfer, and conquest.
- `Core/Persistence/`: save and load support for renderer-agnostic `GameState`.
- `Gameplay/`: domain models and display metadata for buildings, resources, combat, and world data.
- `Presentation/`: SwiftUI screens, components, theme, and `GameViewModel`.
- `Rendering3D/`: RealityKit renderer, camera controller, tile entities, render resources, and state adapter.
- `Assets/`: app asset catalog.
- `docs/`: design notes, contributor guidance, and screenshots.

## RealityKit Rendering

`GameView` is the only gameplay presentation. It embeds `World3DTownView`, which hosts `World3DTownViewController`. The controller owns an ARView configured in non-AR mode, installs `World3DCameraController`, and asks `World3DRenderer` to render snapshots produced by `World3DStateAdapter`.

The renderer builds the terrain scaffold, biome ring, town tiles, buildings, selection state, placement overlays, and adaptive render resources. SwiftUI remains responsible for HUD, build sheets, building details, feedback toasts, and the world map.

## Save and Load

Saves contain `GameState`, not presentation state. `MenuView` exposes Start Game, Load Game, and Asset Gallery. Start Game creates a fresh `GameViewModel` and opens `GameView`; Load Game restores `GameState` into `GameViewModel(savedState:)` and opens the same `GameView` path.

## Build Instructions

1. Open `Quest For Duskara.xcodeproj` in Xcode.
2. Select the `Quest For Duskara` app scheme.
3. Build and run on an iOS simulator or device that supports RealityKit.

## Screenshots

Current reference screenshot:

- `docs/screen.png`

Add new screenshots to `docs/` when UI or renderer changes materially.

## Development Roadmap

- Expand town-building variety and biome-specific rules.
- Persist decorative terrain state where it becomes gameplay relevant.
- Add richer conquest outcomes and enemy town progression.
- Add research, events, weather, and logistics systems.
- Continue tuning RealityKit performance for larger maps and older devices.
