# Design

## Purpose

Capture the implemented product loop and visual language without turning design notes into undocumented requirements.

## Product loop

The player chooses a difficulty, starts with one player town, builds and upgrades, waits through daily production/upkeep, trains soldiers, opens the world map, transfers resources between controlled towns, attacks towns, and wins when Duskara becomes player-controlled.

## Visual philosophy

The project documents a handcrafted miniature direction inspired by Townscaper, Bad North, wooden toys, and coastal villages. Geometry carries detail; forms are soft and readable; colors are calm and pastel; the ocean has motion; deterministic variation makes procedural scenes feel authored. The town board is RealityKit-first with SwiftUI HUD and sheets around it.

## Architecture

`GameView` selects setup, town, map, or victory presentation. `World3DTownView` bridges SwiftUI to an AppKit view controller and RealityKit renderer. `WorldMapView` and `TerritoryRenderer` are SwiftUI projections of generated world/territory state.

## Public interfaces

- `GameViewModel` exposes commands and display projections to views.
- `World3DStateAdapter` exposes `World3DTileSnapshot` values to the renderer.
- `ThemeManager.shared.cycle()` changes the global render theme and triggers later scene rebuilds.

## Constraints

Do not put gameplay rules in view bodies or 3D entity builders. Keep theme changes visual; do not make them mutate game state. Keep camera, sheet, selection, tutorial, and feedback state out of `GameState`/save payloads.

## Performance

Avoid rebuilding `ARView` from SwiftUI updates, per-frame SwiftUI writes, and full-scene rebuilds for ordinary tile changes. Use `World3DRenderResources` caches and adaptive quality.

## Extension points

New visual themes belong in `WorldTheme`/`WorldPalette`; new building visuals belong in `World3DTileEntity` and bundled USDZ assets when appropriate; new map layers belong in the map renderer without changing world rules.

## Known limitations / TODO / Requires Confirmation

- The map has duplicated literal colors rather than consuming the 3D palette directly.
- The app menu currently exposes Start Game only; documented Load Game/Asset Gallery routes are not wired in `ContentView`.
- Accessibility and visual QA beyond the existing screenshot are not comprehensively documented.
