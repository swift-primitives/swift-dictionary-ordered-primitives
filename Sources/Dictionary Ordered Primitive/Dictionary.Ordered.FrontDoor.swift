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

public import Buffer_Linear_Primitive
public import Column_Primitives
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives

// MARK: - Dictionary<K, V>.Ordered — the sibling NEST alias ([DS-028], D4.1 sense (b))

extension __Dictionary where S: Store.`Protocol` & ~Copyable, S.Element: Hash.Key {

    /// An insertion-ordered dictionary over the family's default (growable move-only
    /// heap) ordered hashed entry column.
    ///
    /// This is a **nest alias** (D4.1 sense (b), [DS-028]): it merely NAMES the
    /// `__DictionaryOrdered` sibling carrier's canonical front door under the
    /// `Dictionary` family namespace, so consumers spell `Dictionary<Key, Value>.Ordered`.
    /// The ordered dictionary is a distinct order-contracting sibling ([DS-027].2, its
    /// own package/carrier), not a variant of `__Dictionary`; only its nest alias lives
    /// here. The `Shared` (CoW) column point is reached through the carrier's pinned
    /// constructors; its own front-door alias is consumer-pulled and lands as it gains a
    /// live consumer.
    public typealias Ordered =
        __DictionaryOrdered<Hash.Indexed<Column.Heap<S.Element>>>
}
