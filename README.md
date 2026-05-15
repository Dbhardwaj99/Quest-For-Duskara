# ⚔️ Quest for Duskara

> *A medieval strategy game built for iOS, where empires are forged one tile at a time.*

Quest for Duskara is an open-source, portrait-mode iOS strategy game built entirely in SwiftUI. Inspired by the depth of classic Flash-era city builders and conquest games, it is being built from scratch with one goal: to create a real, living strategy world in your pocket.

This is not a prototype. It's a foundation, designed to grow into something genuinely ambitious.

---

## 🌍 Vision

Most mobile strategy games sacrifice depth for retention loops. Quest for Duskara aims to do the opposite: bring back the joy of *actual strategy*, where resource decisions matter, terrain shapes your options, towns have distinct identities, and wars have real consequences.

The architecture is built to support this. Every system (buildings, soldiers, biomes, world maps) is modular and configurable. When the game grows, it grows cleanly.

---

## ✨ What Exists Today

The core loop is playable. Here's what you can do right now:

- **Allocate a starting pool:** Distribute bonus resources (Gold, Wood, Coal, Tech) before founding your capital. Your choices shape your early game.
- **Build your town:** Place and upgrade modular structures on a grid. Buildings have costs, production rates, population effects, and terrain requirements.
- **Manage biomes:** Wood Mills only go near forests. Coal Mines belong near mountain tiles. Terrain isn't decoration; it constrains your plans.
- **Run the daily simulation:** Each new day, buildings generate resources, armies consume upkeep, and the world advances.
- **Train soldiers:** Build a Barracks to recruit Archers and Knights with distinct combat profiles.
- **Conquer the world map:** Expand outward through adjacent towns. Weaker towns fall. Stronger ones push back.
- **Transfer resources:** Move surplus production between your towns to specialize regions.

---

## 🗺️ Roadmap

These are the real things being worked on and planned, in no particular order. The end goal is multiplayer, but there's a lot of ground to cover first.

| # | Feature | Status | Notes |
|---|---|---|---|
| 1 | **UI/UX Redesign** | 🔴 In Progress | The current visuals are placeholder-grade. Every screen needs a design pass: typography, color, layout hierarchy, and component consistency. |
| 2 | **Game State Persistence** | 🔴 In Progress | The game doesn't save yet. Implementing persistent storage (SwiftData or Codable + file storage) so campaigns survive app restarts. |
| 3 | **Remove Hardcoded Data** | 🔴 In Progress | Cities, map layouts, and several game values are currently hardcoded. These need to move into configurable data so the world is dynamic and extensible. |
| 4 | **Portrait Layout Polish** | 🟡 Planned | Several views have layout issues in portrait mode. UI needs to be properly constrained and tested across iPhone sizes. |
| 5 | **More Building Types** | 🟡 Planned | Adding Armory, Temple, and Park buildings, each with distinct mechanics and town effects. |
| 6 | **2D/3D Assets & Animations** | 🟡 Planned | Replace SwiftUI placeholder visuals with real illustrated assets and tile animations. The game should look and feel like a world. |
| 7 | **Multiplayer Mode** | 🔵 Long-term | The endgame goal. Async or real-time multiplayer via Game Center, where players build, trade, and fight against each other. |

---

## 🏗️ Project Architecture

The codebase is deliberately layered. If you want to contribute, here's where things live:

```
Quest For Duskara/
├── Models/         # Core data types: resources, biomes, placement, soldiers
├── Buildings/      # Building definitions and upgrade configs
├── Systems/        # All game logic: simulation, placement, resources, world, transfers
├── ViewModels/     # GameViewModel, the single coordinator between logic and UI
├── Views/          # Screen-level SwiftUI views (thin, presentation-only)
├── Components/     # Reusable UI primitives and drawing helpers
├── World/          # World map state and town graph models
├── Resources/      # Resource display helpers
├── Managers/       # Message coordination and presentation managers
└── UI/             # Shared theme, colors, typography constants
```

**The golden rule:** Game rules live in `Systems/` and `GameConfig.swift`. SwiftUI views should only handle presentation and forward user intent to the ViewModel.

---

## 🚀 Getting Started

### Requirements

- Xcode with SwiftUI support
- iOS deployment target as configured in the project
- No external packages, no asset dependencies, just open and build

### Running the Game

```bash
git clone https://github.com/your-username/quest-for-duskara.git
```

Open `Quest For Duskara.xcodeproj` in Xcode, select a simulator or device, and hit Run. That's it.

---

## 🤝 Contributing

First time contributing to an open-source iOS game? **This is a great place to start.** The architecture is explicitly designed so that adding a feature doesn't require touching everything.

### The Contribution Workflow

1. **Pick an issue from the roadmap.** Each item maps to a clear area of the codebase.
2. **Open an issue or comment first.** Avoids duplicate work and lets us align on approach before you write code.
3. **Add data before logic.** New features begin as models and `GameConfig.swift` entries, not view code.
4. **Put rules in systems.** Logic goes in `Systems/`, not in views.
5. **Wire it up in the ViewModel.** `GameViewModel` is the single bridge between game logic and the UI.
6. **Keep views thin.** SwiftUI files receive state and fire intents. Nothing else.

### Good First Issues

These are well-scoped entry points tied directly to the active roadmap:

- 🟢 **Add a new building type** (Armory, Temple, or Park): define it in `Buildings/`, wire up its effects, add costs to `GameConfig.swift`
- 🟢 **Fix a portrait layout issue** on any screen that clips or overflows on standard iPhone sizes
- 🟡 **Move a hardcoded city or map value into `GameConfig.swift`** and replace its references throughout the codebase
- 🟡 **Design the persistence model**: propose a `Codable` save/load structure for `GameViewModel` state and open a discussion
- 🔴 **Audit all hardcoded data** and open issues for each instance so they can be tackled incrementally

### Code Style

- Swift idioms throughout, value types preferred, classes where shared state is needed
- No forced unwraps in game logic
- Every new configurable value goes in `GameConfig.swift`, never hardcoded in a view
- Leave the architecture cleaner than you found it

---

## 📋 Design Principles

A few things that guide decisions in this project:

**Depth over retention.** The game should reward thinking, not just clicking. 

**Terrain should matter.** Every biome, river, and mountain range should create genuine strategic tradeoffs, not just cosmetic variation.

**The map should feel alive.** AI towns should behave plausibly.  Events should surprise you.

**Modularity is non-negotiable.** Any system (combat, diplomacy, research) should be addable without rewriting existing systems.

---

## 📄 License

[MIT](LICENSE): free to use, modify, and distribute. Attribution appreciated.

---

## 💬 Discussion

Have ideas? Found a bug? Want to propose a system design before writing code? Open an issue or start a discussion. This project benefits from design conversations as much as pull requests.

*Quest for Duskara is in active development. The world is small now. It won't stay that way.*
