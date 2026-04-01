import BlendZigShellCore
import Foundation
import Observation

@MainActor
@Observable
final class ShellAppModel {
    var currentRequest: ShellOpenRequest?
    var currentInspection: ShellInspectedDocument?
    var currentResult: ShellOpenResult?
    var editableTitle = ""
    var recipeScaleX = "1.0"
    var recipeScaleY = "1.0"
    var recipeScaleZ = "1.0"
    var recipeRotateZDegrees = "0.0"
    var recipeTranslateX = "0.0"
    var recipeTranslateY = "0.0"
    var recipeTranslateZ = "0.0"
    var focusedTargetID: String?
    var errorMessage: String?
    var saveMessage: String?
    var isOpening = false
    var isSaving = false

    @ObservationIgnored private var currentSession: ShellDocumentSession?
    @ObservationIgnored private let sessionService = ShellDocumentSessionService()
    @ObservationIgnored private var activeTask: Task<Void, Never>?
    @ObservationIgnored private var operationState = ShellOperationState()
    @ObservationIgnored private var startupRequestConsumed = false

    deinit {
        activeTask?.cancel()
    }

    func openDocument(at url: URL) {
        do {
            try beginOpen(request: ShellOpenRequest(url: url))
        } catch {
            currentSession = nil
            currentRequest = nil
            currentInspection = nil
            currentResult = nil
            editableTitle = ""
            applyRecipeTransformDrafts(.identity)
            focusedTargetID = nil
            errorMessage = describe(error)
            saveMessage = nil
            isOpening = false
        }
    }

    func reloadCurrentDocument() {
        guard let currentRequest else { return }
        do {
            try beginOpen(request: currentRequest)
        } catch {
            errorMessage = describe(error)
            isOpening = false
        }
    }

    func saveTitle() {
        guard let currentSession, currentSession.inspection.isEditable else { return }

        errorMessage = nil
        saveMessage = nil
        isSaving = true

        let generation = startOperation()
        let sessionService = self.sessionService
        let titleToSave = editableTitle
        activeTask = Task {
            do {
                let payload = try await sessionService.saveTitle(titleToSave, in: currentSession)
                guard operationState.contains(generation) else { return }

                applyPayload(payload.0, result: payload.1)
                saveMessage = "saved title to \(payload.0.inspection.request.url.lastPathComponent)"
            } catch is CancellationError {
            } catch {
                guard operationState.contains(generation) else { return }
                errorMessage = describe(error)
            }
            guard operationState.contains(generation) else { return }
            isSaving = false
        }
    }

    func saveRecipeTransform() {
        guard
            let currentSession,
            currentInspection?.request.kind == .recipe,
            currentInspection?.recipeTransformState?.isEditable == true
        else {
            return
        }

        do {
            let values = try draftRecipeTransformValues()
            errorMessage = nil
            saveMessage = nil
            isSaving = true

            let generation = startOperation()
            let sessionService = self.sessionService
            activeTask = Task {
                do {
                    let payload = try await sessionService.saveRecipeTransform(values, in: currentSession)
                    guard operationState.contains(generation) else { return }

                    applyPayload(payload.0, result: payload.1)
                    saveMessage = "saved transforms to \(payload.0.inspection.request.url.lastPathComponent)"
                } catch is CancellationError {
                } catch {
                    guard operationState.contains(generation) else { return }
                    errorMessage = describe(error)
                }
                guard operationState.contains(generation) else { return }
                isSaving = false
            }
        } catch {
            errorMessage = describe(error)
        }
    }

    var canSaveCurrentDocument: Bool {
        guard let inspection = currentInspection else { return false }
        let trimmedTitle = editableTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return inspection.isEditable && !trimmedTitle.isEmpty && trimmedTitle != inspection.title
    }

    var recipeTransformState: ShellRecipeTransformState? {
        currentInspection?.recipeTransformState
    }

    var recipeSubdivideState: ShellRecipeSubdivideState? {
        currentInspection?.recipeSubdivideState
    }

    var canSaveRecipeTransform: Bool {
        guard
            currentInspection?.request.kind == .recipe,
            let recipeTransformState,
            recipeTransformState.isEditable,
            let values = try? draftRecipeTransformValues()
        else {
            return false
        }
        return values != recipeTransformState.values
    }

    var canToggleRecipeSubdivide: Bool {
        guard
            currentInspection?.request.kind == .recipe,
            let recipeSubdivideState
        else {
            return false
        }
        return recipeSubdivideState.isEditable
    }

    var focusTargets: [ShellFocusTarget] {
        currentInspection?.focusTargets ?? []
    }

    var focusedTarget: ShellFocusTarget? {
        guard let focusedTargetID else { return focusTargets.first }
        return focusTargets.first(where: { $0.id == focusedTargetID }) ?? focusTargets.first
    }

    func focusTarget(id: String) {
        guard focusTargets.contains(where: { $0.id == id }) else { return }
        focusedTargetID = id
    }

    func createPrimitiveStudy(template: ShellPrimitiveTemplate, at url: URL, title: String? = nil) {
        currentRequest = nil
        currentSession = nil
        currentInspection = nil
        currentResult = nil
        editableTitle = ""
        applyRecipeTransformDrafts(.identity)
        focusedTargetID = nil
        errorMessage = nil
        saveMessage = nil
        isOpening = true

        let generation = startOperation()
        let sessionService = self.sessionService
        activeTask = Task {
            do {
                let payload = try await sessionService.createPrimitiveStudy(template: template, at: url, title: title)
                guard operationState.contains(generation) else { return }
                applyPayload(payload.0, result: payload.1)
                saveMessage = "created \(template.displayName.lowercased()) study at \(payload.0.inspection.request.url.lastPathComponent)"
            } catch is CancellationError {
            } catch {
                guard operationState.contains(generation) else { return }
                errorMessage = describe(error)
            }
            guard operationState.contains(generation) else { return }
            isOpening = false
        }
    }

    func toggleRecipeSubdivide() {
        guard
            let currentSession,
            currentInspection?.request.kind == .recipe,
            let recipeSubdivideState,
            recipeSubdivideState.isEditable
        else {
            return
        }

        errorMessage = nil
        saveMessage = nil
        isSaving = true

        let desiredApplied = !recipeSubdivideState.isApplied
        let generation = startOperation()
        let sessionService = self.sessionService
        activeTask = Task {
            do {
                let payload = try await sessionService.saveRecipeSubdivide(desiredApplied, in: currentSession)
                guard operationState.contains(generation) else { return }

                applyPayload(payload.0, result: payload.1)
                saveMessage = desiredApplied
                    ? "applied subdivide to \(payload.0.inspection.request.url.lastPathComponent)"
                    : "removed subdivide from \(payload.0.inspection.request.url.lastPathComponent)"
            } catch is CancellationError {
            } catch {
                guard operationState.contains(generation) else { return }
                errorMessage = describe(error)
            }
            guard operationState.contains(generation) else { return }
            isSaving = false
        }
    }

    func openStartupRequestIfNeeded(_ launchMode: ShellLaunchMode) {
        guard !startupRequestConsumed else { return }
        startupRequestConsumed = true

        guard case .interactive(let startupRequest) = launchMode, let startupRequest else {
            return
        }

        do {
            try beginOpen(request: startupRequest)
        } catch {
            errorMessage = describe(error)
            isOpening = false
        }
    }

    private func beginOpen(request: ShellOpenRequest) throws {
        currentRequest = request
        currentSession = nil
        currentInspection = nil
        currentResult = nil
        editableTitle = ""
        applyRecipeTransformDrafts(.identity)
        focusedTargetID = nil
        errorMessage = nil
        saveMessage = nil
        isOpening = true

        let generation = startOperation()
        let sessionService = self.sessionService
        activeTask = Task {
            do {
                let payload = try await sessionService.open(request)
                guard operationState.contains(generation) else { return }
                applyPayload(payload.0, result: payload.1)
            } catch is CancellationError {
            } catch {
                guard operationState.contains(generation) else { return }
                errorMessage = describe(error)
            }
            guard operationState.contains(generation) else { return }
            isOpening = false
        }
    }

    private func startOperation() -> UInt64 {
        activeTask?.cancel()
        return operationState.nextGeneration()
    }

    private func applyPayload(_ session: ShellDocumentSession, result: ShellOpenResult) {
        let previousFocusID = focusedTargetID
        currentSession = session
        currentInspection = session.inspection
        currentResult = result
        editableTitle = session.inspection.title ?? ""
        applyRecipeTransformDrafts(session.inspection.recipeTransformState?.values ?? .identity)
        focusedTargetID = session.inspection.focusTargets.contains(where: { $0.id == previousFocusID }) ? previousFocusID : session.inspection.defaultFocusTargetID
        if !result.succeeded {
            errorMessage = result.standardError.isEmpty ? "the bundled helper failed with exit code \(result.exitCode)" : result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }

    private func applyRecipeTransformDrafts(_ values: ShellRecipeTransformValues) {
        recipeScaleX = format(values.scaleX)
        recipeScaleY = format(values.scaleY)
        recipeScaleZ = format(values.scaleZ)
        recipeRotateZDegrees = format(values.rotateZDegrees)
        recipeTranslateX = format(values.translateX)
        recipeTranslateY = format(values.translateY)
        recipeTranslateZ = format(values.translateZ)
    }

    private func draftRecipeTransformValues() throws -> ShellRecipeTransformValues {
        try .init(
            scaleX: parseDouble(recipeScaleX, field: "scale x"),
            scaleY: parseDouble(recipeScaleY, field: "scale y"),
            scaleZ: parseDouble(recipeScaleZ, field: "scale z"),
            rotateZDegrees: parseDouble(recipeRotateZDegrees, field: "rotate z"),
            translateX: parseDouble(recipeTranslateX, field: "translate x"),
            translateY: parseDouble(recipeTranslateY, field: "translate y"),
            translateZ: parseDouble(recipeTranslateZ, field: "translate z")
        )
    }

    private func parseDouble(_ rawValue: String, field: String) throws -> Double {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed) else {
            throw ShellAppModelTransformError.invalidNumber(field: field)
        }
        return value
    }

    private func format(_ value: Double) -> String {
        String(value)
    }
}

private enum ShellAppModelTransformError: LocalizedError {
    case invalidNumber(field: String)

    var errorDescription: String? {
        switch self {
        case .invalidNumber(let field):
            "invalid numeric value for \(field)"
        }
    }
}
