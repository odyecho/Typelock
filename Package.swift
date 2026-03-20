// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Typelock",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "Typelock",
            targets: ["Typelock"]
        )
    ],
    targets: [
        .target(
            name: "Typelock",
            path: "src",
            exclude: [
                "App",
                "UI",
                "Resources",
                "Core/InputSourceManager.swift",
                "Core/LockEngine.swift",
                "Core/PermissionManager.swift",
                "Utils/AnimationManager.swift",
                "Utils/HotKeyManager.swift",
                "Utils/NotificationManager.swift",
                "Utils/PerformanceMonitor.swift",
                "Utils/ThemeManager.swift"
            ],
            sources: [
                "Core/AppStateManager.swift",
                "Core/EnhancedInputSourceManager.swift",
                "Core/EnhancedLockEngine.swift",
                "Models",
                "Utils/Constants.swift",
                "Utils/Extensions.swift",
                "Utils/Logger.swift"
            ]
        ),
        .testTarget(
            name: "TypelockTests",
            dependencies: ["Typelock"],
            path: "tests/UnitTests"
        )
    ]
)
