// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Whisk",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Whisk",
            path: "Whisk",
            exclude: [
                "Resources/Info.plist",
                "Resources/Whisk.entitlements",
            ],
            resources: [
                .process("Resources/option.svg")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
