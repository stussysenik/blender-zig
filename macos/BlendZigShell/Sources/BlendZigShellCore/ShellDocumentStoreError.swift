import Foundation

public enum ShellDocumentStoreError: LocalizedError, Equatable {
    case emptyTitle
    case documentChangedSinceOpen(ShellDocumentKind)
    case inspectOnlyDocument(ShellDocumentKind)
    case unsupportedRecipeTransformEditing
    case unsupportedRecipeSubdivideEditing

    public var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "title must not be empty"
        case .documentChangedSinceOpen(let kind):
            switch kind {
            case .recipe, .scene:
                "document changed on disk since it was opened; reload before saving"
            case .bundle:
                "document changed on disk since it was opened"
            }
        case .inspectOnlyDocument(let kind):
            switch kind {
            case .bundle:
                "bundle metadata is inspect-only in this shell slice"
            case .recipe, .scene:
                "document is inspect-only"
            }
        case .unsupportedRecipeTransformEditing:
            "transform editing is unavailable because recipe transform steps are not isolated in a trailing block"
        case .unsupportedRecipeSubdivideEditing:
            "subdivide editing is unavailable because the recipe does not isolate one trailing shell-owned subdivide step"
        }
    }
}
