import Foundation

public struct ShellInspectedDocument: Equatable, Sendable {
    public let request: ShellOpenRequest
    public let formatVersion: Int?
    public let replayID: String?
    public let title: String?
    public let structureSummary: String
    public let isEditable: Bool
    public let focusTargets: [ShellFocusTarget]
    public let defaultFocusTargetID: String?
    public let recipeTransformState: ShellRecipeTransformState?

    public init(
        request: ShellOpenRequest,
        formatVersion: Int?,
        replayID: String?,
        title: String?,
        structureSummary: String,
        isEditable: Bool,
        focusTargets: [ShellFocusTarget] = [],
        defaultFocusTargetID: String? = nil,
        recipeTransformState: ShellRecipeTransformState? = nil
    ) {
        self.request = request
        self.formatVersion = formatVersion
        self.replayID = replayID
        self.title = title
        self.structureSummary = structureSummary
        self.isEditable = isEditable
        self.focusTargets = focusTargets
        self.defaultFocusTargetID = defaultFocusTargetID
        self.recipeTransformState = recipeTransformState
    }
}
