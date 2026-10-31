// swift-tools-version: 6.2
import PackageDescription

// The headless playtester: the game's own rules and view model, built without
// SwiftUI, RealityKit or AppKit so a campaign can be played from a terminal on
// Linux, Windows or macOS. The app itself still builds from the Xcode project.
// See Playtest/README.md.

// Match the app target, so the shared sources compile exactly as they do there.
let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v5),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "DuskaraPlaytest",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "duskara-playtest", targets: ["duskara-playtest"]),
    ],
    targets: [
        // The rules and view model come straight from the app's folders; only
        // the SwiftUI colours and the AppKit sounds stay behind (the engine has
        // a silent GameSound in their place).
        .target(
            name: "DuskaraPlaytest",
            path: ".",
            // The target sits at the repository root to reach those folders,
            // so everything else at the root is excluded by name.
            exclude: [
                "Models/DisplayNames.swift",
                "ViewModels/GameSound.swift",
                "Playtest/CLI",
                "Playtest/Tests",
                "Playtest/README.md",
                "Playtest/PROMPT.md",
                "Assets",
                "Managers",
                "Screenshots",
                "Tests",
                "Tools",
                "Views",
                "brand-assets",
                "Quest For Duskara.xcodeproj",
                "CODE_OF_CONDUCT.md",
                "CONTRIBUTING.md",
                "LICENSE",
                "README.md",
                "SECURITY.md",
                "default.profraw",
                "index.html",
            ],
            sources: [
                "Models",
                "ViewModels/GameViewModel.swift",
                "ViewModels/GameViewModel+Trade.swift",
                "Playtest/Engine",
            ],
            swiftSettings: settings
        ),
        .executableTarget(
            name: "duskara-playtest",
            dependencies: ["DuskaraPlaytest"],
            path: "Playtest/CLI",
            swiftSettings: settings
        ),
        .testTarget(
            name: "DuskaraPlaytestTests",
            dependencies: ["DuskaraPlaytest"],
            path: "Playtest/Tests",
            swiftSettings: settings
        ),
    ]
)
