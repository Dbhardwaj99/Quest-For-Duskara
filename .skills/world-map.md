# World Map

## Purpose

Represent the generated archipelago, town relationships, terrain, landmarks, territory, and map interactions.

## Responsibilities

`WorldMapSystem` creates towns/world and resolves attacks. `WorldGenerator`, `TerrainGenerator`, `WorldNoise`, `TerritoryGenerator`, `TerritorySystem`, and `TerritoryOwnership` generate and reconcile map data. `WorldMapView` and `TerritoryRenderer` display and select towns; `GameViewModel` routes attack, switch, and transfer commands.

## Data flow

`WorldMapSystem.makeInitialState(balance:seed:) → GameState(world/worldNodes/connections/territory) → WorldMapView/TerritoryRenderer`. Town faction changes call territory ownership reconciliation. Map connections support trade, enemy adjacency, and visual sea lanes.

## Implemented rules

- The generated campaign contains named towns, one town node per town, open water/land terrain, landmarks, connections, and one territory region per town.
- The first town is player-controlled; named enemy towns and Duskara have non-player factions.
- Any non-player town can be attacked by the player if the source is player-controlled and its strength exceeds effective defense; player attacks are not restricted to graph adjacency.
- Enemy AI targets adjacent towns only.
- Conquest changes faction, applies capture resource loss, creates a survivor garrison, and reconciles territory ownership.
- Neutral connected towns can provide one seeded daily trade offer to a player town with a Pier.

## Models and APIs

`MapLayout`, `MapCell`, `MapPoint`, `TerrainTile`, `WorldMapState`, `WorldTownNode`, `TownConnection`, `TerritoryState`, `TerritoryRegion`, `WorldLandmark`, `WorldMapSystem.canAttack`, `attack`, and `effectiveDefenseStrength`.

## Constraints and performance

Generation must be deterministic for a seed/algorithm version. Territory ownership is derived from current town factions; territory cells are generated data. Map rendering should project existing state and avoid introducing rule decisions.

## Extension points

Add map-generation variants with an algorithm version; add landmarks as data plus rendering; add map actions through the reducer; add presentation layers without changing generators.

## Known limitations / TODO / Requires Confirmation

- The current map layout includes a legacy layout for compatibility; the migration policy is not documented.
- World map combat visualization and richer landmark gameplay are roadmap items only.
