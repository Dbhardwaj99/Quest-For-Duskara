# Inventory, Resources, and Transfers

## Purpose

Describe the state containers used as town inventory and the rules for moving them.

## Responsibilities

`ResourceWallet` owns resource amounts. `SoldierRoster` owns unit counts and derives army power/manpower. `TransferSystem` moves resources or soldier units between player-controlled towns. UI panels only choose resource/amount and dispatch an action.

## Data flow

`WorldMapView transfer panel → GameViewModel.transfer → GameAction.transferResources → GameReducer → TransferSystem → source/destination Town`.

## Rules and invariants

- Source and destination must be different and player-controlled.
- Non-soldier transfers require the source wallet to afford all positive amounts.
- Soldier transfers move whole units whose power fits the request; a legacy raw-strength remainder moves as a number.
- If no requested unit fits, one weakest available unit moves so a valid request makes progress.
- `armyStrength` and the `.soldiers` wallet entry are synchronized after soldier movement.
- Resource wallet values never become negative.

## Public models/APIs

`ResourceKind`, `ResourceWallet`, `SoldierRoster`, `TransferOrder`, and `TransferSystem.transfer`.

## Performance

Transfers scan towns by ID and unit kinds; the active model is small and does not require a separate inventory database.

## Extension points

Add carried item types only if gameplay requires more than resource/unit inventories. Keep wire representation explicit and versioned; route all movement through the reducer.

## Known limitations / TODO / Requires Confirmation

- There is no item inventory, storage capacity, cargo ship entity, or logistics model beyond resource/unit transfer.
- The soldier transfer request is a requested power amount, not an exact unit-count API; preserve this behavior unless a versioned command change is intended.
