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

// The ORDER-FACING doors — the discipline this package exists for. Positions are
// insertion-order ranks into the dense plane (``Dictionary/Ordered/Index``), so
// every positional read is O(1); `index(forKey:)` is the engine's projected-key
// probe. Bounds violations are programmer errors (preconditions, matching the
// indexed seam's discipline) — key ABSENCE stays `nil`-shaped, position absence
// traps. Positional mutation is VALUE-only (mutability ruling (a)): the key at a
// position — and therefore its hash and its rank — never changes through these
// doors.
public import Dictionary_Ordered_Primitive
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
public import Hash_Primitives
public import Ownership_Shared_Primitive
public import Column_Primitives
public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration

// ============================================================================
// MARK: - Key → position (the engine's projected-key probe)
// ============================================================================

extension __DictionaryOrdered where S: ~Copyable {
    /// The position of the entry for the key, or `nil` if the key is absent
    /// (direct column).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func index<K: Hash.Key & ~Copyable, V: ~Copyable>(forKey key: borrowing K) -> Index_Primitives.Index<Hash.Entry<K, V>>?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
        )
    }

    /// The position of the entry for the key (`Shared` column; no gate — reads
    /// never detach).
    ///
    /// - Complexity: O(1) average
    @inlinable
    public func index<K: Hash.Key & ~Copyable, V: ~Copyable>(forKey key: borrowing K) -> Index_Primitives.Index<Hash.Entry<K, V>>?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in candidate.key == probe }
            )
        }
    }
}

// ============================================================================
// MARK: - Positional reads
// ============================================================================

extension __DictionaryOrdered where S: ~Copyable {
    /// The key at the position (direct column).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func key<K: Hash.Key, V: ~Copyable>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> K
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(position < store.count.map(Ordinal.init), "ordered index domain: position out of bounds")
        return store[position].key
    }

    /// The key at the position (`Shared` column; no gate).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func key<K: Hash.Key, V: ~Copyable>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> K
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(position < column.count.map(Ordinal.init), "ordered index domain: position out of bounds")
            return column[position].key
        }
    }

    /// The value at the position (direct column).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func value<K: Hash.Key & ~Copyable, V>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> V
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(position < store.count.map(Ordinal.init), "ordered index domain: position out of bounds")
        return store[position].value
    }

    /// The value at the position (`Shared` column; no gate).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func value<K: Hash.Key & ~Copyable, V>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> V
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(position < column.count.map(Ordinal.init), "ordered index domain: position out of bounds")
            return column[position].value
        }
    }

    /// The key–value pair at the position (direct column).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func entry<K: Hash.Key, V>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> (key: K, value: V)
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(position < store.count.map(Ordinal.init), "ordered index domain: position out of bounds")
        return (key: store[position].key, value: store[position].value)
    }

    /// The key–value pair at the position (`Shared` column; no gate).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1)
    @inlinable
    public func entry<K: Hash.Key, V>(at position: Index_Primitives.Index<Hash.Entry<K, V>>) -> (key: K, value: V)
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(position < column.count.map(Ordinal.init), "ordered index domain: position out of bounds")
            return (key: column[position].key, value: column[position].value)
        }
    }

    /// Calls the closure with the value at the position; returns its result
    /// (direct column; the move-only-honest positional read).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1), plus the closure
    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(at position: Index_Primitives.Index<Hash.Entry<K, V>>, _ body: (borrowing V) -> R) -> R
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(position < store.count.map(Ordinal.init), "ordered index domain: position out of bounds")
        return body(store[position].value)
    }

    /// Calls the closure with the value at the position (`Shared` column; no gate).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1), plus the closure
    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(at position: Index_Primitives.Index<Hash.Entry<K, V>>, _ body: (borrowing V) -> R) -> R
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(position < column.count.map(Ordinal.init), "ordered index domain: position out of bounds")
            return body(column[position].value)
        }
    }
}

// ============================================================================
// MARK: - Positional value mutation (mutability ruling (a): the key — and so the
// position's hash identity — stays put; the seam's re-index guard takes its
// cheap no-change branch)
// ============================================================================

extension __DictionaryOrdered where S: ~Copyable {
    /// Calls the closure with mutable access to the value at the position;
    /// returns its result (direct column).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1), plus the closure
    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(at position: Index_Primitives.Index<Hash.Entry<K, V>>, _ body: (inout V) -> R) -> R
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(position < store.count.map(Ordinal.init), "ordered index domain: position out of bounds")
        return body(&store[position].value)
    }

    /// Calls the closure with mutable access to the value at the position
    /// (`Shared` column; uniqueness restored first).
    ///
    /// - Precondition: `position < count`.
    /// - Complexity: O(1) (O(`capacity`) when a copy must be made first), plus the closure
    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(at position: Index_Primitives.Index<Hash.Entry<K, V>>, _ body: (inout V) -> R) -> R
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withUnique { column in
            precondition(position < column.count.map(Ordinal.init), "ordered index domain: position out of bounds")
            return body(&column[position].value)
        }
    }
}
