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

import Iterable
import Testing

@testable import Dictionary_Ordered_Primitives

// MARK: - Iteration helpers (post-Swift.Sequence-drop)
//
// `Dictionary.Ordered` (and its variants / Keys / Values views) no longer conform to
// `Swift.Sequence` / `Swift.Collection`; iteration is via the span-primitive `Iterable`
// floor (`forEach`). This helper materialises an `Iterable` into a `[Element]` for
// assertions, mirroring set-ordered's `toArray` test helper.

/// Materialises any `Iterable` (the dictionary, a variant, or a Keys/Values view) into
/// an array of its elements, preserving iteration order.
func toArray<S: Iterable & ~Copyable>(_ source: borrowing S) -> [S.Iterator.Element]
where S.Iterator.Failure == Never {
    var result: [S.Iterator.Element] = []
    source.forEach { result.append($0) }
    return result
}
