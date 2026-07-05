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

// The COLUMN-GENERIC ordered-dictionary surface: the count vocabulary rides the
// template bound; the keyed and positional ops pin per column
// (`Dictionary.Ordered+Columns.swift` / `Dictionary.Ordered+Positions.swift`) —
// they reach the engine, which only the concrete composite exposes.
public import Dictionary_Ordered_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Index_Primitives

extension __DictionaryOrdered where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol` {
    /// The number of key–value entries.
    @inlinable
    public var count: Index_Primitives.Index<S.Element>.Count { store.count }

    /// Whether the ordered dictionary is empty.
    @inlinable
    public var isEmpty: Bool { store.isEmpty }

    /// The dense plane's current capacity.
    @inlinable
    public var capacity: Index_Primitives.Index<S.Element>.Count { store.capacity }
}

// MARK: - Cloning (generic on the CoW column)

extension __DictionaryOrdered where S: Copyable, S: Store.`Protocol` {
    /// Returns an independent copy of this ordered dictionary with its own storage
    /// (the mutation gate on the fresh copy ALWAYS installs a deep copy).
    ///
    /// - Complexity: O(`capacity`)
    @inlinable
    public borrowing func clone() -> Self {
        var result = copy self
        result.store.unshare()
        return result
    }
}
