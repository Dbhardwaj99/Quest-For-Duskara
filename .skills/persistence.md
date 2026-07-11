# Persistence

## Purpose

Document what is saved, how it is encoded, and what compatibility must be preserved.

## Responsibilities

`GameSaveStore` writes `SavedGame` as pretty-printed, sorted-key JSON to the user Documents directory using an atomic write. `SavedGame` stores schema version, day label, immutable `WorldDefinition`, and mutable `MatchState`.

## Data flow

Accepted gameplay changes call `GameViewModel.saveCurrentGame()`. The save store converts `GameState` to `WorldDefinition` and `MatchState`, encodes JSON, and writes `duskara-save.json`.

## Compatibility rules

- Keep raw enum strings, DTO keys, UUID string formats, schema versions, and backward-compatible decode defaults stable.
- `Town` and `GameState` include custom decoding for older faction/army/world fields.
- Save data contains gameplay state, not SwiftUI phase, selection, active town, camera, sheet, tutorial, renderer, or debug state.
- `SchemaVersion.current` and `SchemaVersion.rules` are stamped into payloads.

## APIs and models

`SavedGame`, `GameSaveStore.save`, `GameSaveStore.dayLabel`, `WorldDefinition`, and `MatchState`.

## Performance and safety

Writes are atomic and payload size is dominated by generated terrain/territory data. Do not write per-frame renderer state. Save errors become in-game feedback.

## Extension points

Implement load by decoding `SavedGame`, validating schema/rules, rebuilding `GameState.init(world:match:)`, and initializing the view model in town phase. Add migration only with explicit version handling and fixtures.

## Known limitations / TODO / Requires Confirmation

The store is currently write-only. `ContentView` creates a fresh `GameViewModel` on launch and `MenuView` has no Load Game action. Do not document resume as implemented until this changes.
