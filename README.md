# Dictionary Ordered Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The **insertion-ordered dictionary discipline** over the `Dictionary` namespace: key-value storage that remembers the order pairs were inserted, in four capacity flavours — growable, bounded, inline, and small-buffer-optimized — all supporting noncopyable (`~Copyable`) values.

---

## Quick Start

```swift
import Dictionary_Ordered_Primitives

// Build a registry in the order entries are recorded.
var registry = Dictionary<String, Int>.Ordered()
registry["gamma"]   = 3
registry["alpha"]   = 1
registry["beta"]    = 2

// Iteration follows insertion order — not hash order.
for (name, priority) in registry {
    print("\(name): \(priority)")
}
// gamma: 3
// alpha: 1
// beta: 2

// Updating an existing key does NOT change its position.
registry["alpha"] = 100
print(Array(registry.keys))   // ["gamma", "alpha", "beta"]

// Removing a key and re-inserting moves it to the end.
registry.values.remove("gamma")
registry["gamma"] = 30
print(Array(registry.keys))   // ["alpha", "beta", "gamma"]

// Merge incoming pairs, keeping the first value for duplicate keys.
registry.merge.keep.first([("beta", 999), ("delta", 4)])
print(registry["beta"])        // Optional(2)  — original value kept
print(registry["delta"])       // Optional(4)  — new key appended
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-dictionary-ordered-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        // The umbrella — the whole package.
        .product(name: "Dictionary Ordered Primitives", package: "swift-dictionary-ordered-primitives"),
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3
and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux toolchain).

---

## Variants

| Type                              | Storage              | Reach for it when                                      |
|-----------------------------------|----------------------|--------------------------------------------------------|
| `Dictionary<K, V>.Ordered`        | heap, growable       | the number of entries isn't known up front             |
| `Dictionary<K, V>.Ordered.Bounded`| heap, fixed maximum  | there is a hard capacity ceiling; throws on overflow   |
| `Dictionary<K, V>.Ordered.Static<n>` | inline, compile-time capacity | the maximum is small and fixed at compile time |
| `Dictionary<K, V>.Ordered.Small<n>`  | inline → heap        | usually small, occasionally larger (SBO)           |

Every variant is generic over `Key: Hashable` and `Value`, including noncopyable value types.
`Dictionary.Ordered` and `.Bounded` are conditionally `Copyable` when `Value: Copyable`;
`.Static` and `.Small` are unconditionally `~Copyable`.

---

## Architecture

Each variant ships as **two modules**: a lean type module (`Dictionary Ordered Primitive`) containing
the value types and their core storage operations, and a conformances module (`Dictionary Ordered
Primitives`) containing `Sequence`, `Collection`, `merge`, `keys`, and `values` accessors — kept
separate so they never force a `Copyable` constraint on noncopyable use. Importing
`Dictionary Ordered Primitives` (the umbrella) brings in the complete package; importing
`Dictionary Ordered Primitive` brings in just the type surface.

---

## Related Packages

- `swift-set-ordered-primitives` — the insertion-ordered set discipline that backs key storage in every `Dictionary.Ordered` variant.
- `swift-buffer-linear-primitives` — the linear buffer discipline used for contiguous value storage.
- `swift-dictionary-primitives` — the `Dictionary` namespace and core protocol definitions.

---

## License

Apache License 2.0. See [LICENSE](LICENSE.md) for details.
