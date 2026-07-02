// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Umbrella per [MOD-005]. Re-export the in-package targets so a single
// `import Dictionary_Ordered_Primitives` surfaces the whole package.
//
// NB: the pre-reshape composition (`Set.Ordered` keys + a parallel value plane,
// with Bounded/Inline/Small capacity variants, Builder, Merge, Keys/Values
// views, and Iterator/Iterable/Sequenceable conformances) is RETIRED (W5
// ordered round, 2026-06-11) — replaced by the column-generic carrier
// `__DictionaryOrdered<S>` (nest alias `Dictionary<K, V>.Ordered`) over
// `Hash.Indexed` with key-projected `Hash.Entry` elements. The namespace and column
// packages are ordinary dependencies, never re-exported (zero cross-package
// re-exports).

@_exported public import Dictionary_Ordered_Primitive
