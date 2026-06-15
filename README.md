# Dictionary Ordered Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)
[![CI](https://github.com/swift-primitives/swift-dictionary-ordered-primitives/actions/workflows/ci.yml/badge.svg)](https://github.com/swift-primitives/swift-dictionary-ordered-primitives/actions/workflows/ci.yml)

`Dictionary<S>.Ordered` — the order-preserving dictionary discipline over an ordered-hashed storage **column**. The column-generic sibling of `Dictionary<S>`: it preserves insertion order and exposes it as **positions** (insertion-order ranks), so entries are addressable by key *and* by position, alongside the full keyed surface. Copyability flows from the column — move-only by default, copy-on-write via a `Shared` column.

---

## Key Features

- **Insertion order preserved** — `forEach` and positional reads follow insertion order; updating a key keeps its rank, removing an entry shifts later ranks down by one, and re-insertion appends at the end.
- **Keyed and positional** — the full keyed surface (`insert` / `withValue` / `withMutableValue` / `removeValue` by key) plus positional access (`index(forKey:)`, and `key` / `value` / `entry` at a position).
- **In-place value mutation** — `withMutableValue` by key or by position; keys are immutable and never trigger a rehash.
- **Copyability from the column** — move-only by default (zero-cost, supports `~Copyable` values), opt-in copy-on-write via a `Shared` column.

---

## Quick Start

```swift
import Dictionary_Ordered_Primitives
import Dictionary_Primitive
import Hash_Primitives
import Hash_Indexed_Primitive
import Column_Primitives
import Hash_Primitives_Standard_Library_Integration

// Move-only by default, over the ordered-hashed entry column:
var priorities = Dictionary<Hash.Indexed<Column.Heap<Hash.Entry<String, Int>>>>.Ordered()
priorities.insert(key: "gamma", value: 3)
priorities.insert(key: "alpha", value: 1)
priorities.insert(key: "beta",  value: 2)

priorities.forEach { name, rank in print(name, rank) }   // gamma, alpha, beta — insertion order

// Positions are insertion-order ranks: key → position, then read by position.
let i = priorities.index(forKey: "beta")!
_ = priorities.key(at: i)                                // "beta"

// Values mutate in place behind the hash-stable key — by key or by position:
priorities.withMutableValue(forKey: "beta") { $0 += 1 }
priorities.withMutableValue(at: .zero) { $0 += 1 }       // .zero = the oldest entry
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
        .product(name: "Dictionary Ordered Primitives", package: "swift-dictionary-ordered-primitives")
    ]
)
```

The package is pre-1.0 — depend on `branch: "main"` until `0.1.0` is tagged. Requires Swift 6.3 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the corresponding Linux / Windows toolchain).

---

## Architecture

| Product | Contents | When to import |
|---------|----------|----------------|
| `Dictionary Ordered Primitives` | Umbrella — `Dictionary.Ordered` with its keyed + positional doors and conformances | Most consumers |
| `Dictionary Ordered Primitive` | The `Dictionary.Ordered` value type and the ordered index domain, without the conformances | Move-only / minimal-surface use |

`Dictionary<S>.Ordered` composes the same ordered-hashed entry column as the base `Dictionary<S>` — `Hash.Indexed<Dense>` with key-projected `Hash.Entry<Key, Value>` elements, entries dense in insertion order. Positions *are* the dense slots, so positional access is O(1) and `index(forKey:)` is the engine's O(1)-average projected-key probe. The base `Dictionary<S>` contract is keyed; `Ordered` is where the positional promise lives.

---

## Surface

| Doors | Operations |
|-------|------------|
| Keyed (mirrors `Dictionary<S>`) | `insert(key:value:)` (displaced value handed back), `contains(key:)`, `withValue(forKey:)`, `withMutableValue(forKey:)`, `removeValue(forKey:)` (order-preserving), `removeAll`, `forEach` (insertion order), `clone` |
| Ordered (this package's contract) | `index(forKey:)`, `key(at:)`, `value(at:)`, `entry(at:)`, `withValue(at:)`, `withMutableValue(at:)` |

Position `0` is the oldest live entry; updating an existing key keeps its rank; removing an entry shifts every later rank down by one; re-insertion after removal appends at the end. Keys are immutable — a value mutates in place behind its hash-stable key.

---

## Platform Support

| Platform         | CI  | Status       |
|------------------|-----|--------------|
| macOS 26         | Yes | Full support |
| Linux            | Yes | Full support |
| Windows          | Yes | Full support |
| iOS/tvOS/watchOS | —   | Supported    |
| Swift Embedded   | —   | Pending (nightly-toolchain follow-up) |

---

## Related Packages

- [`swift-dictionary-primitives`](https://github.com/swift-primitives/swift-dictionary-primitives) — the base `Dictionary<S>` ADT and the `Hash.Entry` element vocabulary.
- [`swift-hash-table-primitives`](https://github.com/swift-primitives/swift-hash-table-primitives) — the `Hash.Indexed` position-index engine the entry column is built on.
- [`swift-column-primitives`](https://github.com/swift-primitives/swift-column-primitives) — the column vocabulary (`Hash.Indexed`, `Column.Heap`, …) the dictionary composes.

---

## Community

<!-- BEGIN: discussion -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
