// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LocalPhotoModels",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "LocalPhotoModels", targets: ["LocalPhotoModels"]),
        .executable(name: "local-model-smoke", targets: ["LocalModelSmoke"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", exact: "3.32.3", traits: []),
        .package(url: "https://github.com/ml-explore/mlx-swift", exact: "0.32.3"),
        .package(url: "https://github.com/huggingface/swift-transformers", exact: "1.3.0")
    ],
    targets: [
        .target(name: "PhotoModelContracts", resources: [.process("PrivacyInfo.xcprivacy")]),
        .target(name: "LocalPhotoModels", dependencies: [
            "PhotoModelContracts",
            .product(name: "MLX", package: "mlx-swift"),
            .product(name: "MLXVLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "Tokenizers", package: "swift-transformers")
        ]),
        .executableTarget(name: "LocalModelSmoke", dependencies: ["LocalPhotoModels"]),
        .testTarget(name: "PhotoModelContractsTests", dependencies: ["PhotoModelContracts"])
    ]
)
