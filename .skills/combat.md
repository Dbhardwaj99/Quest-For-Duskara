# Combat and Conquest

## Purpose

Document deterministic army strength, defense, attack resolution, casualties, capture, and enemy combat.

## Responsibilities

`SoldierRoster` is the unit-level army model. `SoldierTrainingSystem` creates units. `CombatSystem` calculates effective defense, winner survivors, casualties, and graph distances. `WorldMapSystem` commits attacks/captures. `OccupationSystem` applies resource loss. `EnemyAISystem` makes deterministic enemy actions.

## Data flow

`WorldMapView → GameViewModel.attackTown → GameAction.attack → GameReducer → WorldMapSystem.attack → CombatSystem + OccupationSystem + TerritorySystem → GameState`.

## Rules

- Archer power is 10 and Knight power is 20 in the default balance.
- The player can attack a non-player town when attacker strength is strictly greater than effective defense.
- The reducer commits whole roster units where possible and uses legacy raw strength for old saves.
- The winner loses `combatWinnerCasualtyRate` of the committed force; survivors become a whole-unit garrison, rounding a non-zero remainder up to the weakest unit.
- Failed attacks consume the committed attacking force and reduce defender strength by the committed amount.
- Capture applies configured gold/skill loss, changes faction, replaces target garrison with survivors, and reconciles territory.
- Capturing Duskara produces victory status through `SimulationSystem.evaluateStatus`.
- Enemy AI acts every 20 days, develops infrastructure, trains at most one unit per town turn, and attacks adjacent eligible targets while retaining an AI reserve.

## Models and APIs

`SoldierDefinition`, `SoldierRoster`, `CombatSystem.effectiveDefenseStrength`, `winnerSurvivors`, `WorldMapSystem.resolveAttack`, `OccupationSystem.applyCapturePenalties`, and `SimulationSystem.evaluateStatus`.

## Constraints and performance

Combat math must stay deterministic and independent of UI/time. Roster strength and the compatibility `armyStrength` field must be kept synchronized by rule paths.

## Extension points

Add units through definitions and roster ordering, not ad hoc strength constants. Add new combat effects in `CombatSystem`/`OccupationSystem` and cover them with deterministic tests/fixtures.

## Known limitations / TODO / Requires Confirmation

- There is no combat animation or battle scene; combat is state-only.
- Player attacks are global while enemy attacks are graph-adjacent; this asymmetry is implemented but may need game-design confirmation.
