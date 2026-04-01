import Foundation

public struct ShellRecipeSubdivideState: Equatable, Sendable {
    public let isApplied: Bool
    public let isEditable: Bool
    public let message: String?

    public init(isApplied: Bool, isEditable: Bool, message: String?) {
        self.isApplied = isApplied
        self.isEditable = isEditable
        self.message = message
    }
}
