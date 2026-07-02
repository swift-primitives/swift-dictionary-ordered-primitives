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

// Dictionary Ordered Primitive declares the hoisted sibling carrier
// `struct __DictionaryOrdered<S: ~Copyable>` ([DS-025], the order-contracting
// sibling of `__Dictionary`) plus the sibling NEST alias `Dictionary<K, V>.Ordered`
// ([DS-028], `Dictionary.Ordered.FrontDoor.swift`) and its ordered index domain
// `__DictionaryOrdered.Index`. The pinned keyed + positional surface lives in the
// umbrella target's `Dictionary.Ordered+Columns.swift` /
// `Dictionary.Ordered+Positions.swift`. No re-exports here — the namespace and
// column packages are ordinary dependencies ([MOD-005]: umbrellas re-export
// in-package targets only).
