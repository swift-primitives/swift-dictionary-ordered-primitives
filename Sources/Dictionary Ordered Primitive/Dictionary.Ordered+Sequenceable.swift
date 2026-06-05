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

public import Dictionary_Primitives_Core
public import Memory_Small_Primitives

// MARK: - Sequenceable witness (consuming makeIterator)
//
// The single-pass consuming scalar iterator in insertion order — the `Copyable`
// witness for the cold `Sequenceable` conformance (declared in the ops module,
// Dictionary.Ordered+Sequenceable.swift). A public member in the type module per
// [MOD-036] refined-C: `Iterator(self)` captures the internal `_keys`/`_values`.

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: Copyable {

    /// A single-pass consuming iterator over key-value pairs in insertion order.
    /// Witness for `Sequenceable`.
    @inlinable
    public consuming func makeIterator() -> Iterator {
        Iterator(self)
    }
}
