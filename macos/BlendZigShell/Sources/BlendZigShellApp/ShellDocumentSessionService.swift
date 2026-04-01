import BlendZigShellCore
import Foundation

actor ShellDocumentSessionService {
    private let runtime = ShellRuntime()
    private let documentStore = ShellDocumentStore()

    func open(_ request: ShellOpenRequest) throws -> (ShellDocumentSession, ShellOpenResult) {
        let session = try documentStore.inspectSession(request)
        let result = try runtime.open(request)
        return (session, result)
    }

    func saveTitle(_ title: String, in session: ShellDocumentSession) throws -> (ShellDocumentSession, ShellOpenResult) {
        let updatedSession = try documentStore.saveTitle(title, in: session)
        let result = try runtime.open(updatedSession.inspection.request)
        return (updatedSession, result)
    }

    func saveRecipeTransform(
        _ values: ShellRecipeTransformValues,
        in session: ShellDocumentSession
    ) throws -> (ShellDocumentSession, ShellOpenResult) {
        let updatedSession = try documentStore.saveRecipeTransform(values, in: session)
        let result = try runtime.open(updatedSession.inspection.request)
        return (updatedSession, result)
    }

    func saveRecipeSubdivide(
        _ isApplied: Bool,
        in session: ShellDocumentSession
    ) throws -> (ShellDocumentSession, ShellOpenResult) {
        let updatedSession = try documentStore.saveRecipeSubdivide(isApplied, in: session)
        let result = try runtime.open(updatedSession.inspection.request)
        return (updatedSession, result)
    }

    func createPrimitiveStudy(
        template: ShellPrimitiveTemplate,
        at url: URL,
        title: String? = nil
    ) throws -> (ShellDocumentSession, ShellOpenResult) {
        let session = try documentStore.createPrimitiveStudy(template: template, at: url, title: title)
        let result = try runtime.open(session.inspection.request)
        return (session, result)
    }
}
