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
public import Dictionary_Ordered_Primitive
public import Dictionary_Primitives_Core
public import Index_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives
import Sequence_Primitives
public import Buffer_Linear_Inline_Primitive

// Note: Dictionary.Ordered.Static is unconditionally ~Copyable (inline storage requires deinit),
// so it never conformed to Swift.Sequence (which requires Copyable). It now exposes the
// span-primitive iteration via Iterable (materialising adapter) + Sequenceable.

// ============================================================================
// MARK: - Scalar pair iterator
// ============================================================================
//
// Copies keys and values to `Buffer.Linear` snapshots for safe iteration, avoiding
// pointer-escape issues with inline storage; then synthesises each `(key, value)` pair
// by walking the parallel snapshots by index. Wrapped in `Iterator.Materializing` for
// the bulk `Iterable` face below.

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static where Value: Copyable {
    /// Single-pass scalar iterator for `Dictionary.Ordered.Static` key-value pairs.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol {
        public typealias Element = (key: Key, value: Value)

        @usableFromInline
        let _keys: Buffer<Storage<Key>.Heap>.Linear

        @usableFromInline
        let _values: Buffer<Storage<Value>.Heap>.Linear

        @usableFromInline
        let _end: Index_Primitives.Index<Key>.Count

        @usableFromInline
        var _position: Index_Primitives.Index<Key> = .zero

        @usableFromInline
        init(keys: Buffer<Storage<Key>.Heap>.Linear, values: Buffer<Storage<Value>.Heap>.Linear) {
            self._keys = keys
            self._values = values
            self._end = keys.count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard _position < _end else { return nil }
            let key = _keys[_position]
            let value = _values[_position.retag(Value.self)]
            _position += .one
            return (key, value)
        }
    }
}

// WHY: Category D — structural Sendable workaround; the iterator holds
// WHY: `Buffer<Storage<{Key,Value}>.Heap>.Linear` whose Heap substrate is
// WHY: Sendable due to a stored pointer, mirroring the parent container.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Static.Iterator: @unsafe @unchecked Sendable
where Key: Sendable, Value: Sendable {}

// MARK: - Snapshot helper (names internal storage)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static where Value: Copyable {
    /// Builds parallel `Buffer.Linear` snapshots of the inline key/value storage.
    @inlinable
    func _snapshotIterator() -> Iterator {
        var keySnapshot = Buffer<Storage<Key>.Heap>.Linear(minimumCapacity: _keys.count)
        var valueSnapshot = Buffer<Storage<Value>.Heap>.Linear(minimumCapacity: _values.count)
        var i: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while i < end {
            keySnapshot.append(_keys[i])
            valueSnapshot.append(_values[i.retag(Value.self)])
            i += .one
        }
        return Iterator(keys: keySnapshot, values: valueSnapshot)
    }
}

// ============================================================================
// MARK: - Iterable (multipass, borrowing) — via materialising adapter
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: Iterable where Value: Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Iterator>

    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Iterator> {
        Iterator_Primitive.Iterator.Materializing(_snapshotIterator())
    }
}

// ============================================================================
// MARK: - Sequenceable (single-pass, consuming)
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: Sequenceable where Value: Copyable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Iterator

    /// Returns a single-pass iterator over the dictionary's key-value pairs.
    ///
    /// Copies keys and values to `Buffer.Linear` snapshots for safe iteration,
    /// avoiding pointer-escape issues with inline storage. Pairs are yielded in
    /// insertion order.
    ///
    /// - Note: Incurs O(n) copy cost. For performance-critical code, use the
    ///   `withValue(forKey:_:)` method or index-based access instead.
    @inlinable
    public consuming func makeIterator() -> Iterator {
        _snapshotIterator()
    }

    /// Returns the count as the underestimated count since we know the exact size.
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: count) }
}

// ============================================================================
// MARK: - Sequence.Clearable Conformance
// ============================================================================

extension Dictionary_Primitives_Core.Dictionary.Ordered.Static: Sequence.Clearable where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    ///
    /// This enables `.forEach.consuming { }` pattern via `Property.Inout` extension.
    @inlinable
    public mutating func removeAll() {
        clear()
    }
}
