public import Buffer_Linear_Primitive
public import Buffer_Protocol_Primitives
public import Column_Primitives
public import Dictionary_Primitive
public import Hash_Indexed_Primitive
import Hash_Primitives
public import Memory_Allocator_Primitive
public import Memory_Heap_Primitives
public import Ownership_Shared_Primitive
public import Storage_Contiguous_Primitives
public import Store_Protocol_Primitives

extension __Dictionary where S: Store.`Protocol` & ~Copyable, S.Element: Hash.Key {

    public typealias Ordered =
        __DictionaryOrdered<Hash.Indexed<Column.Heap<S.Element>>>
}

extension __DictionaryOrdered
where
    S: ~Copyable,
    S: Store.`Protocol` & Buffer.`Protocol`
{

    public typealias Shared = __DictionaryOrdered<Ownership.Shared<S.Element, S>>
}
