// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lio",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Lio",
            path: "Lio",
            exclude: [
                "Shared/Resources/Info.plist",
                "Shared/Resources/Lio.entitlements",
            ],
            resources: [
                .process("Shared/Resources/Lio.svg")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
