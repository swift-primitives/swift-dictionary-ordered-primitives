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

public import Dictionary_Ordered_Primitive
public import Dictionary_Primitives_Core
public import Index_Primitives

// MARK: - Typed Element Access (Copyable)

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Returns the key-value pair at the typed index, with typed error on bounds failure.
    ///
    /// - Parameter index: The typed index of the pair to access.
    /// - Returns: The key-value pair at the index.
    /// - Throws: ``Dictionary/Ordered/Error/bounds(_:)`` if the index is out of bounds.
    @inlinable
    public func element(at index: Index_Primitives.Index<Key>) throws(__DictionaryOrderedError<Key>) -> (key: Key, value: Value) {
        guard index < _keys.count else {
            throw .bounds(.init(index: index, count: _keys.count))
        }
        return (key: _keys[index], value: _values[index.retag(Value.self)])
    }
}
