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
import Hash_Table_Primitives_Test_Support
import Buffer_Primitives_Test_Support
import Hash_Primitives
import Shared_Primitive
import Column_Primitives
import Index_Primitives
import Tagged_Primitives_Standard_Library_Integration
import Ordinal_Primitives_Standard_Library_Integration
import Testing

// The W3 ordered-dictionary model suite (arc-2): the dictionary streams PLUS the
// positional doors — `index(forKey:)`, `key(at:)`, `withValue(at:)`, and
// `withMutableValue(at:)` are audited against the model rank for every entry,
// every op; the order CONTRACT (updates keep rank, removal shifts, reinsertion
// appends) is the lawful surface under test. Both columns; the Shared lane is
// the sibling fleet (refcounted censused values, end-of-scope multiset
// exactness). ASK-W3-A carve-out: the Shared `removeAll`
// (Dictionary.Ordered+Columns.swift:245) rebuilds the box through the
// strategy-less init — fleet wipes sweep the keyed door instead; the disabled
// regression below re-enables the real door with the ruled fix.
// Shape constraint: B10.

private typealias EntryColumn<K: Hash.Key & ~Copyable, V: ~Copyable> =
    Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>

private typealias MoveOrdered<K: Hash.Key & ~Copyable, V: ~Copyable> = Dictionary<EntryColumn<K, V>>.Ordered
private typealias CoWOrdered<K: Hash.Key, V> = Dictionary<Shared<Hash.Entry<K, V>, EntryColumn<K, V>>>.Ordered

// MARK: - Fixtures

private struct Key: Hash.`Protocol` {
    let id: Int
    let group: Int

    init(id: Int, group: Int) {
        self.id = id
        self.group = group
    }

    borrowing func hash(into hasher: inout Hasher) {
        hasher.combine(group)
    }

    static func == (lhs: borrowing Key, rhs: borrowing Key) -> Bool {
        lhs.id == rhs.id
    }
}

private final class Value {
    let id: Int
    let serial: Int
    private let census: Model.Census

    init(id: Int, census: Model.Census) {
        self.id = id
        self.census = census
        self.serial = census.mint()
    }

    deinit {
        census.record(death: serial)
    }
}

// MARK: - The reference model: insertion-ordered (key, value) pairs

private struct Reference {
    var entries: [(key: Int, group: Int, value: Int)] = []
    var keys: Swift.Set<Int> = []
    var graveyard: [(key: Int, group: Int)] = []

    mutating func append(key: Int, group: Int, value: Int) {
        entries.append((key, group, value))
        keys.insert(key)
    }

    mutating func setValue(_ value: Int, at position: Int) {
        entries[position].value = value
    }

    mutating func remove(at index: Int) {
        let entry = entries.remove(at: index)
        keys.remove(entry.key)
        retire((entry.key, entry.group))
    }

    private mutating func retire(_ key: (key: Int, group: Int)) {
        graveyard.append(key)
        if graveyard.count > 8 {
            graveyard.removeFirst(graveyard.count - 8)
        }
    }
}

// MARK: - The direct stream (move-only censused values + the positional doors)

private struct DirectStream: ~Copyable {
    var dictionary: MoveOrdered<Key, Model.Element.Tracked>
    var model = Reference()
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextKey = 0
    var nextValue = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.dictionary = MoveOrdered<Key, Model.Element.Tracked>(
            minimumCapacity: Index<Hash.Entry<Key, Model.Element.Tracked>>.Count(UInt(rng.below(17)))
        )
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextKey, group: nextKey / collisionDivisor)
        nextKey += 1
        return key
    }

    mutating func mintValueID() -> Int {
        let id = nextValue
        nextValue += 1
        return id
    }

    func position(_ rank: Int) -> Index<Hash.Entry<Key, Model.Element.Tracked>> {
        Index(Ordinal(UInt(rank)))
    }

    mutating func insertFresh() {
        let key = freshKey()
        let valueID = mintValueID()
        verdict.record("insert k=\(key.id) g=\(key.group) v=\(valueID)")
        if let displaced = dictionary.insert(key: key, value: Model.Element.Tracked(id: valueID, census: census)) {
            verdict.diverged(["fresh key \(key.id) displaced value id \(displaced.id)"])
        } else {
            model.append(key: key.id, group: key.group, value: valueID)
        }
    }

    mutating func upsert() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        let valueID = mintValueID()
        verdict.record("upsert k=\(entry.key) v=\(entry.value)→\(valueID)")
        if let displaced = dictionary.insert(key: Key(id: entry.key, group: entry.group), value: Model.Element.Tracked(id: valueID, census: census)) {
            if displaced.id != entry.value {
                verdict.diverged(["upsert displaced value id \(displaced.id), model \(entry.value)"])
            }
            model.setValue(valueID, at: index)
        } else {
            verdict.diverged(["upsert of live key \(entry.key) reported a fresh insertion"])
        }
    }

    mutating func removePresent() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        verdict.record("remove k=\(entry.key) @\(index)")
        if let removed = dictionary.removeValue(forKey: Key(id: entry.key, group: entry.group)) {
            if removed.id != entry.value {
                verdict.diverged(["removeValue returned value id \(removed.id), model \(entry.value)"])
            }
            model.remove(at: index)
        } else {
            verdict.diverged(["removeValue(k \(entry.key)) found nothing for a live key"])
        }
    }

    mutating func removeAbsent() {
        let key = freshKey()
        verdict.record("absent k=\(key.id)")
        if let removed = dictionary.removeValue(forKey: key) {
            verdict.diverged(["removeValue of never-inserted key \(key.id) returned value id \(removed.id)"])
        }
    }

    mutating func indexForKey() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        verdict.record("rank k=\(entry.key) @\(index)")
        let found = dictionary.index(forKey: Key(id: entry.key, group: entry.group))
        if found != position(index) {
            verdict.diverged(["index(forKey: \(entry.key)): \(String(describing: found)), model rank \(index)"])
        }
    }

    mutating func keyAt() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        verdict.record("key@\(index)")
        let key = dictionary.key(at: position(index))
        if key.id != entry.key {
            verdict.diverged(["key(at: \(index)): id \(key.id), model \(entry.key)"])
        }
    }

    mutating func readValueAt() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        verdict.record("read@\(index)")
        let value = dictionary.withValue(at: position(index)) { (value: borrowing Model.Element.Tracked) in
            value.id
        }
        if value != entry.value {
            verdict.diverged(["withValue(at: \(index)): \(value), model \(entry.value)"])
        }
    }

    /// The positional mutation door — rank stays, the displaced value dies.
    mutating func mutateValueAt() {
        let index = rng.below(model.entries.count)
        let entry = model.entries[index]
        let valueID = mintValueID()
        verdict.record("mutate@\(index) v=\(entry.value)→\(valueID)")
        let census = self.census
        let previous = dictionary.withMutableValue(at: position(index)) { (slot: inout Model.Element.Tracked) -> Int in
            let old = slot.id
            slot = Model.Element.Tracked(id: valueID, group: 0, census: census)
            return old
        }
        if previous != entry.value {
            verdict.diverged(["withMutableValue(at: \(index)) displaced \(previous), model \(entry.value)"])
        }
        model.setValue(valueID, at: index)
    }

    mutating func walkOrder() {
        verdict.record("walk \(model.entries.count)")
        var keys: [Int] = []
        var values: [Int] = []
        dictionary.forEach { (key: borrowing Key, value: borrowing Model.Element.Tracked) in
            keys.append(key.id)
            values.append(value.id)
        }
        if keys != model.entries.map({ $0.key }) || values != model.entries.map({ $0.value }) {
            verdict.diverged(["forEach walked \(keys)/\(values), model order broken"])
        }
    }

    mutating func wipe() {
        let keep = rng.chance(50)
        verdict.record("wipe keep=\(keep)")
        dictionary.removeAll(keepingCapacity: keep)
        model.entries.removeAll()
        model.keys.removeAll()
    }

    /// Order + every positional door, every audited op: rank round-trips
    /// (index(forKey:) == rank; key(at: rank) == key) across the whole model.
    func audit() -> [String] {
        var findings: [String] = []
        if dictionary.count != Index<Hash.Entry<Key, Model.Element.Tracked>>.Count(UInt(model.entries.count)) {
            findings.append("count: dictionary \(dictionary.count), model \(model.entries.count)")
        }
        for (offset, entry) in model.entries.enumerated() {
            let found = dictionary.index(forKey: Key(id: entry.key, group: entry.group))
            if found != position(offset) {
                findings.append("rank(k \(entry.key)): \(String(describing: found)), model \(offset)")
            }
            let key = dictionary.key(at: position(offset))
            if key.id != entry.key {
                findings.append("key(at: \(offset)): \(key.id), model \(entry.key)")
            }
            let value = dictionary.withValue(at: position(offset)) { (value: borrowing Model.Element.Tracked) in
                value.id
            }
            if value != entry.value {
                findings.append("value(at: \(offset)): \(value), model \(entry.value)")
            }
        }
        for retired in model.graveyard where !model.keys.contains(retired.key) {
            if dictionary.contains(key: Key(id: retired.key, group: retired.group)) {
                findings.append("retired key \(retired.key) is still reachable")
            }
        }
        return findings
    }

    mutating func step() {
        var branch = rng.below(100)
        if model.entries.isEmpty, branch >= 24, branch < 94 { branch = 0 }

        switch branch {
        case 0..<24: insertFresh()
        case 24..<36: upsert()
        case 36..<52: removePresent()
        case 52..<56: removeAbsent()
        case 56..<64: indexForKey()
        case 64..<70: keyAt()
        case 70..<78: readValueAt()
        case 78..<88: mutateValueAt()
        case 88..<94: walkOrder()
        default: wipe()
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }

    consuming func finish() -> Model.Verdict {
        verdict
    }
}

private func runDirectStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var stream = DirectStream(seed: seed, census: census)
    stream.run()
    var verdict = stream.finish()  // the dictionary dies here

    if !census.isExact {
        verdict.findings.append(
            "value teardown multiset broken: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The Shared (CoW) sibling fleet

private struct FleetStream {
    var siblings: [CoWOrdered<Key, Value>]
    var models: [Reference]
    var rng: Model.Random
    var verdict: Model.Verdict
    var nextKey = 0
    var nextValue = 0
    let collisionDivisor = 4
    let census: Model.Census

    init(seed: UInt64, census: Model.Census) {
        var rng = Model.Random(seed: seed)
        self.siblings = [CoWOrdered<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(UInt(rng.below(9)))
        )]
        self.models = [Reference()]
        self.rng = rng
        self.verdict = Model.Verdict(seed: seed)
        self.census = census
    }

    mutating func freshKey() -> Key {
        let key = Key(id: nextKey, group: nextKey / collisionDivisor)
        nextKey += 1
        return key
    }

    mutating func freshValue() -> Value {
        let value = Value(id: nextValue, census: census)
        nextValue += 1
        return value
    }

    func position(_ rank: Int) -> Index<Hash.Entry<Key, Value>> {
        Index(Ordinal(UInt(rank)))
    }

    mutating func fork() {
        let source = rng.below(siblings.count)
        verdict.record("fork ←\(source) (\(siblings.count + 1) siblings)")
        siblings.append(siblings[source])
        models.append(models[source])
    }

    mutating func drop() {
        let target = rng.below(siblings.count)
        verdict.record("drop \(target)")
        siblings.remove(at: target)
        models.remove(at: target)
    }

    mutating func insertFresh(into target: Int) {
        let key = freshKey()
        let value = freshValue()
        verdict.record("insert[\(target)] k=\(key.id) v=\(value.id)")
        if let displaced = siblings[target].insert(key: key, value: value) {
            verdict.diverged(["fresh key \(key.id) displaced value id \(displaced.id) on sibling \(target)"])
        } else {
            models[target].append(key: key.id, group: key.group, value: value.id)
        }
    }

    mutating func upsert(on target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        let value = freshValue()
        verdict.record("upsert[\(target)] k=\(entry.key) v=\(entry.value)→\(value.id)")
        if let displaced = siblings[target].insert(key: Key(id: entry.key, group: entry.group), value: value) {
            if displaced.id != entry.value {
                verdict.diverged(["upsert displaced value id \(displaced.id), model \(entry.value)"])
            }
            models[target].setValue(value.id, at: index)
        } else {
            verdict.diverged(["upsert of live key \(entry.key) reported fresh on sibling \(target)"])
        }
    }

    mutating func removePresent(from target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        verdict.record("remove[\(target)] k=\(entry.key)")
        if let removed = siblings[target].removeValue(forKey: Key(id: entry.key, group: entry.group)) {
            if removed.id != entry.value {
                verdict.diverged(["removeValue returned value id \(removed.id), model \(entry.value)"])
            }
            models[target].remove(at: index)
        } else {
            verdict.diverged(["removeValue(k \(entry.key)) found nothing on sibling \(target)"])
        }
    }

    mutating func positionalReads(on target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        verdict.record("entry[\(target)]@\(index)")
        let pair = siblings[target].entry(at: position(index))
        if pair.key.id != entry.key || pair.value.id != entry.value {
            verdict.diverged(["entry(at: \(index)) on sibling \(target): (\(pair.key.id), \(pair.value.id)), model (\(entry.key), \(entry.value))"])
        }
        let value = siblings[target].value(at: position(index))
        if value.id != entry.value {
            verdict.diverged(["value(at: \(index)) on sibling \(target): \(value.id), model \(entry.value)"])
        }
    }

    mutating func mutateValueAt(on target: Int) {
        let index = rng.below(models[target].entries.count)
        let entry = models[target].entries[index]
        let value = freshValue()
        verdict.record("mutate[\(target)]@\(index) v=\(entry.value)→\(value.id)")
        let previous = siblings[target].withMutableValue(at: position(index)) { (slot: inout Value) -> Int in
            let old = slot.id
            slot = value
            return old
        }
        if previous != entry.value {
            verdict.diverged(["withMutableValue(at: \(index)) displaced \(previous), model \(entry.value)"])
        }
        models[target].setValue(value.id, at: index)
    }

    mutating func walkOrder(on target: Int) {
        verdict.record("walk[\(target)] \(models[target].entries.count)")
        var keys: [Int] = []
        var values: [Int] = []
        siblings[target].forEach { (key: borrowing Key, value: borrowing Value) in
            keys.append(key.id)
            values.append(value.id)
        }
        if keys != models[target].entries.map({ $0.key }) || values != models[target].entries.map({ $0.value }) {
            verdict.diverged(["sibling \(target) walked \(keys)/\(values), model order broken"])
        }
    }

    // ASK-W3-A carve-out: the Shared `removeAll` rebuilds the box through the
    // strategy-less init (Dictionary.Ordered+Columns.swift:245) — wipe → fork →
    // mutate traps. Mass removal sweeps the keyed door until the ruled fix lands.
    mutating func wipe(_ target: Int) {
        verdict.record("sweep[\(target)] \(models[target].entries.count)")
        while let entry = models[target].entries.last {
            if let removed = siblings[target].removeValue(forKey: Key(id: entry.key, group: entry.group)) {
                if removed.id != entry.value {
                    verdict.diverged(["sweep removeValue returned id \(removed.id), model \(entry.value)"])
                }
                models[target].remove(at: models[target].entries.count - 1)
            } else {
                verdict.diverged(["sweep removeValue(k \(entry.key)) missed a live key on sibling \(target)"])
                return
            }
        }
    }

    func audit() -> [String] {
        var findings: [String] = []
        for (index, model) in models.enumerated() {
            if siblings[index].count != Index<Hash.Entry<Key, Value>>.Count(UInt(model.entries.count)) {
                findings.append("sibling \(index) count \(siblings[index].count), model \(model.entries.count)")
            }
            for (offset, entry) in model.entries.enumerated() {
                let found = siblings[index].index(forKey: Key(id: entry.key, group: entry.group))
                if found != position(offset) {
                    findings.append("sibling \(index) rank(k \(entry.key)): \(String(describing: found)), model \(offset)")
                }
            }
            var keys: [Int] = []
            var values: [Int] = []
            siblings[index].forEach { (key: borrowing Key, value: borrowing Value) in
                keys.append(key.id)
                values.append(value.id)
            }
            if keys != model.entries.map({ $0.key }) || values != model.entries.map({ $0.value }) {
                findings.append("sibling \(index): \(keys)/\(values) diverged from its fork")
            }
        }
        return findings
    }

    mutating func step() {
        let target = rng.below(siblings.count)
        var branch = rng.below(100)
        if models[target].entries.isEmpty, branch >= 16, branch < 94 { branch = 10 }

        switch branch {
        case 0..<10 where siblings.count < 4: fork()
        case 0..<10: insertFresh(into: target)
        case 10..<16: insertFresh(into: target)
        case 16..<24 where siblings.count > 1: drop()
        case 16..<24: insertFresh(into: target)
        case 24..<36: upsert(on: target)
        case 36..<52: removePresent(from: target)
        case 52..<64: positionalReads(on: target)
        case 64..<78: mutateValueAt(on: target)
        case 78..<94: walkOrder(on: target)
        default: wipe(target)
        }
    }

    mutating func run() {
        let operations = Model.operations(default: 800)
        var op = 0
        while op < operations, verdict.isClean {
            step()
            if Model.shouldAudit(op: op, of: operations) {
                verdict.diverged(audit())
            }
            op += 1
        }
    }
}

private func runFleetStream(seed: UInt64) -> Model.Verdict {
    let census = Model.Census()
    var verdict: Model.Verdict
    do {
        var stream = FleetStream(seed: seed, census: census)
        stream.run()
        verdict = stream.verdict
    }  // every sibling dies here; value refcounts fall to zero

    if !census.isExact {
        verdict.findings.append(
            "value teardown multiset broken across the fleet: \(census.born.count) born vs \(census.died.count) died"
        )
    }
    return verdict
}

// MARK: - The suites

@Suite
struct `Dictionary.Ordered Model` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
}

extension `Dictionary.Ordered Model`.Integration {
    @Test(arguments: Model.seeds(default: [0x02D1_C701, 0x02D1_C702]))
    func `direct stream: keyed and positional doors match the ordered reference`(seed: UInt64) {
        let verdict = runDirectStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }

    @Test(arguments: Model.seeds(default: [0x02D1_F1E1, 0x02D1_F1E2, 0x02D1_F1E3]))
    func `shared sibling fleet: ranks and doors hold per fork; refcounts end exact`(seed: UInt64) {
        let verdict = runFleetStream(seed: seed)
        #expect(verdict.isClean, Comment(rawValue: verdict.report))
    }
}

extension `Dictionary.Ordered Model`.Unit {
    @Test
    func `the order contract: update keeps rank, removal shifts, reinsertion appends`() {
        let census = Model.Census()
        var dictionary = CoWOrdered<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(8)
        )
        for id in 0..<5 {
            dictionary.insert(key: Key(id: id, group: id / 2), value: Value(id: 100 + id, census: census))
        }
        dictionary.insert(key: Key(id: 2, group: 1), value: Value(id: 999, census: census))  // update keeps rank
        let rankTwo = dictionary.index(forKey: Key(id: 2, group: 1))
        #expect(rankTwo == Index(Ordinal(UInt(2))))
        _ = dictionary.removeValue(forKey: Key(id: 1, group: 0))  // removal shifts
        let rankTwoShifted = dictionary.index(forKey: Key(id: 2, group: 1))
        #expect(rankTwoShifted == Index(Ordinal(UInt(1))))
        dictionary.insert(key: Key(id: 1, group: 0), value: Value(id: 555, census: census))  // reinsertion appends
        let rankOneAppended = dictionary.index(forKey: Key(id: 1, group: 0))
        #expect(rankOneAppended == Index(Ordinal(UInt(4))))
    }
}

extension `Dictionary.Ordered Model`.`Edge Case` {
    @Test(.disabled("""
    ASK-W3-A (REPORT-arc-model-tests-W3): the Shared removeAll rebuilds the box \
    through the strategy-less init (Dictionary.Ordered+Columns.swift:245) — \
    fork-after-wipe then mutate traps at Shared+Unique.swift:77. Re-enable with \
    the ruled fix.
    """))
    func `forking after removeAll keeps both siblings independently mutable`() {
        let census = Model.Census()
        var first = CoWOrdered<Key, Value>(
            minimumCapacity: Index<Hash.Entry<Key, Value>>.Count(4)
        )
        first.insert(key: Key(id: 1, group: 0), value: Value(id: 10, census: census))
        first.removeAll()
        var second = first
        second.insert(key: Key(id: 2, group: 0), value: Value(id: 20, census: census))  // traps pre-fix
        first.insert(key: Key(id: 3, group: 0), value: Value(id: 30, census: census))
        let secondHasTheirs = second.contains(key: Key(id: 2, group: 0))
        let firstHasTheirs = first.contains(key: Key(id: 3, group: 0))
        let crossLeak = first.contains(key: Key(id: 2, group: 0))
        #expect(secondHasTheirs)
        #expect(firstHasTheirs)
        #expect(!crossLeak)
    }
}
