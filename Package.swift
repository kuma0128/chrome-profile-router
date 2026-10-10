// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChromeProfileRouter",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ChromeProfileRouter", targets: ["ChromeProfileRouter"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "RouterCore"),
        .executableTarget(name: "ChromeProfileRouter", dependencies: [
            "RouterCore", .product(name: "Sparkle", package: "Sparkle"),
        ], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "RouterCoreTests", dependencies: ["RouterCore"]),
        .testTarget(name: "ChromeProfileRouterTests", dependencies: ["ChromeProfileRouter"]),
    ]
)
