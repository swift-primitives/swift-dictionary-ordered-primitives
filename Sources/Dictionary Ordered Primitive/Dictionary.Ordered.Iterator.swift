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
public import Dictionary_Primitives_Core
public import Index_Primitives
public import Iterator_Primitive
public import Set_Ordered_Primitive

// MARK: - Scalar pair iterator
//
// The divergent case: `Dictionary.Ordered`'s element is `(key: Key, value: Value)`,
// a pair split across two parallel buffers (`_keys: Set.Ordered`, `_values:
// Buffer.Linear`). There is NO contiguous span of pairs, so the dictionary cannot
// vend `Iterator.Chunk` over a `span` the way contiguous single-element containers
// (set-ordered, stack, heap) do. Instead this scalar `Iterator.`Protocol`` synthesises
// each pair by walking the parallel storage by index; the bulk-iteration face is
// produced by wrapping it in `Iterator.Materializing` (see Dictionary.Ordered+Iterable.swift),
// exactly as the generator-style single/cyclic iterators do.
//
// In the type module per [MOD-036]: the `init(_:)` captures the dictionary's internal
// `_keys`/`_values` storage.

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// A single-pass scalar iterator over the dictionary's key-value pairs, in insertion order.
    ///
    /// Pairs are synthesised by walking the parallel `_keys`/`_values` storage by index.
    /// This is the scalar `Iterator.`Protocol`` source the materialising bulk iterator
    /// (`Iterator.Materializing`) wraps for the `Iterable` face, and the iterator the
    /// consuming `Sequenceable` face vends directly.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        let _values: Buffer<Value>.Linear

        @usableFromInline
        var _index: Index_Primitives.Index<Key>

        @usableFromInline
        let _count: Index_Primitives.Index<Key>.Count

        @inlinable
        init(_ dict: borrowing Dictionary<Key, Value>.Ordered) {
            self._keys = dict._keys
            self._values = dict._values
            self._index = .zero
            self._count = dict._keys.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _index < _count else { return nil }
            let key = _keys[_index]
            let value = _values[_index.retag(Value.self)]
            _index = _index + .one
            return (key, value)
        }
    }
}
