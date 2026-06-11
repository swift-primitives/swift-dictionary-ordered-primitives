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

// Dictionary Ordered Primitive declares the base type: the column-generic
// `Dictionary<S>.Ordered` template (the order-contracting sibling of
// `Dictionary<S>`) plus its ordered index domain `Dictionary.Ordered.Index`.
// The pinned keyed + positional surface lives in the umbrella target's
// `Dictionary.Ordered+Columns.swift` / `Dictionary.Ordered+Positions.swift`.
// No re-exports here — the namespace and column packages are ordinary
// dependencies ([MOD-005]: umbrellas re-export in-package targets only).
