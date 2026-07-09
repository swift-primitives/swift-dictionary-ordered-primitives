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

import Buffer_Primitives_Test_Support
import Column_Primitives
import Dictionary_Ordered_Primitives
import Dictionary_Primitive
import Hash_Indexed_Primitive
import Hash_Primitives
import Hash_Primitives_Standard_Library_Integration
import Hash_Table_Primitives_Test_Support
import Index_Primitives
import Ordinal_Primitives_Standard_Library_Integration
import Ownership_Shared_Primitive
import Tagged_Primitives_Standard_Library_Integration
import Testing

// The ordered-dictionary suite: the same ordered hashed entry column as the base
// `Dictionary<S>`, with the ORDER CONTRACT under test — positions are
// insertion-order ranks; updates keep rank; removal shifts; reinsertion appends.

private typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>

private typealias MoveOrdered<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<K, V>.Ordered
private typealias CoWOrdered<K: Hash.Key, V> = __DictionaryOrdered<Ownership.Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>

/// The position at insertion-order rank `n` (runtime construction; the ordered
/// index domain is entry-tagged).
private func rank(_ n: UInt) -> Index<Hash.Entry<Int, Int>> {
    Index(Ordinal(n))
}

// MARK: - [DS-024] + coherence (the Shared entry composite is this family's column)

@Suite
struct `Ordered Column Law Tests` {

    @Test
    func `the shared entry column obeys the seam ledger laws`() {
        let violations = Seam.Ledger.violations(
            makeEmpty: { Ownership.Shared(EntryColumn<Int, Int>(minimumCapacity: Index<Hash.Entry<Int, Int>>.Count(4))) },
            element: { Hash.Entry(key: $0, value: $0) }
        )
        #expect(violations.isEmpty, "\(violations)")
    }

    @Test
    func `coherence holds through the ordered surface`() {
        var direct = MoveOrdered<Int, Int>(minimumCapacity: 4)
        var i = 0
        while i < 16 {
            direct.insert(key: i &* 3, value: i)
            i += 1
        }
        _ = direct.removeValue(forKey: 9)
        _ = direct.removeValue(forKey: 0)
        direct.insert(key: 6, value: 99)  // replacement: value swaps behind a stable key
        direct.withMutableValue(at: rank(0)) { $0 &+= 1 }  // positional value mutation: no re-index
        let violations = direct.take().checkCoherence()
        #expect(violations.isEmpty, "\(violations)")
    }
}

extension Hash.Indexed<Column.Heap<Hash.Entry<Int, Int>>> {
    fileprivate borrowing func checkCoherence() -> [String] {
        Hash.Coherence.violations(self)
    }
}

// MARK: - Core keyed ops (the direct column)

@Suite(.serialized)
struct `Ordered Core Tests` {

    @Test
    func `insert, displaced hand-back, contains, removeValue, counts`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        let isEmpty = d.isEmpty
        #expect(isEmpty)
        let fresh = d.insert(key: 10, value: 100)
        #expect(fresh == nil)
        let displaced = d.insert(key: 10, value: 101)
        #expect(displaced == 100)
        d.insert(key: 20, value: 200)
        d.insert(key: 30, value: 300)
        let has = d.contains(key: 20)
        let hasNot = d.contains(key: 40)
        #expect(has)
        #expect(!hasNot)
        let removed = d.removeValue(forKey: 20)
        #expect(removed == 200)
        let absent = d.removeValue(forKey: 20)
        #expect(absent == nil)
        let n = d.count
        #expect(n == Index<Hash.Entry<Int, Int>>.Count(2))
    }

    @Test
    func `withValue reads; withMutableValue mutates in place behind the stable key`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 1, value: 10)
        let read = d.withValue(forKey: 1) { $0 }
        #expect(read == 10)
        let missing = d.withValue(forKey: 2) { $0 }
        #expect(missing == nil)
        let old = d.withMutableValue(forKey: 1) { value -> Int in
            let was = value
            value += 5
            return was
        }
        #expect(old == 10)
        let now = d.withValue(forKey: 1) { $0 }
        #expect(now == 15)
        let absent: Void? = d.withMutableValue(forKey: 9) { $0 += 1 }
        #expect(absent == nil)
    }

    @Test
    func `iteration is insertion-ordered across growth, removal, and replacement`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 2)
        var i = 0
        while i < 12 {
            d.insert(key: i, value: i &* 10)
            i += 1
        }
        _ = d.removeValue(forKey: 5)
        d.insert(key: 3, value: 999)  // replacement keeps the slot's order
        var keys: [Int] = []
        d.forEach { key, _ in keys.append(key) }
        #expect(keys == [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11])
        let replaced = d.withValue(forKey: 3) { $0 }
        #expect(replaced == 999)
    }

    @Test
    func `removeAll empties; reuse works; direct clone detaches`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 1, value: 10)
        d.insert(key: 2, value: 20)
        var c = d.clone()
        _ = c.removeValue(forKey: 1)
        let mineHas = d.contains(key: 1)
        let theirsHas = c.contains(key: 1)
        #expect(mineHas)
        #expect(!theirsHas)
        d.removeAll()
        let isEmpty = d.isEmpty
        #expect(isEmpty)
        d.insert(key: 7, value: 70)
        let v7 = d.withValue(forKey: 7) { $0 }
        #expect(v7 == 70)
    }
}

// MARK: - The order contract (positions are insertion-order ranks)

@Suite(.serialized)
struct `Ordered Position Tests` {

    @Test
    func `index(forKey:) is the rank; misses are nil`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 10, value: 1)
        d.insert(key: 20, value: 2)
        d.insert(key: 30, value: 3)
        #expect(d.index(forKey: 10) == rank(0))
        #expect(d.index(forKey: 20) == rank(1))
        #expect(d.index(forKey: 30) == rank(2))
        #expect(d.index(forKey: 40) == nil)
        let zero: Dictionary<Int, Int>.Ordered.Index = .zero
        #expect(d.index(forKey: 10) == zero)  // the ordered index domain typealias
    }

    @Test
    func `updates keep rank; removal shifts later ranks down; reinsertion appends`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 10, value: 1)
        d.insert(key: 20, value: 2)
        d.insert(key: 30, value: 3)
        d.insert(key: 20, value: 22)  // update: rank 1 stays
        #expect(d.index(forKey: 20) == rank(1))
        _ = d.removeValue(forKey: 10)  // ranks after the removal point shift
        #expect(d.index(forKey: 20) == rank(0))
        #expect(d.index(forKey: 30) == rank(1))
        d.insert(key: 10, value: 111)  // reinsertion goes to the end
        #expect(d.index(forKey: 10) == rank(2))
        var keys: [Int] = []
        d.forEach { key, _ in keys.append(key) }
        #expect(keys == [20, 30, 10])
    }

    @Test
    func `key(at:), value(at:), entry(at:) read the rank; withValue(at:) borrows`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 7, value: 70)
        d.insert(key: 8, value: 80)
        let k0 = d.key(at: rank(0))
        #expect(k0 == 7)
        let v1 = d.value(at: rank(1))
        #expect(v1 == 80)
        let e = d.entry(at: rank(0))
        #expect(e.key == 7)
        #expect(e.value == 70)
        let borrowed = d.withValue(at: rank(1)) { $0 }
        #expect(borrowed == 80)
    }

    @Test
    func `withMutableValue(at:) mutates the value; the key keeps its rank`() {
        var d = MoveOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 7, value: 70)
        d.insert(key: 8, value: 80)
        let was = d.withMutableValue(at: rank(0)) { value -> Int in
            let old = value
            value += 1
            return old
        }
        #expect(was == 70)
        let now = d.value(at: rank(0))
        #expect(now == 71)
        #expect(d.index(forKey: 7) == rank(0))  // hash-stable: rank survived
        let k = d.key(at: rank(0))
        #expect(k == 7)
    }

    @Test
    func `the positional doors agree on the shared column`() {
        var d = CoWOrdered<Int, Int>(minimumCapacity: 4)
        d.insert(key: 10, value: 1)
        d.insert(key: 20, value: 2)
        d.insert(key: 30, value: 3)
        _ = d.removeValue(forKey: 20)
        #expect(d.index(forKey: 30) == rank(1))
        let k1 = d.key(at: rank(1))
        #expect(k1 == 30)
        let v0 = d.value(at: rank(0))
        #expect(v0 == 1)
        let e = d.entry(at: rank(1))
        #expect(e.key == 30)
        #expect(e.value == 3)
        let borrowed = d.withValue(at: rank(0)) { $0 }
        #expect(borrowed == 1)
        var keys: [Int] = []
        d.forEach { key, _ in keys.append(key) }
        #expect(keys == [10, 30])
    }
}

// MARK: - CoW value semantics (the Shared composite column)

@Suite(.serialized)
struct `Ordered CoW Tests` {

    @Test
    func `copies share until mutation; inserts detach through the box`() {
        var a = CoWOrdered<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        let b = a  // S5: Ordered is Copyable because S is
        a.insert(key: 2, value: 20)  // withUnique(consuming:) detaches first
        let mine = a.count
        let theirs = b.count
        #expect(mine == Index<Hash.Entry<Int, Int>>.Count(2))
        #expect(theirs == Index<Hash.Entry<Int, Int>>.Count(1))
        let aHas2 = a.contains(key: 2)
        let bHas2 = b.contains(key: 2)
        #expect(aHas2)
        #expect(!bHas2)
    }

    @Test
    func `positional value mutation detaches; the sibling keeps its value and order`() {
        var a = CoWOrdered<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        a.insert(key: 2, value: 20)
        let b = a
        a.withMutableValue(at: rank(0)) { $0 = 11 }
        let mine = a.value(at: rank(0))
        let theirs = b.value(at: rank(0))
        #expect(mine == 11)
        #expect(theirs == 10)
        let keyed = a.withMutableValue(forKey: 2) { value -> Int in
            value = 22
            return value
        }
        #expect(keyed == 22)
        let bKept = b.withValue(forKey: 2) { $0 }
        #expect(bKept == 20)
    }

    @Test
    func `removal detaches; the sibling keeps the entry; generic clone detaches`() {
        var a = CoWOrdered<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        a.insert(key: 2, value: 20)
        let b = a
        let removed = a.removeValue(forKey: 1)
        #expect(removed == 10)
        let bStillHas = b.contains(key: 1)
        #expect(bStillHas)
        #expect(b.index(forKey: 2) == rank(1))  // the sibling's order is untouched
        #expect(a.index(forKey: 2) == rank(0))

        var c = a.clone()
        c.insert(key: 9, value: 90)
        let aHas9 = a.contains(key: 9)
        let cHas9 = c.contains(key: 9)
        #expect(!aHas9)
        #expect(cHas9)
    }

    @Test
    func `removeAll detaches to a fresh box; the sibling is untouched`() {
        var a = CoWOrdered<Int, Int>(minimumCapacity: 4)
        a.insert(key: 1, value: 10)
        let b = a
        a.removeAll()
        let aEmpty = a.isEmpty
        let bHas = b.contains(key: 1)
        #expect(aEmpty)
        #expect(bHas)
    }

    @Test
    func `set and the keyed subscript read, replace, and remove; the subscript setter detaches`() {
        var a = CoWOrdered<Int, Int>(minimumCapacity: 4)
        a.set(1, 10)  // set inserts a fresh key
        a.set(2, 20)
        a[1] = 11  // subscript setter replaces in place
        let read1 = a[1]  // subscript getter
        let readMissing = a[9]
        #expect(read1 == 11)
        #expect(readMissing == nil)
        #expect(a.index(forKey: 1) == rank(0))  // replacement kept the rank

        let b = a  // S5: Ordered is Copyable because S is
        a[1] = nil  // assigning nil removes; detaches the box
        let goneFromA = a[1]
        let keptInB = b[1]
        #expect(goneFromA == nil)
        #expect(keptInB == 11)  // the sibling keeps its entry
        #expect(a.count == Index<Hash.Entry<Int, Int>>.Count(1))
    }
}

// MARK: - Move-only values + teardown

@Suite(.serialized)
struct `Ordered Teardown Tests` {

    @Test
    func `move-only values flow through and tear down exactly once`() {
        OrderedProbe.reset()
        do {
            var d = MoveOrdered<Int, OrderedItem>(minimumCapacity: 4)
            d.insert(key: 1, value: OrderedItem(10))
            d.insert(key: 2, value: OrderedItem(20))
            if let displaced: OrderedItem = d.insert(key: 1, value: OrderedItem(11)) {
                let id = displaced.id
                #expect(id == 10)  // the displaced OLD value hands back
            } else {
                Issue.record("expected the displaced value")
            }
            let peeked = d.withValue(at: Index(Ordinal(0))) { (item: borrowing OrderedItem) in item.id }
            #expect(peeked == 11)  // positional borrow is not a teardown
            if let removed: OrderedItem = d.removeValue(forKey: 2) {
                let id = removed.id
                #expect(id == 20)
            } else {
                Issue.record("expected the removed value")
            }
        }
        let all = OrderedProbe.destroyedSorted
        #expect(all == [10, 11, 20])  // displaced + live-at-teardown + removed
    }

    @Test
    func `the boxed move-only lane tears down via the box drain`() {
        OrderedProbe2.reset()
        do {
            var d = __DictionaryOrdered<Ownership.Shared<Hash.Entry<Int, OrderedItem2>, EntryColumn<Int, OrderedItem2>>>(minimumCapacity: 4)
            d.insert(key: 7, value: OrderedItem2(70))
            d.insert(key: 8, value: OrderedItem2(80))
            let n = d.count
            #expect(n == Index<Hash.Entry<Int, OrderedItem2>>.Count(2))
        }
        let all = OrderedProbe2.destroyedSorted
        #expect(all == [70, 80])
    }
}

private struct OrderedItem: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { OrderedProbe.recordDestroy(id) }
}

private enum OrderedProbe {
    nonisolated(unsafe) static var _destroyed: [Int] = []
}

extension OrderedProbe {
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

private struct OrderedItem2: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
    deinit { OrderedProbe2.recordDestroy(id) }
}

private enum OrderedProbe2 {
    nonisolated(unsafe) static var _destroyed: [Int] = []
}

extension OrderedProbe2 {
    static func reset() { unsafe _destroyed = [] }
    static func recordDestroy(_ id: Int) { unsafe _destroyed.append(id) }
    static var destroyedSorted: [Int] { unsafe _destroyed.sorted() }
}

// MARK: - Sendable smoke

@Suite
struct `Ordered Sendable Tests` {

    @Test
    func `sendable composes through both columns`() {
        let a = MoveOrdered<Int, Int>(minimumCapacity: 1)
        requireSendable(a)
        let b = CoWOrdered<Int, Int>(minimumCapacity: 1)
        requireSendable(b)
        #expect(Bool(true))
    }
}

private func requireSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {}
