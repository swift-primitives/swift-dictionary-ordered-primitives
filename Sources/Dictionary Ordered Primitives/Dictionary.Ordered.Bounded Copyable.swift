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
public import Memory_Small_Primitives
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
public import Buffer_Linear_Bounded_Primitive
public import Dictionary_Ordered_Primitive
public import Dictionary_Primitives_Core
public import Index_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives
import Sequence_Primitives

// MARK: - Scalar pair iterator
//
// Divergent pair type (no contiguous span of pairs): synthesises each `(key, value)`
// by walking the parallel `_keys`/`_values` by index. Wrapped in `Iterator.Materializing`
// for the bulk `Iterable` face below.

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: Copyable {
    /// Single-pass scalar iterator for bounded ordered dictionary key-value pairs.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        let _values: Buffer<Storage<Value>.Contiguous<Memory.Heap<Value>>>.Linear.Bounded

        @usableFromInline
        var _index: Index_Primitives.Index<Key>

        @usableFromInline
        let _count: Index_Primitives.Index<Key>.Count

        @inlinable
        init(_ dict: borrowing Dictionary<Key, Value>.Ordered.Bounded) {
            self._keys = dict._keys
            self._values = dict._values
            self._index = .zero
            self._count = dict.count
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

// MARK: - Iterable (multipass, borrowing) — via materialising adapter

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Iterable where Value: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Iterator>

    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Iterator> {
        Iterator_Primitive.Iterator.Materializing(Iterator(self))
    }
}

// MARK: - Sequenceable (single-pass, consuming)
//
// `Dictionary.Ordered.Bounded` does not conform `Swift.Sequence` / `Swift.Collection`
// / `Swift.BidirectionalCollection` / `Swift.RandomAccessCollection`: dropped to match
// the exemplar (the deferred stdlib-interop axis). Index-based access remains available
// via the `subscript(index:)` and the typed `value(at:)` / `entry(at:)` accessors.

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Sequenceable where Value: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Iterator

    @inlinable
    public consuming func makeIterator() -> Iterator {
        Iterator(self)
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// MARK: - Sequence.Clearable Conformance

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
