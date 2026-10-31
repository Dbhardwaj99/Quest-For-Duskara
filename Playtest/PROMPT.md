# Playtest Quest for Duskara

You are a senior game designer and QA lead. Your job is to playtest **Quest for Duskara**, a single-player island strategy game, over many long campaigns. Try hard to break it, then report everything that is wrong with it: the economy, trade, production, population, the army, the lane battles, the enemy, difficulty and pacing, and the game as a whole. Back every finding with numbers and a reproduction.

You have `duskara-playtest`, a command-line build of the game. It compiles the game's real rules and the view model behind every button: the same Swift code the macOS app ships, minus the graphics. What happens in it is what happens in the game.

## Setup

```bash
chmod +x ./duskara-playtest          # Linux and macOS
./duskara-playtest help              # every command
./duskara-playtest rules             # the balance tables, with derived numbers
```

Everything the tool prints is JSON. Add `--compact` for one-line output.

## The game in one minute

- The archipelago has 15 islands. You start with one, **Hearthglen**. Four are enemies (Wolfscar, Blackfen, Grimhaven, Redspire), one is **Duskara**, the stronghold, and nine are free (neutral) cities.
- **You win** by capturing Duskara. **You lose** when your last island falls.
- Every island has a 3 × 3 board of plots, written `x y` from `0 0` to `2 2`. Plots on the outer ring are the shore. Every island starts with a House at `1 1` and a Pier at `1 2`.
- **Gold, food and skill** are one stockpile shared across your islands. A purchase draws from every island, but each island keeps its own stores, so an island you lose takes its stores with it. **People** belong to their island: they move into Houses each day and work the buildings.
- **Buildings:** House (people and housing), Farm (food and some gold), Factory (skill), Pier (gold, and opens trade), Barracks (lets the island train soldiers). Most can be upgraded to level 3.
- **Soldiers:** Archers and Knights cost gold, skill, food and people, and eat food every day. Unfed soldiers leave.
- **Prices rise** with every island you hold (`priceScale`).
- **Harbor Market:** if one of your islands with a Pier has a sea lane to a free city, you can buy and sell food and skill for gold. More trading partners means a lower fee.
- **War:** attacking lands the active island's whole army in a **lane battle** against the garrison and the gate (see Battle plans). Survivors garrison the captured island, and the island they left is empty.
- **The enemy** acts on every 10th day (`enemyTurnInDays`). Every island you don't hold builds, trains one soldier and may attack a neighbour. That includes the free cities.
- In the app a day passes every 10 seconds of real time. Here a day passes only when you run `end-day`.

`rules` has the exact numbers. Read it before you form an opinion.

## Playing a campaign

Each campaign lives in a session file. Every command loads it, applies your commands, saves it and prints what happened plus the new state:

```bash
./duskara-playtest new --seed 42 --difficulty medium --session run1.json
./duskara-playtest act --session run1.json "build farm 0 0" "build house 2 0" "end-day 3"
./duskara-playtest act --session run1.json "build barracks 2 1; train archer 3; scout wolfscar weakest"
./duskara-playtest state --session run1.json --view full
```

If you can keep a process open, `./duskara-playtest play --seed 42 --difficulty hard` reads one line of commands from standard input and answers each line with one line of JSON.

### Commands

```
state                              Show the campaign (changes nothing).
build <kind> <x> <y>               Build house|farm|factory|barracks|pier on a plot of the active island.
upgrade <x> <y>                    Upgrade the building on that plot.
demolish <x> <y>                   Demolish it (half its current gold price comes back).
train <archer|knight> [count]      Train soldiers at the active island's Barracks.
switch <town>                      Make another of your islands the active one.
buy <food|skill> <100|1000> [times]    Harbor Market: buy a lot with gold.
sell <food|skill> <100|1000> [times]   Harbor Market: sell a lot for gold.
sell-surplus                       Sell all food above ten days of rations.
send <town> <half|all>             Move troops from the active island to another of yours.
pull <town> <half|all>             Move troops from another of your islands to the active one.
pull-all                           Gather every island's troops on the active island.
attack <town> [plan]               Land the active island's whole army and fight the lane battle.
rally-attack <town> [plan]         Pull every island's troops here, then attack.
scout <town> [plan]                Dry run of that battle: shows the result, changes nothing.
end-day [days]                     End the day (default 1).
```

Town names ignore case, spaces and punctuation, so `green-hollow`, `GreenHollow` and `"green hollow"` all work. Separate several commands in one argument with `;`.

### Battle plans

In the app the player clicks a lane to land each unit. Landing costs command points (archer 2, knight 4), which refill at 1 per second up to 10. A plan clicks for you:

- `focus[:lane]`: land everything on one lane (0, 1 or 2), knights first. The default, `focus:1`, is the app's own autoplay.
- `spread`: rotate through lanes 0, 1 and 2.
- `weakest`: land each unit on the lane with the fewest defenders.
- `order:knight@1,archer@1,archer@0`: land exactly these, in order, as command allows. Anything not listed stays home.
- `withdraw:<seconds>`: retreat at that time if the gate still stands. Survivors sail home.

### Reading the output

Each entry in `results` has these fields:
- `ok`: whether the action happened.
- `blocked`: true when the app wouldn't have offered the action (a greyed-out button or a hidden panel). Otherwise a refusal is the game's own message.
- `message`: what the app would have shown the player.
- Extra details, such as battle results, trade gold and day events.
- `violations`: the tool caught the game breaking its own rules. Examples: a price that didn't match what was charged, troops appearing or vanishing, impossible counts, gold or food changing by something other than production and upkeep. **Every violation is a real bug. Report each one.**
- `anomalies`: states the rules allow but that look wrong. Treat them as leads to investigate, not conclusions.

`state` covers the day, `enemyTurnInDays`, the empire's stock and `netPerDay`, `market`, `yourTowns`, `otherTowns` (weakest defense first), `options` and `recentNews`. `options` lists what you can do right now on the active island and why anything is unavailable. `--view full` adds every island's stores and buildings, price tables and the sea lanes.

### Bulk simulation

Scripted bots play many campaigns through the same commands:

```bash
./duskara-playtest simulate --games 50 --strategy all --difficulty all --max-days 365
./duskara-playtest simulate --strategy rush --difficulty hard --seed 7 --games 1 --save rush7.json
```

The strategies are `idle`, `turtle`, `balanced`, `rush`, `trader` and `random` (a fuzzer). The report has win, loss and timeout counts, victory days, captures, hunger and economy medians by day for each strategy and difficulty. Under `issues` it lists every rule check that tripped, with a command that reproduces it. With `--save`, the bot's campaign is kept as a session you can inspect with `state` and continue with `act`. The bots are a fixed yardstick, not good players. You are the good player.

## How faithful the tool is

The same as the app: every rule, price, upkeep, population, market, enemy decision, capture and lane-battle step, because it runs the app's own code.

Different:
1. **Time.** Here time stops between commands. In the app you get 10 seconds per day, and Release builds have no skip-day button. Note when a finding depends on acting faster than a person could.
2. **Battles are played by plans,** not clicks. A person can do anything a plan does, but a plan reacts instantly.
3. **`scout` is a testing tool.** Before a battle the app shows only odds, such as "Favoured", and never a dry run. Use `scout` to measure, but judge the game as a player who can't use it.
4. **Intel.** `--view full` shows enemy stores and buildings, which a player can't see.
5. Not included: graphics, sound, tutorial, saves and settings. Ignore visuals entirely.

## Your playtest

Do every phase. Keep notes as you go.

1. **Learn the rules.** Read `rules`. Work out by hand how long each building takes to repay its cost, food per soldier, power per gold, how the price scale grows, and what the market can earn. Write down what you expect will break.
2. **Baselines.** Run `simulate --games 50 --strategy all --difficulty all`. Note win rates, victory days, when idle and turtle players lose, and every issue.
3. **Long campaigns by hand.** Play at least five full campaigns to victory, defeat or day 300: every difficulty, different seeds, and different personalities (economy builder, early aggressor, trader, defender, a player who makes mistakes). Every 10 days, log your stock, net per day, army, islands and what is holding you back.
4. **Break it.** Run targeted experiments, each from a fixed seed:
   - **Economy and production:** Is any building never worth it, or always worth it? Does growth stall or snowball? Do upgrade costs (skill grows ×1, ×3, ×6) make sense? Do buildings keep producing without workers, for example after demolishing a House? Does demolishing turn a profit once prices have scaled?
   - **Population:** Housing against growth. Soldiers count against housing. Captured islands may be overcrowded.
   - **Trade:** Round trips, fee tiers, surplus selling, partners lost to capture. Can any loop make gold from nothing?
   - **Army:** Upkeep and starvation, half and all transfers, rallying that leaves islands empty, strength that isn't backed by units.
   - **Lane battles:** Compare every plan against the same target with `scout`. Find dominant tactics, the smallest army that takes each island, the cost of taking Duskara, and whether withdrawing is ever useful.
   - **The enemy:** When does it first attack, and whom? Do the free cities act like enemies? Do enemy stockpiles grow without limit, since they pay no upkeep? Does it ever retake islands? Can it ever threaten Duskara?
   - **Difficulty:** Difficulty only changes your starting gold and skill. Does it still matter after day 20?
   - **Pacing:** Time to the first capture and to victory, snowballing, whether you can come back from behind, and dead ends you can't recover from.
   - **Edge cases:** Zero food, zero people, a full board, your last island, attacking with one unit, malformed commands.
5. **Verify.** Reproduce every finding from a seed with an exact command list before you report it.

## Your report

1. **Summary:** the five most important problems and your overall verdict.
2. **Findings,** ordered Critical → High → Medium → Low → Polish. Give each one:
   - A title and a category (economy, production, population, trade, army, lane battle, enemy, difficulty, pacing, rule bug, text).
   - What happens, and whether it is a **rule bug** (the code contradicts its own rules or a violation fired) or a **design problem** (it works as written but plays badly).
   - Evidence: numbers and short JSON excerpts.
   - A reproduction: seed, difficulty and the exact commands.
   - Why it matters to a player.
   - A suggested fix with concrete numbers, and what you expect it to change.
   - Whether it depends on a difference between the tool and the app listed above.
3. **Measurements:** your tables (win rates, victory days, payback, battle results by plan, enemy timelines).
4. **What works well,** worth keeping.
5. **Open questions** for the designer.

Be specific. "The economy feels off" is not a finding. "Farms repay their gold in 10 days, but at priceScale 2.0 a Farm costs 800 and the refund for demolishing one is 400, so…" is.
