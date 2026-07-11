# Quest for Duskara — AI Agent Entry Point

## Project overview

Quest for Duskara is a native macOS strategy game built with Swift, SwiftUI, Observation, AppKit, RealityKit, and Metal. The player builds island towns, produces resources, trains soldiers, conquers towns, and ultimately captures Duskara before the day cycle defeats the campaign.

The current executable is local single-player. Its gameplay commands and state are already shaped around a future authoritative multiplayer protocol, but no network transport or server implementation exists in this repository.

## Repository structure

- `App/` — app entry point and root navigation.
- `Core/Models/` — shared value types, balance, placement, resources, and command dispatch.
- `Core/Multiplayer/` — wire DTOs, action payloads, patches, room metadata, schema versions, and server-clock support.
- `Core/Systems/` — deterministic gameplay rules and world generation.
- `Core/Managers/` — small presentation coordination values.
- `Core/Persistence/` — renderer-independent JSON save encoding.
- `Gameplay/` — building, soldier, resource-display, and world domain models.
- `Presentation/` — SwiftUI views, view model, components, and theme.
- `Rendering3D/` — RealityKit/AppKit town renderer, camera, entities, resources, ocean, and state adapter.
- `Quest For DuskaraTests/` — Swift Testing tests, deterministic fixtures, and replication contract coverage.
- `Assets/` — app icon catalog and bundled USDZ building assets.
- `docs/` — existing human-facing design and handoff notes.
- `tools/` — Blender asset-generation script; it is not part of the app target.

## Architecture summary

`GameState` is the local working model. `WorldDefinition` contains immutable generated-world data for replication; `MatchState` contains mutable match data. Player intent becomes a `GameActionPayload`, passes through `LocalCommandDispatcher`, and is applied by `GameReducer`. Core systems own rules; `GameViewModel` coordinates presentation, dispatch, clock ticks, feedback, and saves. SwiftUI renders UI. `World3DStateAdapter` projects state into render snapshots, and RealityKit renders those snapshots.

Primary flow:

`SwiftUI/AppKit input → GameViewModel → GameAction → dispatcher → GameReducer → Core systems → GameState → save + SwiftUI/RealityKit projections`

## Design philosophy

The visual direction is a calm, handcrafted miniature: geometry over textures, soft pastel materials, warm readable silhouettes, small deterministic details, and a living ocean. See [`design.md`](design.md) and [`rendering.md`](rendering.md).

## Coding conventions

- Use PascalCase for types and camelCase for members.
- Keep rules in `Core/Systems`; do not duplicate rules in views, view models, or renderer entities.
- Prefer value types and deterministic functions for gameplay state.
- Use `Codable` deliberately at persistence and replication boundaries.
- Use stable ordering whenever a `Set` or dictionary can affect replicated results.
- Avoid force unwraps and speculative abstractions.
- Keep `@MainActor` around UI, RealityKit, and Observation-owned code.
- Preserve raw-value enum strings and DTO field names unless a versioned migration is added.

## Documentation index

- [`architecture.md`](architecture.md) — layers, state ownership, data flow, APIs, and invariants.
- [`design.md`](design.md) — product loop and visual/design decisions.
- [`multiplayer.md`](multiplayer.md) — replication boundary and current transport gap.
- [`world-map.md`](world-map.md) — generated map, territories, routes, and map UI.
- [`city.md`](city.md) — town model, buildings, placement, and town interaction.
- [`economy.md`](economy.md) — resources, production, upkeep, trade, and difficulty.
- [`combat.md`](combat.md) — armies, attacks, defense, capture, and AI combat.
- [`inventory.md`](inventory.md) — resource wallets, soldier rosters, and transfer rules.
- [`simulation.md`](simulation.md) — day advancement, clock, news, and deterministic reducer behavior.
- [`persistence.md`](persistence.md) — save payload and compatibility constraints.
- [`rendering.md`](rendering.md) — SwiftUI/RealityKit boundary and performance rules.
- [`testing.md`](testing.md) — test inventory, fixtures, and verification workflow.

## Feature summaries

- **City:** 3×3 town boards begin with a House and shoreline Pier. Buildings can be built and upgraded through shared placement and balance definitions.
- **Economy:** Gold, food, people, skill, and soldiers are stored in `ResourceWallet`; buildings produce income once per day.
- **Combat:** deterministic strength comparison with whole-unit rosters, casualties, capture loss, faction changes, and victory on Duskara capture.
- **World map:** generated archipelago, town nodes, sea connections, terrain, landmarks, territories, map selection, conquest, and transfers.
- **Multiplayer foundation:** versioned actions and DTOs, revisions, patches, immutable world data, and authoritative timestamps; no transport.
- **Rendering:** RealityKit town board with bundled USDZ building models, procedural detail, ocean shader, adaptive quality, and camera gestures.

## Common development workflows

1. Open `Quest For Duskara.xcodeproj` and use the shared `Quest For Duskara` scheme.
2. Build/run the macOS target in Xcode.
3. Run the test target when the local Xcode/Metal toolchain is available.
4. For a gameplay change, update the relevant system, add or update a focused test/fixture, then update the relevant `.skills/` document and `.memory/` note.
5. For a new replicated action, update `GameActionPayload`, reducer handling, DTO/patch implications, schema/rules version policy, and replication tests together.
6. For a renderer change, preserve snapshot input, incremental updates, cache use, and main-actor ownership.

## Important invariants

- `GameReducer` must leave state unchanged when an action fails.
- Accepted commands advance the dispatcher revision exactly once.
- `WorldDefinition` is immutable after match creation; mutable factions and town state belong in `MatchState`/`GameState`.
- Replicated enum values, resource keys, action discriminators, and DTO fields are compatibility contracts.
- Gameplay randomness and minted persistent IDs must be deterministic from world seed/state, never wall-clock randomness.
- Day progress is derived from `dayStartServerMillis` and `ServerClock`; clients do not accumulate gameplay time locally.
- The soldier roster is canonical when units exist; `armyStrength` remains for compatibility with legacy raw garrisons.
- Presentation state such as active town, selection, sheets, camera, and tutorial flags is not save/replication state.
- Terrain/territory generation must remain stable for a given seed and algorithm version.

## Extension guidelines

- Add a resource by updating `ResourceKind`, display metadata, balance, and every rule that should consume/produce it; add tests for affordability and persistence.
- Add a building through `BuildingKind`, `GameBalance.buildingDefinitions`, placement rules, presentation metadata, and renderer visuals only when needed.
- Add a soldier through `SoldierKind`, its definition, roster tests, training, upkeep, and combat implications.
- Add a command in the shared action boundary, never as a direct view-model mutation.
- Add map behavior to the world/territory systems; keep map views as projections and interaction surfaces.
- Prefer extending an existing system over introducing a parallel service with one implementation.
- Keep new source files focused; the repository currently has several older rendering and presentation files above the preferred ~300-line limit, recorded below as debt.

## Known technical debt

- `GameSaveStore` writes a versioned save but the app does not load it; every launch creates a new campaign.
- There is no network transport, server, subscription loop, patch application service, or idempotency store. `GameActionResult.duplicate` is a protocol shape, not an implemented local behavior.
- The app currently exposes Start Game only. Existing human docs that describe Load Game or an Asset Gallery route are partially stale; verify against `MenuView` and `ContentView` before relying on them.
- `GameViewModel`, `WorldMapView`, `TerritoryRenderer`, `World3DRenderer`, `World3DTileEntity`, and some renderer resource files exceed the preferred file size. Split only along tested cohesive boundaries.
- `Gameplay/Resources/ResourceDisplay.swift` imports SwiftUI, so display metadata is not fully separated from domain data.
- Map colors in `TerritoryRenderer` are literals that can drift from `WorldPalette`.
- The current build/test environment lacks the Metal toolchain required by `OceanShaders.metal`; verify on a complete Xcode installation.

## Future roadmap (identified, not assumed)

Restore save loading; add a real multiplayer transport/server; expand building, research, events, weather, logistics, enemy progression, conquest outcomes, combat visualization, persistent decorative terrain, and larger-map performance tuning. These are roadmap items from existing project notes, not current features.

## Guardrails

- Never break existing functionality.
- Preserve the project's architectural patterns.
- Do not move business logic into UI, rendering, or presentation layers.
- Prefer extending existing systems over creating duplicate ones.
- Avoid unnecessary abstractions.
- Keep files focused on a single responsibility.
- No source file should exceed approximately **300 lines**. Split large files into cohesive components when appropriate.
- Minimize coupling and maximize cohesion.
- Remove dead code, obsolete abstractions, duplicated logic, and unused assets where safe.
- Improve naming where it increases clarity.
- Keep public APIs stable unless a migration is performed.
- Preserve save compatibility, networking compatibility, and persistence unless explicitly refactoring them.
- Maintain performance characteristics or improve them.
- Every significant architectural decision should be reflected in the documentation.
- After every successful implementation, update the relevant documentation before finishing.
