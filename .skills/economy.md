# Economy

## Purpose

Document resources, production, construction costs, daily upkeep, trade, and difficulty balance.

## Responsibilities

`ResourceWallet` stores non-negative amounts. `GameBalance` defines grid, day duration, starting resources, combat/capture constants, building definitions, and soldier definitions. `ResourceSystem`, `BuildingSystem`, `ArmyUpkeepSystem`, `TransferSystem`, and reducer trade handling mutate economy state.

## Resources and flow

The active resource kinds are gold, food, people, soldiers, and skill. Buildings produce defined resources per day. A day advances through `SimulationSystem`, applies production, then pays soldier food upkeep. Construction, upgrades, training, transfers, and trade spend/apply wallet amounts.

## Rules

- Wallet writes clamp values to zero.
- Costs require `canAfford` before spending.
- House adds people and capacity; Pier produces gold; Farm produces gold/food; Factory produces skill; Barracks unlocks training.
- Difficulty presets change the starting gold/skill bonus: Easy 500/250, Medium 300/150, Hard 100/50.
- Soldiers consume daily food. If food is insufficient, units are removed by highest upkeep first and released people return to the town.
- Trade offers are deterministic per world seed/day/town, expire on the next day, and require a connected neutral partner.

## APIs and models

`ResourceWallet.canAfford`, `spend`, `apply`, `ResourceSystem`, `GameBalance.duskDefault`, `Difficulty.modeBalance`, `ArmyUpkeepSystem.applyDailyUpkeep`, `TransferSystem.transfer`, and reducer `.acceptTrade`/`.declineTrade`.

## Invariants and performance

Do not allow negative wallet values. Keep resource keys stable in Codable/DTO forms. Economy operations are small dictionary updates; daily simulation scans towns/buildings once.

## Extension points

Add a resource through the enum, display metadata, balance, rules, DTO conversion, fixtures, and tests. Add production/cost values in balance rather than hardcoding them in views.

## Known limitations / TODO / Requires Confirmation

- No explicit workforce consumption is applied to building production despite some summaries mentioning labor.
- The `Difficulty` type is not Codable, so difficulty selection is not persisted as a named campaign setting.
