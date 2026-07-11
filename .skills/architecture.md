# Architecture

## Purpose

Describe the implemented runtime boundaries so an agent can change the game without mixing rules, persistence, networking, UI, and rendering responsibilities.

## Responsibilities and layers

| Layer | Owns | Must not own |
| --- | --- | --- |
| `Core/Models` | Shared values, balance, action dispatch contract | UI or renderer behavior |
| `Core/Multiplayer` | Wire DTOs, versions, patches, room metadata, clock | Network I/O; none exists here |
| `Core/Systems` | Deterministic rules, generation, simulation, combat, AI | SwiftUI/AppKit state |
| `Gameplay` | Domain models and display metadata | Command orchestration |
| `Core/Persistence` | JSON save encoding | Camera/navigation/UI state |
| `Presentation` | SwiftUI screens, view model, feedback, routing | Rule calculations and direct state mutation |
| `Rendering3D` | RealityKit scene, camera, materials, snapshots | Gameplay rules, saves, navigation |

## Data flow

1. `ContentView` creates a `GameViewModel`; `MenuView` starts a fresh campaign.
2. `GameViewModel` creates a world through `WorldMapSystem`, owns presentation state, and dispatches every mutable command.
3. `LocalCommandDispatcher` validates schema/rules versions, revision, and match status.
4. `GameReducer` applies the payload to a copy-on-failure transaction, calls systems, normalizes deterministic IDs, and evaluates match status.
5. The view model saves accepted changes and projects state to SwiftUI and `World3DStateAdapter`.
6. `World3DRenderer` incrementally updates RealityKit entities from tile snapshots.

## Important models and APIs

- `GameState` — local assembled state: day, towns, world nodes/connections, map, territory, status, news, offers, and entity counter.
- `WorldDefinition` — immutable wire/persistence world data.
- `MatchState` — mutable wire/persistence match data.
- `GameActionPayload` — explicit action discriminator for build, upgrade, training, transfer, attack, trade, and day advance.
- `GameCommandDispatching.dispatch` — command boundary used by the view model.
- `GameReducer.reduce` — deterministic rules entry point.
- `WorldMapSystem.makeInitialState` — deterministic campaign creation.
- `GameSaveStore.save` — current persistence entry point.
- `World3DStateAdapter` — domain-to-render projection.

## Constraints and invariants

State mutations must go through systems/reducer. Presentation-only state stays in `GameViewModel` or views. World generation and reducer outputs must be deterministic. Save and wire models use raw strings for enum/map keys and explicit versions. Changes to serialized names or action cases require migration/version handling.

## Performance

Core systems operate on small town collections and a generated map. Rendering is the performance-sensitive area: meshes/materials are cached, ordinary updates are incremental, terrain scaffolding is rebuilt only for structural changes, and quality adapts to FPS/thermal state.

## Extension points

Add rules in an existing system; add commands through the action/reducer boundary; add domain fields with backward-compatible decoding; add rendering through snapshots and cached resources.

## Known limitations / TODO / Requires Confirmation

- No concrete multiplayer service applies patches or tracks duplicate action IDs.
- Save loading is not implemented in the app.
- The exact future server implementation and transport are not present, so backend ownership beyond the DTO contract requires confirmation.
