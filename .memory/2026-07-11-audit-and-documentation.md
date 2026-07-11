# 2026-07-11 — Full audit and AI documentation

## What changed

- Added the AI-first documentation set under `.skills/`.
- Added persistent memory guidance and this audit note under `.memory/`.
- Renamed `Difficulty.modebalance` to `Difficulty.modeBalance` and updated its caller for clarity.

## Why

The repository already has a coherent Core → Gameplay → Presentation/Rendering boundary and a recently added deterministic replication boundary. Documentation was fragmented across `README.md`, `docs/agents.md`, and `docs/design.md`; the new entry point makes implemented behavior, constraints, and missing systems explicit for future agents.

## Files modified

- `.skills/skills.md`
- `.skills/architecture.md`
- `.skills/design.md`
- `.skills/multiplayer.md`
- `.skills/world-map.md`
- `.skills/city.md`
- `.skills/economy.md`
- `.skills/combat.md`
- `.skills/inventory.md`
- `.skills/simulation.md`
- `.skills/persistence.md`
- `.skills/rendering.md`
- `.skills/testing.md`
- `.memory/README.md`
- `.memory/2026-07-11-audit-and-documentation.md`
- `Core/Models/Difficulty.swift`
- `Presentation/ViewModels/GameViewModel.swift`
- `Presentation/Views/StartSetupView.swift`
- `README.md`
- `docs/agents.md`
- `docs/design.md`

## Architectural decisions

- Preserve the existing reducer/action boundary and immutable-world/mutable-match split.
- Do not add a speculative network service, save loader, or large rendering split during a documentation/audit pass.
- Record oversized renderer/presentation files as technical debt because mechanical extraction could change access boundaries without a reliable Metal build.

## Audit findings and assumptions

- The executable is macOS-only with SwiftUI, Observation, AppKit, RealityKit, and Metal.
- Current gameplay is local; multiplayer types are protocol scaffolding without transport.
- Saves are written atomically as `duskara-save.json` but never loaded by the app.
- The app menu currently exposes Start Game only.
- Player attacks are global; enemy AI attacks graph-adjacent towns.
- `GameState`/DTO determinism and backward-compatible decoding are compatibility invariants.

## Known issues

- `xcodebuild test` could not complete in this environment: the Metal toolchain is missing for `OceanShaders.metal`, and preview linking also fails. This is not evidence of a source regression.
- Several renderer/presentation files exceed the preferred ~300-line limit.
- Existing human-facing docs contain stale Load Game/Asset Gallery descriptions; the new `.skills/` docs call this out.

## Verification

- `git diff --check` passes.
- All `.skills/` and `.memory/` Markdown files are non-empty and the documentation index resolves to files in `.skills/`.
- The `modeBalance` rename has no remaining source callers using the old spelling.
- `xcodebuild ... build` still stops at the pre-existing environment/toolchain failures noted above.

## Follow-up work

1. Verify the documented architecture against a complete Xcode/Metal build.
2. Add save loading with migration tests before exposing Load Game.
3. Decide the multiplayer transport/server ownership and implement patch application/idempotency.
4. Split oversized renderer/presentation files along tested cohesive boundaries.
5. Unify map and 3D palette sources if visual drift becomes a problem.
