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
public import Buffer_Protocol_Primitives
public import Column_Primitives
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
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
    /// here. The `Shared` (CoW, value-semantic) column point has its own front-door
    /// nest alias `Dictionary<K, V>.Ordered.Shared`, declared below — consumer-pulled
    /// by `RFC_6570` (2026-07-10, ratified decider #8).
    public typealias Ordered =
        __DictionaryOrdered<Hash.Indexed<Column.Heap<S.Element>>>
}

// MARK: - Dictionary<K, V>.Ordered.Shared — the OWNERSHIP variant ([DS-028] law 2)

extension __DictionaryOrdered
where
    S: ~Copyable,
    S: Store.`Protocol` & Buffer.`Protocol`
{

    /// The explicit CoW (value-semantic) ordered dictionary: the current ordered
    /// hashed entry column boxed behind `Ownership.Shared`.
    ///
    /// This is an ownership-axis variant alias ([DS-028] law 2) — a
    /// column-PRESERVING transformer that wraps the member it is named on
    /// (`Ownership.Shared` wraps `S` unconditionally, so it chains correctly ahead of
    /// any future allocation or capacity variant; no `Store.Direct` fence — law 2
    /// preserves `S`). `Shared` boxes the COMPOSITE column — one box around both the
    /// dense entry plane and the position-index engine, one clone strategy.
    /// Copyability flows from the entry: `Dictionary<K, V>.Ordered.Shared` is
    /// `Copyable` exactly when `K`/`V` are; copies share the backing box until the
    /// first mutation restores uniqueness (copy-on-write). It carries the identical
    /// keyed + positional surface as the move-only `Ordered`, so consumers reach the
    /// CoW column by spelling `Dictionary<Key, Value>.Ordered.Shared` rather than the
    /// carrier's pinned `Shared` constructor.
    ///
    /// **Consumer-pulled** (2026-07-10, ratified decider #8): the deferred `Shared`
    /// front-door alias lands here because `RFC_6570` (`swift-rfc-6570`) is now the
    /// live consumer — its `RFC_6570.Variable` associated-list payload needs the
    /// Copyable ordered dictionary, which only the `Shared` column provides.
    ///
    /// ```swift
    /// var d = Dictionary<String, String>.Ordered.Shared()   // CoW value-semantic
    /// var e = d                        // shares d's backing — no entry copy
    /// e.insert(key: "a", value: "1")   // copy-on-write: e diverges, d untouched
    /// ```
    public typealias Shared = __DictionaryOrdered<Ownership.Shared<S.Element, S>>
}
