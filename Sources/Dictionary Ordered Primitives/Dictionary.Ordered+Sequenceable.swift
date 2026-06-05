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

public import Dictionary_Ordered_Primitive
public import Storage_Small_Primitives
public import Dictionary_Primitives_Core
public import Sequence_Primitives

// MARK: - Sequenceable (single-pass, consuming)
//
// Re-uses the scalar pair `Iterator` (single-pass, consuming). The consuming
// `makeIterator()` witness is a public member in the type module
// (Dictionary.Ordered+Sequenceable.swift) per [MOD-036] refined-C; this conformance
// is thin and splits the `Iterator` associated-type binding from `Iterable`'s via
// `@_implements`.
//
// `Dictionary.Ordered` does not conform to `Swift.Sequence`: the span-primitive
// iteration family is `~Copyable, ~Escapable` end-to-end and cannot back a Copyable
// stdlib `IteratorProtocol` without re-introducing a per-type Copyable iterator. This
// is the DEFERRED `Swift.Sequence`-interop axis settled ecosystem-wide — see
// set-ordered-capability-composition.md §2.8 / §3 (one generic `Swift.Sequence` bridge
// `where Element: Copyable`, vended once). The dropped per-type `Swift.Sequence`,
// `Swift.Collection`, `Swift.BidirectionalCollection`, and `Swift.RandomAccessCollection`
// conformances are a deliberate consumer-facing removal to match the exemplar.

extension Dictionary_Primitives_Core.Dictionary.Ordered: Sequenceable where Value: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Iterator

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}
