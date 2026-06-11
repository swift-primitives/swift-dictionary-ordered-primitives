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

public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Shared_Primitive
public import Column_Primitives
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Index_Primitives

// MARK: - Dictionary.Ordered (the ORDER-CONTRACTING ADT over the same ordered
// hashed entry column the base `Dictionary<S>` composes)

extension Dictionary_Primitive.Dictionary where S: ~Copyable {
    /// The insertion-ordered dictionary DISCIPLINE — the sibling template of
    /// `Dictionary<S>` over the same ordered hashed entry column (the W5 ordered
    /// round of the ADT-families reshape; the old element-keyed
    /// `Dictionary<Key, Value>.Ordered` over `Set.Ordered` + a parallel value
    /// plane is retired).
    ///
    /// `Dictionary<S>` already iterates in insertion order (today's column is
    /// `Hash.Indexed`), but the base ADT's contract is KEYED — it exposes no
    /// positions. `Ordered` is where the order-facing surface lives:
    ///
    ///   • the ordered index domain (``Dictionary/Ordered/Index``: positions are
    ///     insertion-order ranks `0 ..< count`),
    ///   • positional access (`key(at:)`, `value(at:)`, `entry(at:)`,
    ///     `withValue(at:)`, `withMutableValue(at:)`),
    ///   • the key → position door (`index(forKey:)`),
    ///
    /// alongside the full keyed surface mirrored from `Dictionary<S>`.
    ///
    /// The ratified two-column design: `Ordered` is generic over `S`, and
    /// **copyability flows from the column** (S5):
    ///
    /// ```swift
    /// Dictionary<                       Hash.Indexed<Column.Heap<Hash.Entry<Key, FD >>>>.Ordered   // zero-cost MOVE-ONLY (default)
    /// Dictionary<Shared<Hash.Entry<…>,  Hash.Indexed<Column.Heap<Hash.Entry<Key, Int>>>>>.Ordered  // explicit CoW value semantics
    /// ```
    ///
    /// The column is `Hash.Indexed<Dense>` with `Dense.Element == Hash.Entry<Key,
    /// Value>`: entries live DENSELY in insertion order; the hash side is the
    /// bucket position-index engine (tombstone-free backward shift, per-instance
    /// seed). Positions ARE the dense slots, so positional access is O(1) and the
    /// engine's `position(matching:)` doubles as `index(forKey:)`. `Shared` wraps
    /// the COMPOSITE — one box, one clone strategy.
    ///
    /// Keys are immutable; values mutate in place behind a hash-stable key
    /// (`withMutableValue` — mutability ruling (a)). Updating an existing key
    /// keeps its position; removal preserves the order of the remaining entries
    /// (positions after the removal point shift down by one); re-insertion after
    /// removal appends at the end.
    @frozen
    public struct Ordered: ~Copyable {

        /// The ordered hashed entry column — move-only (the default ownership
        /// column) or a `Shared` CoW column. The ADT is a thin keyed-plus-ordered
        /// discipline over it; it carries NO deinit.
        @usableFromInline
        package var store: S

        /// Wraps an existing column.
        @inlinable
        public init(store: consuming S) {
            self.store = store
        }

        /// Consumes the ordered dictionary, yielding its storage column.
        @inlinable
        public consuming func take() -> S {
            store
        }
    }
}

// MARK: - Conditional Conformances (co-located per [COPY-FIX-004])

/// The S5 chain: `Dictionary<Shared<Hash.Entry<K, V>, B>>.Ordered` is `Copyable`
/// exactly when the entry is.
extension Dictionary_Primitive.Dictionary.Ordered: Copyable where S: Copyable {}

extension Dictionary_Primitive.Dictionary.Ordered: Sendable where S: Sendable & ~Copyable {}

// MARK: - Column-pinned construction ([MEM-COPY-017]: the split lives in `Shared`'s
// pinned constructor pair; the `Ordered` forms pick the column)

extension Dictionary_Primitive.Dictionary.Ordered where S: ~Copyable {
    /// Creates an empty MOVE-ONLY ordered dictionary (the default ownership column).
    @inlinable
    public init<K: Hash.Key & ~Copyable, V: ~Copyable>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        self.init(store: S(minimumCapacity: minimumCapacity))
    }

    /// Creates an empty CoW (value-semantic) ordered dictionary on the `Shared` column.
    @inlinable
    public init<K: Hash.Key, V>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        self.init(store: Shared(
            Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>(minimumCapacity: minimumCapacity)
        ))
    }

    /// Creates an empty statically-unique ordered dictionary of move-only values
    /// on the `Shared` column (the boxed flavor of the move-only regime).
    @inlinable
    public init<K: Hash.Key & ~Copyable, V: ~Copyable>(
        minimumCapacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count = .zero
    )
    where S == Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        self.init(store: Shared(
            Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>(minimumCapacity: minimumCapacity)
        ))
    }
}
