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
public import Storage_Small_Primitives
public import Dictionary_Primitives_Core
public import Index_Primitives
public import Set_Ordered_Primitive

// MARK: - Typed Access (Dictionary.Ordered)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Accesses the key at the given typed index.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public func key(at index: Dictionary<Key, Value>.Index) -> Key {
        precondition(index < count, "Index out of bounds")
        return _keys[index]
    }

    /// Accesses the value at the given typed index.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Precondition: `index` must be in bounds.
    @inlinable
    public func value(at index: Dictionary<Key, Value>.Index) -> Value {
        precondition(index < count, "Index out of bounds")
        return _values[index.retag(Value.self)]
    }

    /// Returns the key-value pair at the typed index, or nil if out of bounds.
    ///
    /// - Parameter index: The typed index of the entry to access.
    /// - Returns: The key-value pair at the index, or `nil` if out of bounds.
    @inlinable
    public func entry(at index: Dictionary<Key, Value>.Index) -> (key: Key, value: Value)? {
        guard index < count else { return nil }
        let key = _keys[index]
        return (key, _values[index.retag(Value.self)])
    }
}
