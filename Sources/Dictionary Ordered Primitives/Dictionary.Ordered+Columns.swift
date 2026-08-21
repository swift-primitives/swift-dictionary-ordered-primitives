public import Buffer_Linear_Primitive
public import Buffer_Primitive
public import Column_Primitives
public import Dictionary_Ordered_Primitive
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
import Hash_Primitives
public import Index_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives
public import Storage_Primitive

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    @discardableResult
    public mutating func insert<K: Hash.Key & ~Copyable, V: ~Copyable>(
        key: consuming K,
        value: consuming V
    ) -> V?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        if let slot = store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                candidate.key == probe
            }
        ) {
            var displaced = consume value
            swap(&store[slot].value, &displaced)
            return displaced
        }
        _ = store.insert(Hash.Entry(key: key, value: value))
        return nil
    }

    @inlinable
    @discardableResult
    public mutating func insert<K: Hash.Key & ~Copyable, V: ~Copyable>(
        key: consuming K,
        value: consuming V
    ) -> V?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withUnique(consuming: Hash.Entry(key: key, value: value)) { column, entry in
            if let slot = column.position(
                matching: entry.hashValue,
                context: entry,
                equals: {
                    (candidate: borrowing Hash.Entry<K, V>, probe: borrowing Hash.Entry<K, V>) in
                    candidate == probe
                }
            ) {

                var displaced = consume entry
                swap(&column[slot].value, &displaced.value)
                return displaced.take()
            }
            _ = column.insert(entry)
            return nil
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public func contains<K: Hash.Key & ~Copyable, V: ~Copyable>(key: borrowing K) -> Bool
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                candidate.key == probe
            }
        ) != nil
    }

    @inlinable
    public func contains<K: Hash.Key & ~Copyable, V: ~Copyable>(key: borrowing K) -> Bool
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                    candidate.key == probe
                }
            ) != nil
        }
    }

    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        forKey key: borrowing K,
        _ body: (borrowing V) -> R
    ) -> R?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        guard
            let slot = store.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                    candidate.key == probe
                }
            )
        else {
            return nil
        }
        return body(store[slot].value)
    }

    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        forKey key: borrowing K,
        _ body: (borrowing V) -> R
    ) -> R?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column -> R? in
            guard
                let slot = column.position(
                    matching: key.hashValue,
                    context: key,
                    equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                        candidate.key == probe
                    }
                )
            else {
                return nil
            }
            return body(column[slot].value)
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        forKey key: borrowing K,
        _ body: (inout V) -> R
    ) -> R?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        guard
            let slot = store.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                    candidate.key == probe
                }
            )
        else {
            return nil
        }
        return body(&store[slot].value)
    }

    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        forKey key: borrowing K,
        _ body: (inout V) -> R
    ) -> R?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withUnique { column -> R? in
            guard
                let slot = column.position(
                    matching: key.hashValue,
                    context: key,
                    equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                        candidate.key == probe
                    }
                )
            else {
                return nil
            }
            return body(&column[slot].value)
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public mutating func removeValue<K: Hash.Key & ~Copyable, V: ~Copyable>(
        forKey key: borrowing K
    ) -> V?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        guard
            let entry = store.remove(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                    candidate.key == probe
                }
            )
        else {
            return nil
        }
        return entry.take()
    }

    @inlinable
    public mutating func removeValue<K: Hash.Key & ~Copyable, V: ~Copyable>(
        forKey key: borrowing K
    ) -> V?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withUnique { column -> V? in
            guard
                let entry = column.remove(
                    matching: key.hashValue,
                    context: key,
                    equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                        candidate.key == probe
                    }
                )
            else {
                return nil
            }
            return entry.take()
        }
    }

    @inlinable
    public mutating func removeAll<K: Hash.Key & ~Copyable, V: ~Copyable>(
        keepingCapacity: Bool = true
    )
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        store.removeAll(keepingCapacity: keepingCapacity)
    }

    @inlinable
    public mutating func removeAll<K: Hash.Key, V>(keepingCapacity: Bool = true)
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        let capacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count =
            keepingCapacity ? store.capacity : .zero
        self.store = Ownership.Shared(
            Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>(minimumCapacity: capacity)
        )
    }

    @inlinable
    public mutating func removeAll<K: Hash.Key & ~Copyable, V: ~Copyable>(
        keepingCapacity: Bool = true
    )
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        let capacity: Index_Primitives.Index<Hash.Entry<K, V>>.Count =
            keepingCapacity ? store.capacity : .zero
        self.store = Ownership.Shared(
            Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>(minimumCapacity: capacity)
        )
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public func forEach<K: Hash.Key & ~Copyable, V: ~Copyable>(
        _ body: (borrowing K, borrowing V) -> Void
    )
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        store.forEach { entry in body(entry.key, entry.value) }
    }

    @inlinable
    public func forEach<K: Hash.Key & ~Copyable, V: ~Copyable>(
        _ body: (borrowing K, borrowing V) -> Void
    )
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            column.forEach { entry in body(entry.key, entry.value) }
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public func clone<K: Hash.Key, V>() -> Self
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        Self(store: store.clone())
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public subscript<K: Hash.Key, V>(key: K) -> V?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        get { withValue(forKey: key) { $0 } }
        set {
            if let newValue {
                insert(key: key, value: newValue)
            } else {
                _ = removeValue(forKey: key)
            }
        }
    }

    @inlinable
    public mutating func set<K: Hash.Key, V>(_ key: K, _ value: V)
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        insert(key: key, value: value)
    }
}
