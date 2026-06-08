// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-dictionary-ordered-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Dictionary Ordered Primitives",
            targets: ["Dictionary Ordered Primitives"]
        ),
        .library(
            name: "Dictionary Ordered Primitive",
            targets: ["Dictionary Ordered Primitive"]
        ),
        .library(
            name: "Dictionary Ordered Primitives Test Support",
            targets: ["Dictionary Ordered Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-memory-small-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-dictionary-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-set-ordered-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-set-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-hash-table-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-index-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-finite-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-linear-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-sequence-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-iterator-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-property-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        // E2 (storage-small-substrate.md): verbose Storage.Contiguous<Memory.Heap> needs direct deps (MemberImportVisibility).
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
    ],
    targets: [

        // MARK: - Type (ordered-dictionary type surface: Ordered + Bounded/Small)
        .target(
            name: "Dictionary Ordered Primitive",
            dependencies: [
                .product(name: "Dictionary Primitives Core", package: "swift-dictionary-primitives"),
                .product(name: "Set Ordered Primitive", package: "swift-set-ordered-primitives"),
                .product(name: "Hash Table Static Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Bounded Primitive", package: "swift-buffer-linear-primitives"),
                // Cleave-3 #12a/#5a: Dictionary.Ordered.Small backs _values with Buffer<Storage<Value>.Small<n>>.Linear.
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
            ]
        ),

        // MARK: - Ordered (operations / conformances over the ordered-dictionary types; doubles as umbrella)
        .target(
            name: "Dictionary Ordered Primitives",
            dependencies: [
                "Dictionary Ordered Primitive",
                .product(name: "Dictionary Primitives Core", package: "swift-dictionary-primitives"),
                .product(name: "Set Ordered Primitive", package: "swift-set-ordered-primitives"),
                .product(name: "Set Primitives", package: "swift-set-primitives"),
                .product(name: "Hash Table Static Primitive", package: "swift-hash-table-primitives"),
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Finite Bounded Primitives", package: "swift-finite-primitives"),
                .product(name: "Sequence Primitives", package: "swift-sequence-primitives"),
                .product(name: "Buffer Linear Primitive", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Primitives", package: "swift-buffer-linear-primitives"),
                .product(name: "Buffer Linear Bounded Primitive", package: "swift-buffer-linear-primitives"),
                // Cleave-3 #12a/#5a: Dictionary.Ordered.Small backs _values with Buffer<Storage<Value>.Small<n>>.Linear.
                .product(name: "Memory Small Primitives", package: "swift-memory-small-primitives"),
                .product(name: "Storage Primitive", package: "swift-storage-primitives"),
                .product(name: "Iterator Primitive", package: "swift-iterator-primitives"),
                .product(name: "Iterable", package: "swift-iterator-primitives"),
                .product(name: "Iterator Chunk Primitives", package: "swift-iterator-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Storage Contiguous Primitives", package: "swift-storage-primitives"),
                .product(name: "Memory Heap Primitives", package: "swift-memory-heap-primitives"),
            ]
        ),

        // MARK: - Test Support
        .target(
            name: "Dictionary Ordered Primitives Test Support",
            dependencies: [
                "Dictionary Ordered Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
                .product(name: "Tagged Primitives Test Support", package: "swift-tagged-primitives"),
                .product(name: "Buffer Primitives Test Support", package: "swift-buffer-primitives"),
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests
        .testTarget(
            name: "Dictionary Ordered Primitives Tests",
            dependencies: [
                "Dictionary Ordered Primitives",
                "Dictionary Ordered Primitives Test Support",
                .product(name: "Iterable", package: "swift-iterator-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = [
        .enableExperimentalFeature("RawLayout"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
