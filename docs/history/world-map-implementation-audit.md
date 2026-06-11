# World Map Implementation Audit

## Executive Summary

The codebase currently has a fixed world map made of 25 predefined towns, normalized node positions, and undirected town connections. Each town stores ownership through `Town.faction`, and the world-map systems support visiting owned towns, transferring resources between owned towns, attacking adjacent non-owned towns, capturing towns, Duskara victory, enemy turns, daily economy simulation, and save/load of the full world state.

The functional gameplay loop today is: start in Hearthglen, grow the active town through the city-building economy, train soldiers, open the world map, attack an adjacent weaker town from the active town, capture it, switch to owned towns, transfer resources or soldiers between owned towns, and continue toward Duskara. Enemy-owned towns can periodically build, train, and attack adjacent non-enemy towns.

Major missing pieces for the requested empire-conquest fantasy are city founding, dynamic expansion beyond the fixed map, territory/borders/influence, travel time or pathfinding movement, explicit field armies, and richer conquest control beyond immediate ownership flips.

## World Map Architecture

### Core Models

- `TownFaction` in `Gameplay/World/WorldModels.swift`: `.player`, `.neutral`, `.enemy`, `.duskara`.
- `Town`: stores town identity, resources, buildings, biome layout, `faction`, `isDuskara`, `armyStrength`, and `soldierRoster`.
- `WorldTownNode`: stores a town ID and normalized map coordinates `x` / `y`.
- `TownConnection`: stores undirected graph edges between two town IDs, with helpers for containment and connection checks.
- `GameState`: stores `day`, `elapsedSecondsInDay`, all `towns`, all `worldNodes`, all `connections`, `activeTownID`, and `newsEvents`.
- `TransferOrder`: stores resource transfer requests between two town IDs.

### View Models

- `GameViewModel` owns the current `GameState` and mediates world-map actions.
- Relevant world-map-facing state and computed values:
  - `isWorldMapPresented`
  - `activeTown`
  - `activeArmyStrength`
  - `empireArmyStrength`, calculated as the sum of `armyStrength` across player-controlled towns.
- Relevant world-map actions:
  - `switchToTown(_:)`
  - `attackTown(_:)`
  - `canAttack(_:)`
  - `effectiveDefenseStrength(for:)`
  - `isAdjacentToActiveTown(_:)`
  - `transfer(_:amount:to:)`

### Systems

- `WorldMapSystem`: creates the initial world, creates fixed connections, computes adjacency, validates player attacks, resolves attacks, applies capture results.
- `CombatSystem`: computes effective defense and winner survivors.
- `OccupationSystem`: applies resource penalties on capture.
- `TransferSystem`: transfers resources and soldiers between player-controlled towns.
- `EnemyAISystem`: periodically develops enemy towns, trains soldiers, and attacks adjacent non-enemy targets.
- `SimulationSystem`: advances days, applies income/upkeep to every town, and triggers enemy AI every 20 days.
- `ArmyUpkeepSystem`: consumes food for armies and reduces army strength if food is insufficient.
- `GameSaveStore`: saves and loads the full `GameState`.
- `NewsStore`: records city capture, Duskara attack, training, construction, and transfer events.

### Views

- `GameView`: presents `WorldMapView` as a full-screen cover from the bottom bar world button.
- `WorldMapView`: draws the graph, town nodes, ownership colors/icons, adjacency highlight, selected-town panel, Visit/Attack buttons, resource display, and transfer panel.
- `NewsFeedPanel` in `GameView`: displays world event history.

### Data Flow

1. `ContentView` creates or loads a `GameViewModel`.
2. `GameViewModel` initializes `state` with `WorldMapSystem.makeInitialState(balance:)` or from `GameSaveStore`.
3. `GameView` opens `WorldMapView` through `isWorldMapPresented`.
4. `WorldMapView` reads `viewModel.state.worldNodes`, `state.connections`, and `state.towns` to render the map.
5. User actions call `GameViewModel` methods.
6. `GameViewModel` delegates to `WorldMapSystem`, `TransferSystem`, or other systems, mutates `GameState`, records news, and saves.
7. `SimulationSystem.advanceDay` mutates town resources/upkeep and may run `EnemyAISystem`.

## City Ownership

Ownership is stored per town in `Town.faction`. `Town.isPlayerControlled` is a computed property that returns `faction == .player`. `Town.setFaction(_:)` changes ownership by assigning `faction`.

Initial towns are created in this order:

| Town | Initial Ownership | Notes |
| --- | --- | --- |
| Hearthglen | Player | Initial active town. Receives base starting resources and starts with `armyStrength = 0`. |
| Green Hollow | Neutral | Fixed map town. |
| Ironridge | Neutral | Fixed map town. |
| Mosswatch | Neutral | Fixed map town. |
| Ashbarrow | Neutral | Fixed map town. |
| Pinefall | Neutral | Fixed map town. |
| Stonewake | Neutral | Fixed map town. |
| Rivergate | Neutral | Fixed map town. |
| Brindle Keep | Neutral | Fixed map town. |
| Oakmere | Neutral | Fixed map town. |
| Frostford | Neutral | Fixed map town. |
| Briarwall | Neutral | Fixed map town. |
| Duskara | Duskara | Marked with `isDuskara = true`; capturing it sets victory. |
| Sunreach | Neutral | Fixed map town. |
| Valehold | Neutral | Fixed map town. |
| Cinder Pass | Neutral | Fixed map town. |
| Deepwood | Neutral | Fixed map town. |
| Crownhill | Neutral | Fixed map town. |
| Greyfen | Neutral | Fixed map town. |
| Moonford | Neutral | Fixed map town. |
| Redspire | Neutral | Fixed map town. |
| Westmere | Neutral | Fixed map town. |
| Northbarrow | Neutral | Fixed map town. |
| Dawnfield | Neutral | Fixed map town. |
| Elderwick | Enemy | Initial Red Kingdom enemy town. |

Ownership changes only through successful attack resolution in `WorldMapSystem.resolveAttack(...)`. On capture, the system applies occupation penalties, sets the target faction to the attacker faction, assigns survivor strength to the captured town, syncs the town's soldiers resource, and clears its detailed roster.

Ownership currently affects:

- Whether a town can be visited: `switchToTown(_:)` only allows player-controlled towns.
- Whether a town can be attacked by the player: target must be non-player, adjacent to active town, and weaker than the active town's army after defense calculation.
- Whether transfers are allowed: both source and destination must be player-controlled.
- How nodes render in `WorldMapView`: player towns are green, Duskara is purple, enemy towns are red, neutral towns are gray.
- Which towns contribute to `empireArmyStrength`: player-controlled towns only.
- Enemy AI target selection: enemy towns skip attacking other `.enemy` towns but can attack player, neutral, or Duskara towns.
- Active town sanitation: if active town is no longer player-controlled, the view model selects the first remaining player town.

## World Map Navigation

Cities are connected by `TownConnection` edges generated from town order. Connections are undirected and include horizontal, vertical, and diagonal-forward links based on a five-row layout.

Movement between cities is implemented as instant active-town switching through `GameViewModel.switchToTown(_:)`. The only restriction is ownership: the destination must be player-controlled. There is no travel cost, travel time, route selection, unit movement, cooldown, or distance restriction for visiting owned towns.

Player attacks are restricted to adjacent towns only. `WorldMapSystem.canAttack(...)` checks that the source is player-controlled, the target is not player-controlled, the source and target are directly connected, and source `armyStrength` is greater than the target's effective defense.

Pathfinding is partially implemented only for internal distance calculations. `WorldMapSystem` and `CombatSystem` each contain breadth-first graph distance helpers used for initial defense scaling and distance-from-Duskara defense bonuses. There is no exposed gameplay pathfinding for movement, route planning, travel, or multi-hop attacks.

## Territory / Empire Systems

| System | Status | Evidence |
| --- | --- | --- |
| Territory control | Partially Implemented | Town-level ownership exists through `Town.faction`; there is no area/hex/region territory layer. |
| Border systems | Missing | Connections are drawn as graph edges, but there is no border model or border calculation. |
| Influence systems | Missing | No influence field, pressure, loyalty, culture, or control radius exists in world-map code. |
| Expansion systems | Partially Implemented | Expansion by conquest exists through capture; founding new cities or dynamically adding nodes is missing. |
| Empire size calculations | Partially Implemented | `empireArmyStrength` sums player army strength, but there is no count/area/economy-based empire size model. |

## Military Systems

| System | Status | Evidence |
| --- | --- | --- |
| Army storage | Implemented | `Town.armyStrength` stores aggregate strength; `Town.soldierRoster` stores archer/knight counts when available. Captures/transfers often clear rosters and keep aggregate strength. |
| Army movement | Partially Implemented | Soldier transfer between owned towns exists and is instant. There are no independent armies, travel time, or movement orders. |
| Army transfers | Implemented | `TransferSystem` can transfer `.soldiers` between two player-controlled towns and updates both `armyStrength` and soldier resources. |
| Attacks | Implemented | Player attacks use active town vs adjacent non-player target. Enemy AI attacks adjacent non-enemy targets every 20 days when thresholds pass. |
| Battles | Partially Implemented | Battles resolve immediately by comparing attack strength to effective defense. There is no battle screen, tactics, randomness, siege, duration, or partial occupation. |
| City capture | Implemented | Successful attacks apply capture penalties, flip faction, assign survivors, sync soldier resources, record news, and trigger victory if Duskara is captured by the player. |

## Resource Interaction

City resources that affect the world map:

- `soldiers` / `armyStrength`: determines attack eligibility, defense, capture survivors, transfers, upkeep, and empire army total.
- `gold`, `skill`, `food`, `people`: indirectly affect the world map by enabling city growth, barracks construction, soldier training, enemy AI development, and army upkeep.
- `food`: directly affects military sustainability through daily upkeep; insufficient food reduces army strength.
- `gold` and `skill`: reduced by capture penalties.

World map actions that consume or mutate resources:

- Player attack consumes the committed active-town army strength. On success, committed soldiers leave the source town and survivors become the target garrison. On failure, committed soldiers are lost and the target garrison is reduced by up to the attack strength.
- Capture applies `captureResourceLossRates` to target `gold` and `skill`, currently 50% each.
- Resource transfers move selected resources from active town to another player-controlled town. The UI excludes `people` from transfer options.
- Soldier transfers move aggregate army strength between owned towns.
- Daily simulation applies income and army upkeep to every town, regardless of ownership.

## AI World Behavior

Expansion behavior is partially implemented as conquest-only expansion. Every 20 days, each `.enemy` town may attack an adjacent non-enemy town if it has a stable economy, army strength above reserve, and enough strength to beat target defense plus reserve.

Attack behavior is implemented. Enemy AI ranks valid adjacent targets by Duskara first, then closer-to-Duskara by map coordinate distance, then lower defense. It commits `sourceStrength - aiReserveThreshold` and uses the same `WorldMapSystem.resolveAttack(...)` capture logic as the player, with attacker faction `.enemy`.

City management behavior is partially implemented. Enemy towns attempt to build missing infrastructure in priority order `house`, `farm`, `barracks`, `factory`, then train archers or knights if possible.

Strategic decision making is limited. The AI has threshold checks, adjacency checks, target sorting, and simple development priority. It has no diplomacy, fronts, long-term planning, reinforcement logistics, empire goals, threat assessment beyond adjacent targets, or path planning.

## Persistence

Saved world-map state:

- `GameSaveStore.save(state:)` encodes `SavedGame`, which contains a day label and the full `GameState`.
- `GameState` saves day, elapsed day time, towns, world nodes, connections, active town ID, and news events.
- `Town` saves ID, name, resources, buildings, biome layout, faction, Duskara flag, army strength, and soldier roster.

Restored world-map state:

- `ContentView` loads `SavedGame.state` and constructs `GameViewModel(savedState:)`.
- The saved state is used directly, then building coordinates and active-town selection are sanitized.
- On load, phase becomes `.victory` if Duskara is player-controlled; otherwise it becomes `.town` and the clock starts.
- Legacy decoding support exists for old `isPlayerControlled` and `enemyArmyStrength` keys.

## Current Gameplay Loop

A player can currently perform this loop with implemented systems:

1. Start a game from the menu and enter setup.
2. Start the town phase with Hearthglen as the initial player-controlled active town.
3. Build and upgrade the active town's local economy.
4. Build barracks and train soldiers if resources, free people, and population cap allow it.
5. Advance days manually or let the clock advance days, producing resources and applying army upkeep.
6. Open the world map from the bottom bar.
7. Select a connected non-player town.
8. Attack if active-town army strength is greater than target effective defense.
9. On success, capture the town, flip its faction to player, lose the committed army from the source, and place survivors in the captured town.
10. Visit any owned town instantly from the world map.
11. Transfer gold, food, skill, or soldiers from the active town to another owned town.
12. Repeat attacks through adjacent captured towns toward Duskara.
13. Capture Duskara to enter victory.
14. During day advancement, enemy towns may develop, train, and attack adjacent non-enemy towns every 20 days.

## Missing Pieces

Major missing systems that prevent the full experience of "Found cities, grow an empire, expand territory, attack neighboring cities, conquer cities, and control a growing realm":

- City founding: no action or system creates new towns/nodes/connections during gameplay.
- Dynamic world expansion: the map is fixed at 25 towns.
- Territory areas: only town ownership exists; there is no land/region control layer.
- Borders: no border model, border rendering, or border gameplay.
- Influence/control projection: no influence, culture, loyalty, unrest, control radius, or assimilation system.
- Travel: owned-town switching, transfers, and attacks are instant; no travel time, roads, movement range, or route cost.
- Gameplay pathfinding: graph distance exists internally, but no player-facing pathfinding or multi-hop logistics.
- Independent armies: armies are stored on towns only; there are no army entities on the map.
- Strategic army logistics: no marching, staging, reinforcements in transit, supply lines, or multi-town attack coordination.
- Conquest aftermath beyond penalties: capture flips ownership immediately; no occupation duration, revolt, repair, loyalty, or governance layer.
- Empire size/control metrics: only aggregate army strength exists; no empire population, economy, area, administrative capacity, or realm status.

## Suggested Next Milestone

The single highest-leverage next feature is city founding on the world map: add a player action that creates a new player-controlled town node and connection from an existing owned town, with a clear resource cost. Conquest, ownership, saving, visiting, transfers, and rendering already operate on `GameState.towns`, `worldNodes`, and `connections`, so founding would connect the existing fixed-map conquest loop to the missing "found cities, grow an empire" part of the target experience.
