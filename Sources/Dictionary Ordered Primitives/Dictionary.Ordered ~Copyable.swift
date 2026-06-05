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
public import Buffer_Linear_Small_Primitive
public import Buffer_Linear_Inline_Primitives
public import Dictionary_Ordered_Primitive
public import Hash_Table_Static_Primitive
public import Index_Primitives
public import Finite_Bounded_Primitives

// MARK: - Initialization (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Creates an ordered dictionary with reserved capacity.
    ///
    /// Pre-allocates storage for the specified number of elements.
    ///
    /// - Parameter capacity: Number of elements to reserve space for.
    @inlinable
    public init(reservingCapacity capacity: Index_Primitives.Index<Key>.Count) throws(Self.Error) {
        // Delegate to the designated `init()` in the type module: a cross-module
        // extension initializer cannot initialize stored properties directly.
        self.init()
        self._keys.reserve(capacity)
        self._values.reserveCapacity(capacity.retag(Value.self))
    }
}

// MARK: - Properties (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count {
        _keys.count
    }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool {
        _keys.isEmpty
    }

    /// The current capacity.
    @inlinable
    public var capacity: Index_Primitives.Index<Key>.Count {
        _values.capacity.retag(Key.self)
    }
}

// MARK: - Contains (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Returns whether the dictionary contains the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if the key exists.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }
}

// MARK: - Capacity Management (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Ensures the dictionary has capacity for at least the specified number of elements.
    @usableFromInline
    mutating func ensureCapacity(_ minimumCapacity: Index_Primitives.Index<Key>.Count) {
        _values.reserveCapacity(minimumCapacity.retag(Value.self))
    }

    /// Reserves enough space for the specified number of pairs.
    ///
    /// - Parameter minimumCapacity: The minimum number of pairs.
    @inlinable
    public mutating func reserve(_ minimumCapacity: Index_Primitives.Index<Key>.Count) {
        _keys.reserve(minimumCapacity)
        ensureCapacity(minimumCapacity)
    }
}

// MARK: - Core Operations (~Copyable - Base)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Sets the value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Complexity: O(1) amortized.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) {
        if let existingKeyIndex = _keys.index(key) {
            _ = _values.replace(at: existingKeyIndex.retag(Value.self), with: value)
        } else {
            _keys.insert(key)
            _values.append(value)
        }
    }

    /// Removes the value for the given key.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if not present.
    /// - Complexity: O(n) due to index shifting.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let keyIndex = _keys.index(key) else { return nil }
        _keys.remove(key)
        return _values.remove(at: keyIndex.retag(Value.self))
    }

    /// Removes all key-value pairs.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    @inlinable
    public mutating func clear(keepingCapacity: Bool = false) {
        _keys.clear(keepingCapacity: keepingCapacity)
        _values.remove.all()
        if !keepingCapacity {
            _values = Buffer<Storage<Value>.Contiguous<Memory.Heap<Value>>>.Linear(minimumCapacity: .zero)
        }
    }
}

// MARK: - Peek (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Accesses the value for the given key via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - key: The key to look up.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure, or `nil` if the key doesn't exist.
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let keyIndex = _keys.index(key) else { return nil }
        return body(_values[keyIndex.retag(Value.self)])
    }

    /// Accesses the value at the given index via closure (for ~Copyable values).
    ///
    /// - Parameters:
    ///   - index: The typed index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Precondition: The index must be in bounds.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) -> R) -> R {
        precondition(index < _keys.count, "Index out of bounds")
        return body(_values[index.retag(Value.self)])
    }

    /// Accesses the value at the given index via closure, with typed error on bounds failure.
    ///
    /// - Parameters:
    ///   - index: The typed index.
    ///   - body: A closure that receives a borrowed reference to the value.
    /// - Returns: The result of the closure.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if the index is out of bounds.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) throws(__DictionaryOrderedError<Key>) -> R) throws(__DictionaryOrderedError<Key>) -> R {
        guard index < _keys.count else {
            throw .bounds(.init(index: index, count: _keys.count))
        }
        return try body(_values[index.retag(Value.self)])
    }
}

// MARK: - forEach (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {
    /// Calls the given closure for each key-value pair in the dictionary.
    ///
    /// Elements are visited in insertion order.
    ///
    /// - Parameter body: A closure that receives each key and borrowed value.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public func forEach(_ body: (Key, borrowing Value) -> Void) {
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            body(_keys[idx], _values[idx.retag(Value.self)])
            idx += .one
        }
    }

    /// Drains all key-value pairs from the dictionary, passing each to the closure.
    ///
    /// After this method returns, the dictionary is empty but still usable.
    /// Entries are visited in insertion order. Values are moved out (consumed).
    ///
    /// - Parameter body: A closure that receives each entry with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Entry) -> Void) {
        var idx: Index_Primitives.Index<Key> = .zero
        let end = _keys.count.map(Ordinal.init)
        while idx < end {
            body(Entry(key: _keys[idx], value: _values.remove.first()))
            idx += .one
        }
        _keys.clear(keepingCapacity: true)
    }
}

// MARK: - Bounded Variant (~Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: ~Copyable {
    // Note: `Bounded.Error` typealias is co-located with the type in the type module
    // (Dictionary.Ordered.Bounded.swift) per [MOD-036] — the canonical init throws it.

    /// The number of key-value pairs.
    @inlinable
    public var count: Index_Primitives.Index<Key>.Count { _keys.count }

    /// Whether the dictionary is empty.
    @inlinable
    public var isEmpty: Bool { _keys.isEmpty }

    /// Whether the dictionary is at capacity.
    @inlinable
    public var isFull: Bool { _keys.count >= capacity }

    /// Returns whether the dictionary contains the given key.
    @inlinable
    public func contains(_ key: Key) -> Bool {
        _keys.contains(key)
    }

    /// Sets a value for the given key.
    ///
    /// - Parameters:
    ///   - key: The key.
    ///   - value: The value to associate with the key.
    /// - Throws: ``Dictionary/Ordered/Bounded/Error/overflow`` if the dictionary is full
    ///   and the key is new.
    @inlinable
    public mutating func set(_ key: Key, _ value: consuming Value) throws(Self.Error) {
        if let existingKeyIndex = _keys.index(key) {
            _ = _values.replace(at: existingKeyIndex.retag(Value.self), with: value)
        } else {
            guard _keys.count < capacity else {
                throw .overflow
            }
            _keys.insert(key)
            _ = _values.append(value)
        }
    }

    /// Removes a key-value pair.
    ///
    /// - Parameter key: The key to remove.
    /// - Returns: The removed value, or `nil` if the key was not present.
    @inlinable
    @discardableResult
    public mutating func remove(_ key: Key) -> Value? {
        guard let keyIndex = _keys.index(key) else { return nil }
        _keys.remove(key)
        return _values.remove(at: keyIndex.retag(Value.self))
    }

    /// Removes all key-value pairs.
    @inlinable
    public mutating func clear() {
        _keys.clear(keepingCapacity: true)
        _values.remove.all()
    }

    /// Accesses the value for the given key via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(forKey key: Key, _ body: (borrowing Value) -> R) -> R? {
        guard let keyIndex = _keys.index(key) else { return nil }
        return body(_values[keyIndex.retag(Value.self)])
    }

    /// Accesses the value at the given typed index via closure (for ~Copyable values).
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_values[index.retag(Value.self)])
    }

    /// Accesses the value at the given typed index via closure, with typed error on bounds failure.
    @inlinable
    public func withValue<R>(at index: Index_Primitives.Index<Key>, _ body: (borrowing Value) throws(__DictionaryOrderedBoundedError<Key>) -> R) throws(__DictionaryOrderedBoundedError<Key>) -> R {
        guard index < count else {
            throw .bounds(index: index, count: count)
        }
        return try body(_values[index.retag(Value.self)])
    }
}

// MARK: - Inline Variant (~Copyable)


// Note: Inline is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.

// MARK: - Small Variant (~Copyable)


// Note: Small is unconditionally ~Copyable (has deinit), cannot conform to Equatable/Hashable
// which require Copyable. Use isEqual(to:) method instead if needed.
