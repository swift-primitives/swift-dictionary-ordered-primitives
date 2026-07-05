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

import Dictionary_Ordered_Primitives
import Dictionary_Primitive
import Column_Primitives
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Hash_Indexed_Primitive
import Buffer_Primitive
import Buffer_Linear_Primitive
import Storage_Contiguous_Primitives
import Memory_Heap_Primitives
import Memory_Allocator_Primitive
import Ownership_Shared_Primitive
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Cardinal_Primitives

// The ratified columns, spelled as the package's own test suite spells them.

typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>

typealias MoveOrdered<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<EntryColumn<K, V>>.Ordered

typealias CoWOrdered<K: Hash.Key, V> = Dictionary<Ownership.Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>.Ordered

extension Bench {
    /// The order-preserving remove curve uses denser scales (see set-ordered).
    static let curveSizes: [Int] = [16, 256, 4_096, 65_536]

    /// Typed count from a runtime size via the non-throwing `UInt` lane.
    static func count<E>(_ n: Int) -> Index_Primitives.Index<E>.Count {
        Index_Primitives.Index<E>.Count(Cardinal(UInt(n)))
    }

    /// Shapes per the inventory (vs `Swift.Dictionary`, the unordered
    /// baseline), mirroring the set-ordered matrix at entry granularity:
    /// `insert.zero` build · `lookup.hit`/`lookup.miss` via `withValue(forKey:)`
    /// vs stdlib subscript · `frontEvict.steady`/`backEvict.steady` (one op =
    /// one removeValue+insert pair; front pays the order-preserving shift) ·
    /// `iterate.sum` over values in insertion order vs stdlib's bucket scan.
    static func dictionaryOrderedCases() -> [Result] {
        var results: [Result] = []

        for n in sizes {
            let reps = Swift.max(1, structureOpsTarget / n)
            let buildOps = reps * n
            let seed = opaque(0)

            results.append(Result(
                name: "insert.zero", subject: "tower.direct", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = MoveOrdered<Int, Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = d.insert(key: i &+ seed, value: i) }
                        acc &+= d.withValue(forKey: seed) { $0 } ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "tower.cow", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = CoWOrdered<Int, Int>(minimumCapacity: .zero)
                        for i in 0..<n { _ = d.insert(key: i &+ seed, value: i) }
                        acc &+= d.withValue(forKey: seed) { $0 } ?? 0
                    }
                    sink(acc)
                }
            ))

            results.append(Result(
                name: "insert.zero", subject: "stdlib", n: n, opsPerBatch: buildOps,
                perOpNs: sample(opsPerBatch: buildOps) {
                    var acc = 0
                    for _ in 0..<reps {
                        var d = Swift.Dictionary<Int, Int>()
                        for i in 0..<n { d[i &+ seed] = i }
                        acc &+= d[seed] ?? 0
                    }
                    sink(acc)
                }
            ))

            // Lookup setup: keys 0..<n → value = key; hits 0..<n, misses n..<2n.
            let passes = Swift.max(1, (elementOpsTarget / 4) / n)
            let lookupOps = passes * n

            var d = MoveOrdered<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = d.insert(key: i, value: i) }
            var c = CoWOrdered<Int, Int>(minimumCapacity: count(n))
            for i in 0..<n { _ = c.insert(key: i, value: i) }
            var sd = Swift.Dictionary<Int, Int>(minimumCapacity: n)
            for i in 0..<n { sd[i] = i }

            for (label, lo) in [("lookup.hit", 0), ("lookup.miss", n)] {
                results.append(Result(
                    name: label, subject: "tower.direct", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= d.withValue(forKey: k) { $0 } ?? 0 }
                        }
                        sink(sum)
                    }
                ))

                results.append(Result(
                    name: label, subject: "tower.cow", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= c.withValue(forKey: k) { $0 } ?? 0 }
                        }
                        sink(sum)
                    }
                ))

                results.append(Result(
                    name: label, subject: "stdlib", n: n, opsPerBatch: lookupOps,
                    perOpNs: sample(opsPerBatch: lookupOps) {
                        var sum = 0
                        for _ in 0..<passes {
                            for k in lo..<(lo + n) { sum &+= sd[k] ?? 0 }
                        }
                        sink(sum)
                    }
                ))
            }

            let iterOps = passes * n

            results.append(Result(
                name: "iterate.sum", subject: "tower.direct", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        d.forEach { _, value in sum &+= value }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "tower.cow", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        c.forEach { _, value in sum &+= value }
                    }
                    sink(sum)
                }
            ))

            results.append(Result(
                name: "iterate.sum", subject: "stdlib", n: n, opsPerBatch: iterOps,
                perOpNs: sample(opsPerBatch: iterOps) {
                    var sum = 0
                    for _ in 0..<passes {
                        for (_, value) in sd { sum &+= value }
                    }
                    sink(sum)
                }
            ))
        }

        // The evict curves (one op = one removeValue+insert pair; rolling key
        // window keeps occupancy n — see the set-ordered twin for the scheme).
        for n in curveSizes {
            let frontPairs = Swift.max(16, copiedSlotsTarget / n)
            let backPairs = 1 << 15

            do {
                var d = MoveOrdered<Int, Int>(minimumCapacity: count(n))
                for i in 0..<n { _ = d.insert(key: i, value: i) }
                var low = 0
                var high = n

                results.append(Result(
                    name: "frontEvict.steady", subject: "tower.direct", n: n, opsPerBatch: frontPairs,
                    perOpNs: sample(opsPerBatch: frontPairs) {
                        var acc = 0
                        for _ in 0..<frontPairs {
                            acc &+= d.removeValue(forKey: low) ?? 0
                            _ = d.insert(key: high, value: high)
                            low &+= 1
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))

                results.append(Result(
                    name: "backEvict.steady", subject: "tower.direct", n: n, opsPerBatch: backPairs,
                    perOpNs: sample(opsPerBatch: backPairs) {
                        var acc = 0
                        for _ in 0..<backPairs {
                            acc &+= d.removeValue(forKey: high - 1) ?? 0
                            _ = d.insert(key: high, value: high)
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))
            }

            do {
                var c = CoWOrdered<Int, Int>(minimumCapacity: count(n))
                for i in 0..<n { _ = c.insert(key: i, value: i) }
                var low = 0
                var high = n

                results.append(Result(
                    name: "frontEvict.steady", subject: "tower.cow", n: n, opsPerBatch: frontPairs,
                    perOpNs: sample(opsPerBatch: frontPairs) {
                        var acc = 0
                        for _ in 0..<frontPairs {
                            acc &+= c.removeValue(forKey: low) ?? 0
                            _ = c.insert(key: high, value: high)
                            low &+= 1
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))

                results.append(Result(
                    name: "backEvict.steady", subject: "tower.cow", n: n, opsPerBatch: backPairs,
                    perOpNs: sample(opsPerBatch: backPairs) {
                        var acc = 0
                        for _ in 0..<backPairs {
                            acc &+= c.removeValue(forKey: high - 1) ?? 0
                            _ = c.insert(key: high, value: high)
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))
            }

            do {
                var sd = Swift.Dictionary<Int, Int>(minimumCapacity: n)
                for i in 0..<n { sd[i] = i }
                var low = 0
                var high = n

                results.append(Result(
                    name: "frontEvict.steady", subject: "stdlib", n: n, opsPerBatch: backPairs,
                    perOpNs: sample(opsPerBatch: backPairs) {
                        var acc = 0
                        for _ in 0..<backPairs {
                            acc &+= sd.removeValue(forKey: low) ?? 0
                            sd[high] = high
                            low &+= 1
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))

                results.append(Result(
                    name: "backEvict.steady", subject: "stdlib", n: n, opsPerBatch: backPairs,
                    perOpNs: sample(opsPerBatch: backPairs) {
                        var acc = 0
                        for _ in 0..<backPairs {
                            acc &+= sd.removeValue(forKey: high - 1) ?? 0
                            sd[high] = high
                            high &+= 1
                        }
                        sink(acc)
                    }
                ))
            }
        }

        return results
    }
}
