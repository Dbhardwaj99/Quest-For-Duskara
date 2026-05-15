# Agent Handoff Notes

This file gives future coding agents the minimum context needed to work safely on Quest for Duskara.

## Current State

The project is a SwiftUI iOS game prototype with a modular architecture. It is already playable and should be modified incrementally. Do not collapse the project into one file or rewrite the system architecture.

Important current systems:

- `ResourceSystem` applies resource changes and spending.
- `SimulationSystem` advances days and applies building income.
- `BuildingSystem` builds and upgrades structures.
- `PlacementValidationSystem` owns tile placement validation.
- `BiomeSystem` owns biome adjacency checks.
- `WorldMapSystem` creates towns, connections, and conquest behavior.
- `TransferSystem` moves resources between owned towns.
- `SoldierTrainingSystem` trains soldier counts and power.
- `FeedbackOverlaySystem` maps system failures to in-game feedback text.

`GameViewModel` is the main app-facing coordinator. It should call systems instead of duplicating rules. Keep it as a coordinator, not a dumping ground for simulation logic.

## Recent UX Decisions

- Building details are presented in `BuildingDetailsSheetView`, not inline below the grid.
- Normal gameplay feedback uses `feedback` and `FeedbackToastView`, not system alerts.
- Build menu selection enters placement mode.
- Placement mode highlights valid tiles green and invalid tiles red.
- Invalid placement taps show lightweight feedback and do not dismiss sheets or present alerts.
- `TownGridView` is scrollable in both directions so biome terrain around the grid remains reachable.

## Architecture Rules

- Keep balance values in `GameConfig.swift`.
- Keep gameplay rules in `Systems/`.
- Keep reusable drawing and UI controls in `Components/`.
- Keep screen composition in `Views/`.
- Keep state models value-based where practical.
- Avoid introducing Combine. Prefer SwiftUI Observation and plain Swift systems.
- Avoid external assets for now. Use SwiftUI shapes.
- Avoid SpriteKit, RealityKit, and custom render engines unless explicitly requested.

## Common Extension Points

Add a resource:

1. Add a case to `ResourceKind`.
2. Add display metadata in `ResourceDisplay.swift`.
3. Add starting or production balance values in `GameConfig.swift`.
4. Update UI only if the new resource needs special handling.

Add a building:

1. Add a case to `BuildingKind`.
2. Add visual color in `ResourceDisplay.swift`.
3. Add a `BuildingDefinition` in `GameConfig.swift`.
4. Add custom visual details in `BuildingArtView` if needed.
5. Add placement rules via `PlacementRule` and `PlacementValidationSystem`.

Add a biome:

1. Add a case to `BiomeKind`.
2. Add terrain drawing in `BiomeTerrainStrip`.
3. Add any rules in `BiomeSystem` or `PlacementValidationSystem`.
4. Update world layouts in `WorldMapSystem`.

Add a rule:

1. Extend `PlacementRule` or create a new focused rule model.
2. Implement validation in `PlacementValidationSystem`.
3. Add feedback mapping in `FeedbackOverlaySystem`.

## Validation

Use Xcode build after changes. Also check navigator warnings. If editing SwiftUI views, render a preview when practical.

Do not use alerts for normal gameplay interactions. Alerts caused presentation conflicts when a sheet was already active.
