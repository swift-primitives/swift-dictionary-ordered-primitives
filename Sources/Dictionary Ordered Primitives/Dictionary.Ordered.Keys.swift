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

public import Index_Primitives
public import Storage_Small_Primitives
public import Iterable
public import Iterator_Primitive
public import Iterator_Chunk_Primitives
public import Sequence_Primitives
public import Set_Primitives

// MARK: - Keys Accessor

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Nested accessor for key operations.
    ///
    /// ```swift
    /// if let idx = dict.keys.index("apple") { ... }
    /// let allKeys = dict.keys.all
    /// ```
    @inlinable
    public var keys: Keys {
        Keys(keys: _keys)
    }
}

// MARK: - Keys Type

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Namespace for key operations.
    ///
    /// Keys are always `Copyable` since `Key: Hashable` implies `Copyable`.
    public struct Keys {
        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        init(keys: Set<Key>.Ordered) {
            self._keys = keys
        }
    }
}

// MARK: - Keys Operations

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys where Value: ~Copyable {
    /// Returns the index of the given key, or `nil` if not present.
    ///
    /// - Parameter key: The key to find.
    /// - Returns: The typed index of the key.
    /// - Complexity: O(1) average.
    @inlinable
    public func index(_ key: Key) -> Index_Primitives.Index<Key>? {
        _keys.index(key)
    }

    /// All keys in order.
    @inlinable
    public var all: Set<Key>.Ordered {
        _keys
    }

    /// The number of keys.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count {
        _keys.count
    }

    /// Whether the keys collection is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The key at the given typed index.
    ///
    /// - Parameter index: The typed index.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public subscript(_ index: Index_Primitives.Index<Key>) -> Key {
        _keys[index]
    }

    /// The key at the given raw index (stdlib compatibility).
    @inlinable
    public subscript(raw index: Int) -> Key {
        let keyIndex = Index_Primitives.Index<Key>(Ordinal(UInt(index)))
        return _keys[keyIndex]
    }

    /// Returns whether the given key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Scalar iterator
//
// The Keys view yields keys one at a time by walking the underlying `Set<Key>.Ordered`
// by index. Wrapped in `Iterator.Materializing` for the bulk `Iterable` face — the same
// self-contained generator shape the parent dictionary uses, avoiding any reliance on
// the underlying type's bridge-vended iterator overloads.

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys {
    /// Single-pass scalar iterator over the keys in insertion order.
    public struct Iterator: Iterator_Primitive.Iterator.`Protocol`, IteratorProtocol {
        @usableFromInline
        let _keys: Set<Key>.Ordered

        @usableFromInline
        var _index: Index_Primitives.Index<Key>

        @usableFromInline
        let _count: Index_Primitives.Index<Key>.Count

        @inlinable
        init(_ keys: Set<Key>.Ordered) {
            self._keys = keys
            self._index = .zero
            self._count = keys.count
        }

        @inlinable
        public mutating func next() -> Key? {
            guard _index < _count else { return nil }
            let key = _keys[_index]
            _index = _index + .one
            return key
        }
    }
}

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys.Iterator: Sendable where Key: Sendable {}

// MARK: - Iterable (multipass, borrowing) — via materialising adapter
//
// Keys does NOT conform to `Swift.Sequence`: dropped to match the exemplar (the
// deferred stdlib-interop axis).

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys: Iterable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Primitive.Iterator.Materializing<Iterator>

    @inlinable
    @_lifetime(borrow self)
    @_implements(Iterable, makeIterator())
    public borrowing func iterableMakeIterator() -> Iterator_Primitive.Iterator.Materializing<Iterator> {
        Iterator_Primitive.Iterator.Materializing(Iterator(_keys))
    }
}

// MARK: - Sequenceable (single-pass, consuming)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Keys: Sequenceable {
    @_implements(Sequenceable, Iterator)
    public typealias SequenceableIterator = Iterator

    @inlinable
    public consuming func makeIterator() -> Iterator {
        Iterator(_keys)
    }
}
