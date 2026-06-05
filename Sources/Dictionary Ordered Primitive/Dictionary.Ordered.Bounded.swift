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
public import Dictionary_Primitives_Core
public import Index_Primitives
public import Set_Ordered_Primitive

extension Dictionary_Primitives_Core.Dictionary.Ordered where Value: ~Copyable {

    /// A fixed-capacity ordered dictionary that throws on overflow.
    ///
    /// `Dictionary.Ordered.Bounded` allocates storage upfront and throws when
    /// inserting a key-value pair would exceed the capacity.
    ///
    /// ## Example
    ///
    /// ```swift
    /// var dict = try Dictionary<String, Int>.Ordered.Bounded(capacity: 10)
    /// try dict.set("apple", 1)
    /// try dict.set("banana", 2)
    /// dict["apple"]  // Optional(1)
    /// ```
    ///
    /// ## Move-Only Support
    ///
    /// Both the dictionary and its values can be `~Copyable`:
    ///
    /// ```swift
    /// struct FileHandle: ~Copyable { ... }
    /// var dict = try Dictionary<String, FileHandle>.Ordered.Bounded(capacity: 5)
    /// try dict.set("primary", FileHandle())
    /// ```
    // WHY: Category D — structural Sendable workaround; the type is
    // WHY: structurally value-safe but the compiler cannot synthesize
    // WHY: Sendable due to a stored pointer / generic parameter shape.
    @safe
    public struct Bounded: ~Copyable {
        public var _keys: Set<Key>.Ordered

        public var _values: Buffer<Storage<Value>.Contiguous<Memory.Heap<Value>>>.Linear.Bounded

        /// The maximum number of key-value pairs the dictionary can hold.
        public let capacity: Index_Primitives.Index<Key>.Count

        /// Creates a bounded ordered dictionary with the specified capacity.
        ///
        /// - Parameter capacity: Maximum number of pairs. Must be non-negative.
        /// - Throws: ``Dictionary/Ordered/Bounded/Error/invalidCapacity`` if capacity is negative.
        @inlinable
        public init(capacity: Index_Primitives.Index<Key>.Count) throws(Dictionary_Primitives_Core.Dictionary<Key, Value>.Ordered.Bounded.Error) {
            self._keys = Set<Key>.Ordered()
            self._keys.reserve(capacity)
            self._values = Buffer<Storage<Value>.Contiguous<Memory.Heap<Value>>>.Linear.Bounded(minimumCapacity: capacity.retag(Value.self))
            self.capacity = capacity
        }

        // Note: No deinit needed - Buffer.Linear.Bounded handles cleanup
    }
}

// MARK: - Error Typealias (Nest.Name API)
//
// Co-located with the type per [MOD-036]: `Bounded.Error` is the error type the
// canonical `init(capacity:)` above throws, so its typealias belongs in the type
// module alongside the init. (The growable base's `Dictionary.Ordered.Error` lives
// in the type module's Dictionary.Ordered.Error.swift for the same reason.)

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded where Value: ~Copyable {
    /// Errors that can occur during bounded ordered dictionary operations.
    public typealias Error = __DictionaryOrderedBoundedError<Key>
}

// MARK: - Conditional Conformances

/// `Dictionary.Ordered.Bounded` is `Copyable` when its values are `Copyable`.
extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: Copyable where Value: Copyable {}

// MARK: - Sendable

extension Dictionary_Primitives_Core.Dictionary.Ordered.Bounded: @unsafe @unchecked Sendable where Key: Sendable, Value: Sendable {}
