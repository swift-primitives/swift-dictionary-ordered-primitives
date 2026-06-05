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
public import Memory_Small_Primitives
public import Dictionary_Primitives_Core

// MARK: - removeAll()

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {
    /// Removes all key-value pairs from the dictionary.
    @inlinable
    public mutating func removeAll() {
        clear(keepingCapacity: false)
    }
}
