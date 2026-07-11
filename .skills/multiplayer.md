# Multiplayer Boundary

## Purpose

Document the implemented protocol-shaped boundary and clearly separate it from the missing network runtime.

## Responsibilities

`WorldDefinition` carries immutable generated-world data. `MatchState` carries mutable towns, lifecycle, day, news, offers, and entity counter. `GameAction`/`GameActionPayload` encode client commands. `GameActionResult` and `GameStatePatch` describe authoritative outcomes. `RoomSession` and `Participant` describe room membership. `ServerClock` converts local time to server time using a measured offset.

## Data flow

Local play: `GameViewModel → GameAction → LocalCommandDispatcher → GameReducer → GameState`. A server integration is intended to submit the same action shape and return a result/patch, but no transport or remote dispatcher is present.

## Rules and invariants

- `schemaVersion` protects wire/persistence shape; `rulesVersion` protects deterministic behavior.
- `expectedRevision` must equal the dispatcher/server revision before application.
- Immutable world data is never part of a patch.
- Patch application is expected to be strict and ordered by revision; the actual client patch service is absent.
- Action IDs are intended as idempotency keys; local dispatch does not store duplicate outcomes.
- All persistent IDs and random events in reducer paths derive from world seed and replicated state.

## Public APIs and models

See `GameCommandDispatching`, `LocalCommandDispatcher.dispatch`, `GameReducer.reduce`, `WorldDefinition.init(state:)`, `MatchState.init(state:roomID:revision:)`, `GameState.init(world:match:)`, and `GameStatePatch.init(actionID:revision:before:after:)`.

## Performance

Patches avoid sending terrain/full world data and replace only changed towns plus small live lists. DTO conversion is linear over towns, news, buildings, and offers.

## Extension points

Add a command to the explicit payload codec, reducer switch, contract fixtures, and any server mirror. Add mutable fields to `MatchState`/`TownState`; add immutable fields to `WorldDefinition`/definition DTOs. Bump the appropriate schema version when compatibility is not preserved.

## Known limitations / TODO / Requires Confirmation

- No server, socket, matchmaking, subscription, patch application, reconnect, or duplicate-action store is in this repository.
- The reducer comment references a TypeScript mirror, but no TypeScript source is present here; mirror location requires confirmation.
