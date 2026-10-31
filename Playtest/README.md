# Headless playtester

`duskara-playtest` plays Quest for Duskara from a terminal, on Linux, Windows or macOS, with no graphics. It is built for AI agents and scripts that want to play hundreds of campaigns and hunt for balance problems and bugs. A person can drive it too.

It isn't a copy of the rules. The [package](../Package.swift) compiles the app's own `Models/` and `ViewModels/GameViewModel.swift` and drives the view model the way the buttons do. A balance change in `GameConfig.swift` reaches the playtester the moment you rebuild.

## Build

You need Swift 6.2 or later.

| Platform | Command | Binary |
| --- | --- | --- |
| macOS (Xcode 26) | `swift build -c release` | `.build/release/duskara-playtest` |
| Linux | `swift build -c release --static-swift-stdlib` | `.build/release/duskara-playtest` |
| Linux with Docker | `docker run --rm -v "$PWD":/src -w /src swift:6.2 swift build -c release --static-swift-stdlib` | `.build/release/duskara-playtest` |
| Windows | `swift build -c release` | `.build\release\duskara-playtest.exe` |

Run these from the repository root. On Linux, `--static-swift-stdlib` links Swift and Foundation into the binary, so it runs on any recent glibc distribution with nothing installed. On Windows the `.exe` needs the Swift runtime DLLs beside it or on `PATH`.

The [Playtest engine workflow](../.github/workflows/playtest.yml) builds and tests on Linux (x86_64 and arm64) and Windows whenever the rules change. Each run uploads ready-to-use bundles as artifacts: the binary, this README and the prompt.

Run the tests with `swift test`.

## Use

```bash
duskara-playtest new --seed 42 --difficulty medium --session run.json
duskara-playtest act --session run.json "build farm 0 0" "build house 2 0" "end-day 3"
duskara-playtest state --session run.json --view full
duskara-playtest simulate --games 50 --strategy all --difficulty all
duskara-playtest rules
duskara-playtest help
```

[PROMPT.md](PROMPT.md) is the full guide, written as instructions for an AI playtester. To have an agent playtest the game, give it the binary for its platform and `PROMPT.md`.

## How it stays faithful

- **The game's code, unchanged.** The playtester runs every rule, price, enemy decision, capture and lane battle through the app's code. Each command checks the same conditions that enable or hide its button, then calls the same `GameViewModel` method that button calls.
- **Left out:** `Models/DisplayNames.swift` (SwiftUI colours) and `ViewModels/GameSound.swift` (AppKit sounds). `Playtest/Engine/GameSound.swift` is a silent stand-in.
- **Headless tweaks:** the autosave is off (`GameSaveStore(directory: nil)`), the real-time clock is stopped (days pass on `end-day`), and the terrain tiles only the map draws are dropped.
- **Replayable:** `makeNewGame(balance:seed:)` takes a seed, and towns get UUIDs derived from it, so a seed plus a command list replays a campaign exactly. Other platforms' maths libraries may round differently, so seeds aren't guaranteed to match across operating systems.
- **Checked:** after every command it verifies that the shared stockpile paid exactly the price shown, that troops are conserved, that each day's gold, skill and food change equals production minus upkeep, and that buildings and counts stay legal. A failure is reported as a `violation`. States that are allowed but suspicious are reported as `anomalies`.

**Keep SwiftUI, AppKit and RealityKit out of `Models/` and `ViewModels/GameViewModel*.swift`.** The playtester compiles those files on Linux and Windows, and the workflow fails if one of them imports a framework only macOS has.

## Layout

| Path | Contents |
| --- | --- |
| `Engine/PlaytestSession.swift` | One campaign: the view model with its clock stopped, plus session files. |
| `Engine/Commands.swift` | The command language. |
| `Engine/Actions.swift` | Each command, mirroring its button, with the ledger checks. |
| `Engine/BattlePlan.swift` | Plays lane battles from a plan. |
| `Engine/Snapshot.swift` | The state an agent reads. |
| `Engine/Invariants.swift` | Rule checks after every command. |
| `Engine/Bots.swift`, `Engine/Simulation.swift` | Scripted players and the bulk report. |
| `Engine/Rules.swift` | The `rules` tables. |
| `Engine/CLI.swift`, `CLI/main.swift` | The command-line tool. |
| `Tests/` | Swift Testing tests for the playtester. |
