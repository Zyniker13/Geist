/// Variant lookup by ID (P1: Standard only; the JSON catalog arrives in P3).
public enum VariantCatalog {
    /// All variants known to the catalog.
    public static var all: [Variant] { [.standard] }

    /// Look up a variant by ID.
    public static func variant(id: String) -> Variant? {
        all.first { $0.id == id }
    }
}
