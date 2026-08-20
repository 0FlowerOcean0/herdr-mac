// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HerdrMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HerdrMac", targets: ["HerdrMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.15.0")
    ],
    targets: [
        .executableTarget(
            name: "HerdrMac",
            dependencies: [
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/HerdrMac",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "HerdrMacTests",
            dependencies: ["HerdrMac"],
            path: "Tests/HerdrMacTests"
        )
    ]
)
