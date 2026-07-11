# Testing and Verification

## Purpose

Describe the current automated safety net and the minimum checks for future changes.

## Test coverage

`Quest For DuskaraTests` covers building, placement, combat, enemy AI, simulation, soldier training, transfers, world generation, action outcomes, replication DTOs, action payload codecs, local command revisions, and deterministic golden fixtures.

Fixtures include a deterministic world generated from seed 42 and an action-outcome scenario. `TestSupport` provides stable UUIDs and canonical JSON comparison.

## Workflows

- Run the shared macOS scheme's test target in Xcode or with `xcodebuild test`.
- For core rule changes, add a focused system test and update the golden fixture only when the behavior change is intentional.
- For DTO/action changes, add round-trip and canonical JSON tests.
- For rendering changes, build with a complete Xcode/Metal toolchain and perform a manual town/map interaction smoke test.

## Invariants to test

Failed actions must be atomic; deterministic seeds must produce stable world/action output; revisions must reject stale actions; roster strength and wallet soldiers must stay synchronized; save/wire round trips must preserve state.

## Known limitations / TODO / Requires Confirmation

The current environment's `xcodebuild test` reaches compilation but fails because the Metal toolchain is unavailable and preview linking fails. This is an environment limitation until reproduced on a complete Xcode installation.
