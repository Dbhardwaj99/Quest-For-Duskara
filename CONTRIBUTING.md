# Contributing to Quest for Duskara

Thanks for your interest! Help of any size is welcome: a bug report from your last campaign, a balance tweak, a new building model, a test, or a feature.

## Ways to help

- **Report a bug.** [Open a bug report](https://github.com/Dbhardwaj99/Quest-For-Duskara/issues/new?template=bug_report.yml) with the steps that lead to it.
- **Suggest an idea.** New mechanics, balance changes, map or interface improvements: [share an idea](https://github.com/Dbhardwaj99/Quest-For-Duskara/issues/new?template=feature_request.yml).
- **Pick up an issue.** [`good first issue`](https://github.com/Dbhardwaj99/Quest-For-Duskara/labels/good%20first%20issue) marks small, self-contained tasks; [`help wanted`](https://github.com/Dbhardwaj99/Quest-For-Duskara/labels/help%20wanted) marks bigger ones. Leave a comment before you start so nobody duplicates your work.
- **Improve the look.** Buildings are USDZ models and the world is rendered with RealityKit and Metal, so 3D art and shader work are especially welcome.

## Build and run

You need a Mac running **macOS 26 or later** with **Xcode 26.6 or later**.

1. Fork the repository and clone your fork.
2. Open `Quest For Duskara.xcodeproj`, select the **Quest For Duskara** scheme and **My Mac**, and press **Run** (`⌘R`).
3. The project is signed with my team, so Xcode will ask for yours. Under **Signing & Capabilities**, choose your own team (a free Personal Team works) or **Sign to Run Locally**. Please don't commit that change.

**Run** builds the Release configuration, the same build players get. Debug-only tools, such as skipping days and the building-size panel, need the Debug configuration: choose **Product → Scheme → Edit Scheme…**, select **Run**, and set **Build Configuration** to **Debug**. Don't commit that change either.

Run the tests with `⌘U`, or from Terminal:

```bash
xcodebuild test -scheme "Quest For Duskara" -destination 'platform=macOS' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=
```

## Where things live

| Folder | Contents |
| --- | --- |
| `Models/` | Game state and rules: economy, combat, world generation, and saves. Most gameplay changes start here. |
| `ViewModels/` | Connects player actions to the interface. |
| `Views/` | SwiftUI screens. `Views/3D/` renders the town, ocean, and world with RealityKit and Metal. |
| `Managers/` | Visual theme selection. |
| `Assets/` | USDZ building models, brand art, and the asset catalog. |
| `Tools/` | `generate_settlement_models.py` rebuilds the settlement USDZ pieces in Blender; usage is at the top of the file. |
| `Tests/` | Gameplay tests written with Swift Testing. |

Xcode picks up new files in these folders automatically. The test target compiles `Models/` and `ViewModels/` directly, so code there can't depend on anything in `Views/`.

## Sending a pull request

- Keep it focused: one fix or feature per pull request. For larger changes, such as a new mechanic or a refactor, open an issue first so we can agree on the approach.
- Branch from `main` and match the style of the surrounding code.
- If you change a game rule, add or update a test in `Tests/GameplayTests.swift`.
- Attach before-and-after screenshots for visual changes.
- Check that the game builds and the tests pass.

## Community

Everyone taking part follows the [Code of Conduct](CODE_OF_CONDUCT.md). Please report security problems privately, as described in the [security policy](SECURITY.md).

By contributing, you agree that your contributions are licensed under the project's [MIT License](LICENSE).
