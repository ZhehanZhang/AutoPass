// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AutoPass",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "AutoPass", targets: ["AutoPass"])],
    targets: [
        // Pure logic (policy, parsing, signature checks): unit-testable without Accessibility permission.
        .target(name: "AutoPassCore"),
        // The menu bar app: Accessibility, key injection, approval, SwiftUI settings.
        .executableTarget(name: "AutoPass", dependencies: ["AutoPassCore"]),
        .testTarget(
            name: "AutoPassCoreTests",
            dependencies: ["AutoPassCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
