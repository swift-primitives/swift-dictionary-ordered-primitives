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
import Ordinal_Primitives_Standard_Library_Integration
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives
public import Storage_Primitive

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public func index<K: Hash.Key & ~Copyable, V: ~Copyable>(
        forKey key: borrowing K
    ) -> Index_Primitives.Index<Hash.Entry<K, V>>?
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        store.position(
            matching: key.hashValue,
            context: key,
            equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                candidate.key == probe
            }
        )
    }

    @inlinable
    public func index<K: Hash.Key & ~Copyable, V: ~Copyable>(
        forKey key: borrowing K
    ) -> Index_Primitives.Index<Hash.Entry<K, V>>?
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            column.position(
                matching: key.hashValue,
                context: key,
                equals: { (candidate: borrowing Hash.Entry<K, V>, probe: borrowing K) in
                    candidate.key == probe
                }
            )
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public func key<K: Hash.Key, V: ~Copyable>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> K
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(
            position < store.count.map(Ordinal.init),
            "ordered index domain: position out of bounds"
        )
        return store[position].key
    }

    @inlinable
    public func key<K: Hash.Key, V: ~Copyable>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> K
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(
                position < column.count.map(Ordinal.init),
                "ordered index domain: position out of bounds"
            )
            return column[position].key
        }
    }

    @inlinable
    public func value<K: Hash.Key & ~Copyable, V>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> V
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(
            position < store.count.map(Ordinal.init),
            "ordered index domain: position out of bounds"
        )
        return store[position].value
    }

    @inlinable
    public func value<K: Hash.Key & ~Copyable, V>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> V
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(
                position < column.count.map(Ordinal.init),
                "ordered index domain: position out of bounds"
            )
            return column[position].value
        }
    }

    @inlinable
    public func entry<K: Hash.Key, V>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> (key: K, value: V)
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(
            position < store.count.map(Ordinal.init),
            "ordered index domain: position out of bounds"
        )
        return (key: store[position].key, value: store[position].value)
    }

    @inlinable
    public func entry<K: Hash.Key, V>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>
    ) -> (key: K, value: V)
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(
                position < column.count.map(Ordinal.init),
                "ordered index domain: position out of bounds"
            )
            return (key: column[position].key, value: column[position].value)
        }
    }

    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>,
        _ body: (borrowing V) -> R
    ) -> R
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(
            position < store.count.map(Ordinal.init),
            "ordered index domain: position out of bounds"
        )
        return body(store[position].value)
    }

    @inlinable
    public func withValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>,
        _ body: (borrowing V) -> R
    ) -> R
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withColumn { column in
            precondition(
                position < column.count.map(Ordinal.init),
                "ordered index domain: position out of bounds"
            )
            return body(column[position].value)
        }
    }
}

extension __DictionaryOrdered where S: ~Copyable {

    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>,
        _ body: (inout V) -> R
    ) -> R
    where S == Hash.Indexed<Column.Heap<Hash.Entry<K, V>>> {
        precondition(
            position < store.count.map(Ordinal.init),
            "ordered index domain: position out of bounds"
        )
        return body(&store[position].value)
    }

    @inlinable
    public mutating func withMutableValue<K: Hash.Key & ~Copyable, V: ~Copyable, R>(
        at position: Index_Primitives.Index<Hash.Entry<K, V>>,
        _ body: (inout V) -> R
    ) -> R
    where S == Ownership.Shared<Hash.Entry<K, V>, Hash.Indexed<Column.Heap<Hash.Entry<K, V>>>> {
        store.withUnique { column in
            precondition(
                position < column.count.map(Ordinal.init),
                "ordered index domain: position out of bounds"
            )
            return body(&column[position].value)
        }
    }
}
