# Simulation and Rules Reducer

## Purpose

Document the deterministic day loop and the transaction boundary for mutable gameplay.

## Responsibilities

`GameReducer` routes actions and restores state on failure. `SimulationSystem` advances days, applies income/upkeep, runs enemy AI, and evaluates victory/defeat. `AuthoritativeClockSystem` and `TimeSystem` derive day progress and request advances. `NewsStore` records the newest 40 events.

## Data flow

An `advanceDay` action increments the day, applies every town's building income and army upkeep, lets enemy AI act every 20th day, updates the server-time day start, regenerates trade offers, normalizes new IDs, and reevaluates match status.

The local view model ticks once per second for display and dispatches as many `advanceDay` actions as authoritative time requires, including catch-up after suspension.

## Invariants

- Reducer failure is atomic: state is restored to the pre-action copy.
- Accepted actions increment revision once.
- Time decisions use server timestamps plus measured offset; local wall-clock values are only the source of the local clock reading.
- News is newest-first and capped at 40.
- Trade generation uses seeded random streams and stable sorting.

## APIs and models

`GameReducer.reduce`, `GameReducer.regenerateTradeOffers`, `SimulationSystem.advanceDay`, `evaluateStatus`, `TimeSystem`, `AuthoritativeClockSystem`, `NewsEvent`, and `NewsStore.record`.

## Performance

The day loop is linear in towns and buildings; catch-up can dispatch multiple days after suspension. Keep daily systems deterministic and avoid UI work in the loop.

## Extension points

Add new daily rules to `SimulationSystem` or a focused system, then include them in reducer fixtures. Add new commands to the reducer switch and version contracts.

## Known limitations / TODO / Requires Confirmation

- The reducer comments refer to an external TypeScript mirror that is not in this repository.
- Match defeat is derived when no player town remains; there is no separate defeat screen in the current `GamePhase` enum.
