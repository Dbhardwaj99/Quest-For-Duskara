# Quest for Duskara Design and Technical Notes

This document records the current design patterns, gameplay systems, and technical intent for the project.

## Product Direction

Quest for Duskara is a cozy medieval strategy simulation game. The target experience is a portrait-mode mobile town-management loop with expandable systems:

- Town construction
- Resource production
- Biome specialization
- Soldier training
- World conquest
- Resource transfer between controlled towns

The game should feel like a deep strategy simulation, not a static prototype.

## Core Loop

1. Player distributes a configurable starting bonus pool.
2. Player enters the active town.
3. Buildings are placed on a grid.
4. Buildings generate resources each game day.
5. Some buildings unlock actions, such as Barracks training.
6. Army strength enables conquest on the world map.
7. Conquered towns produce independently and can receive transfers.

## Data-Driven Balance

`GameConfig.swift` is the main balance source.

It defines:

- Grid size
- Day duration
- Base starting resources
- Bonus pool size
- Building definitions
- Soldier definitions

Building definitions include:

- Base cost
- Base production
- People required
- People gained on build
- Population capacity
- Max level
- Placement rules

Changing balance should usually mean editing config data, not changing UI or simulation code.

## State and Flow

`GameState` stores the persistent game state:

- Current day
- Current day progress
- Town list
- World nodes
- Town connections
- Active town ID

`Town` owns:

- Resource wallet
- Buildings
- Biome layout
- Ownership
- Enemy army strength
- Soldier roster

`GameViewModel` exposes state to SwiftUI and coordinates user intent. It should remain thin enough that game rules stay in systems.

## Placement Design

Placement is centralized through `PlacementValidationSystem`.

The current path is:

1. Build menu calls `beginPlacement(for:)`.
2. `TownGridView` asks `tilePlacementState(for:)` for each tile.
3. Valid tiles render green.
4. Invalid tiles render red/dimmed.
5. Tapping a valid tile calls `BuildingSystem.build`.
6. Tapping an invalid tile shows feedback through `FeedbackOverlaySystem`.

Biome-specific placement uses `BiomeSystem`:

- Wood Mills require adjacency to `.forest`.
- Coal Mines require adjacency to `.mountain`.
- Adjacency means the town tile touches the corresponding border side.

Future placement rules should extend this same validation path.

## Biome Rendering

Biome terrain is drawn with SwiftUI shapes in `BiomeBorderView`.

The renderer uses:

- `BiomeBorderView` for the four-sided terrain container.
- `BiomeTerrainStrip` for per-side rendering.
- layered tree silhouettes for forests.
- layered mountain silhouettes for mountains.

The terrain is not interactive. The scrollable `TownGridView` contains both grid and outer biome terrain so the map can exceed the viewport without clipping important edges.

## Presentation Design

Normal gameplay should avoid system alerts.

Current presentation rules:

- Build menu is a sheet.
- Building details and upgrades are a sheet.
- World map is a full-screen cover.
- Feedback is an in-game toast banner.

This prevents nested presentation conflicts such as trying to show an alert while a sheet is already active.

## UI Patterns

Use compact strategy-game UI:

- Resource pills in the HUD.
- Bottom action bar for common commands.
- Sheets for focused interactions.
- Grid highlights for placement feedback.
- SwiftUI-only placeholder building art.

Avoid marketing-page styling, large decorative cards, or instructional copy inside gameplay screens.

## Performance Notes

The town grid uses a `LazyVGrid` and lightweight SwiftUI shapes.

Avoid:

- Deep nested `GeometryReader` chains.
- Putting all state in one massive observable object.
- Recomputing expensive derived state in every small cell.
- External renderers before the gameplay needs them.

For future larger maps, cache valid placement sets per selected building and town revision if tile counts grow substantially.

## Future Systems

The architecture is intended to support:

- Roads
- Workers
- Logistics
- Research trees
- Weather
- Random events
- AI diplomacy
- Factions
- Trading
- Combat visuals
- Multiplayer

Add these as focused models and systems. Keep UI as a consumer of system output, not the source of truth for game rules.
