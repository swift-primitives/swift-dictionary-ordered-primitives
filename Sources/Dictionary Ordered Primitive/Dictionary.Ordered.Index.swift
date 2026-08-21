public import Index_Primitives
public import Store_Protocol_Primitives

extension __DictionaryOrdered where S: Store.`Protocol` & ~Copyable {

    public typealias Index = Index_Primitives.Index<S.Element>
}
