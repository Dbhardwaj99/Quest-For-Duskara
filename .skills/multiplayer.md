# Multiplayer Boundary

## Purpose

Document the Firebase-backed cooperative runtime and its replication boundary.

## Responsibilities

`WorldDefinition` carries immutable generated-world data. `MatchState` carries mutable towns, lifecycle, day, news, offers, and entity counter. `GameAction`/`GameActionPayload` encode client commands. `GameActionResult` and `GameStatePatch` describe authoritative outcomes. `RoomSession` and `Participant` describe room membership. `ServerClock` converts local time to server time using a measured offset.

## Data flow

Local play remains `GameViewModel → GameAction → LocalCommandDispatcher → GameReducer → GameState`. Multiplayer uses `GameViewModel → MultiplayerCommandGateway → callable function → TypeScript reducer → Firestore transaction`, then applies consecutive RTDB patches through `RoomReplicationService`. Revision gaps recover from the Firestore checkpoint.

## Rules and invariants

- `schemaVersion` protects wire/persistence shape; `rulesVersion` protects deterministic behavior.
- `expectedRevision` must equal the dispatcher/server revision before application.
- Immutable world data is never part of a patch.
- Patch application is strict and ordered by revision; duplicates are ignored and gaps trigger recovery.
- The server persists each action ID outcome transactionally; reconnect retries the same pending IDs.
- All persistent IDs and random events in reducer paths derive from world seed and replicated state.

## Public APIs and models

See `GameCommandDispatching`, `LocalCommandDispatcher.dispatch`, `GameReducer.reduce`, `WorldDefinition.init(state:)`, `MatchState.init(state:roomID:revision:)`, `GameState.init(world:match:)`, and `GameStatePatch.init(actionID:revision:before:after:)`.

## Performance

Patches avoid sending terrain/full world data and replace only changed towns plus small live lists. DTO conversion is linear over towns, news, buildings, and offers.

## Extension points

Add a command to the explicit payload codec, reducer switch, contract fixtures, and any server mirror. Add mutable fields to `MatchState`/`TownState`; add immutable fields to `WorldDefinition`/definition DTOs. Bump the appropriate schema version when compatibility is not preserved.

## Schema and migration safeguards

- `schemaVersion` and `rulesVersion` remain `1`; mismatches are rejected before reduction.
- Existing `GameSaveStore` files remain local-only. The separate room cache contains only room ID, checkpoint/revision, and pending idempotent actions.
- World definitions are immutable after room start. Ordinary actions never resend terrain or a full match state.
- FCM sends room/day/reconnect prompts only and is never replication transport.
