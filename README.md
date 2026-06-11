# Dictionary Ordered Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The **order-contracting dictionary discipline** over the `Dictionary` namespace: the column-generic sibling of `Dictionary<S>` that contracts insertion order and exposes it — positions are insertion-order ranks, with positional access and a key → position door, alongside the full keyed surface.

---

## Quick Start

```swift
import Dictionary_Ordered_Primitives
import Dictionary_Primitive
import Hash_Indexed_Primitive
import Column_Primitives
import Shared_Primitive

// The CoW (value-semantic) column — Copyable, copies share until mutation.
typealias Registry = Dictionary<
    Shared<Hash.Entry<String, Int>, Hash.Indexed<Column.Heap<Hash.Entry<String, Int>>>>
>.Ordered

var registry = Registry()
registry.insert(key: "gamma", value: 3)
registry.insert(key: "alpha", value: 1)
registry.insert(key: "beta",  value: 2)

// Iteration follows insertion order — not hash order.
registry.forEach { name, priority in print("\(name): \(priority)") }
// gamma: 3
// alpha: 1
// beta: 2

// Positions are insertion-order ranks.
registry.index(forKey: "alpha")     // rank 1
registry.key(at: registry.index(forKey: "beta")!)   // "beta"
registry.entry(at: .zero)           // (key: "gamma", value: 3)

// Updating an existing key keeps its rank; the displaced value hands back.
let displaced = registry.insert(key: "alpha", value: 100)   // 1

// Removal preserves the order of the rest; re-insertion appends at the end.
registry.removeValue(forKey: "gamma")
registry.insert(key: "gamma", value: 30)    // now at the last rank

// Values mutate in place behind the hash-stable key — by key or by rank.
registry.withMutableValue(forKey: "beta") { $0 += 1 }
registry.withMutableValue(at: .zero) { $0 += 1 }
```

The default column is MOVE-ONLY (zero-cost, supports `~Copyable` values):

```swift
struct FileHandle: ~Copyable { /* … */ }

var handles = Dictionary<
    Hash.Indexed<Column.Heap<Hash.Entry<String, FileHandle>>>
>.Ordered()
handles.insert(key: "primary", value: FileHandle())
handles.withValue(forKey: "primary") { handle in /* borrow */ }
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

## Surface

| Doors | Operations |
|-------|------------|
| Keyed (mirrors `Dictionary<S>`) | `insert(key:value:)` (displaced-value hand-back), `contains(key:)`, `withValue(forKey:)`, `withMutableValue(forKey:)`, `removeValue(forKey:)` (order-preserving), `removeAll`, `forEach` (insertion order), `clone` |
| Ordered (this package's contract) | `Index` (the ordered index domain), `index(forKey:)`, `key(at:)`, `value(at:)`, `entry(at:)`, `withValue(at:)`, `withMutableValue(at:)` |

The order contract: position `0` is the oldest live entry; updating an existing key keeps its
rank; removing an entry shifts every later rank down by one; re-insertion after removal appends
at the end. Keys are immutable — values mutate in place behind a hash-stable key.

Copyability flows from the column (S5): the direct `Hash.Indexed` column is move-only; the
`Shared`-wrapped composite is `Copyable` with explicit copy-on-write value semantics.

---

## Architecture

`Dictionary<S>.Ordered` composes the same ordered hashed entry column as the base
`Dictionary<S>` ([swift-dictionary-primitives](https://github.com/swift-primitives/swift-dictionary-primitives)):
`Hash.Indexed<Dense>` with key-projected `Hash.Entry<Key, Value>` elements — entries live densely
in insertion order; the hash side is the bucket position-index engine. Positions ARE the dense
slots, so positional access is O(1) and `index(forKey:)` is the engine's O(1)-average
projected-key probe. The base `Dictionary<S>`'s contract is keyed; `Ordered` is where the
positional promise lives.

The package ships as **two modules**: a lean type module (`Dictionary Ordered Primitive`)
declaring the `@frozen` template, its column-pinned constructors, and the ordered index domain;
and the umbrella (`Dictionary Ordered Primitives`) carrying the pinned keyed + positional doors.

---

## Related Packages

- `swift-dictionary-primitives` — the base `Dictionary<S>` ADT and the `Hash.Entry` element vocabulary.
- `swift-hash-table-primitives` — `Hash.Indexed`, the ordered hashed column, and its bucket engine.
- `swift-column-primitives` — the `Column` spelling vocabulary (`Column.Heap` et al.).
- `swift-shared-primitives` — `Shared`, the explicit copy-on-write column wrapper.

---

## License

Apache License 2.0. See [LICENSE](LICENSE.md) for details.
