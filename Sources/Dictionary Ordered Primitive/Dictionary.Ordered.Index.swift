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

public import Dictionary_Primitive
public import Index_Primitives

extension Dictionary_Primitive.Dictionary.Ordered where S: ~Copyable {
    /// The ORDERED INDEX DOMAIN — type-safe positions into the entry column.
    ///
    /// Uses `Index<S.Element>` (entry-tagged) to provide compile-time safety
    /// preventing cross-collection index confusion.
    ///
    /// ## Ordering contract
    ///
    /// The base `Dictionary<S>` makes no positional promise — its contract is
    /// keyed. `Ordered` CONTRACTS positions as insertion-order ranks:
    /// position `0` is the oldest live entry and `count − 1` the newest.
    /// Updating an existing key keeps its position; removing an entry shifts
    /// every later position down by one; re-insertion after removal appends
    /// at the end.
    public typealias Index = Index_Primitives.Index<S.Element>
}
