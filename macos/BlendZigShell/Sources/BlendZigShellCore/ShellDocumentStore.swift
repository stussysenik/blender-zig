import Foundation

public struct ShellDocumentStore: Sendable {
    private static let unsupportedRecipeTransformEditingMessage =
        "transform editing is unavailable because recipe transform steps are not isolated in a trailing block"
    private static let unsupportedRecipeSubdivideEditingMessage =
        "subdivide editing is unavailable because the recipe does not isolate one trailing shell-owned subdivide step"

    public init() {}

    public func inspect(_ request: ShellOpenRequest) throws -> ShellInspectedDocument {
        try inspectSession(request).inspection
    }

    public func inspectSession(_ request: ShellOpenRequest) throws -> ShellDocumentSession {
        switch request.kind {
        case .recipe:
            let text = try readText(at: request.url)
            let document = LineTextDocument(text: text)
            let focusTargets = recipeFocusTargets(from: document, request: request)
            let transformAnalysis = recipeTransformAnalysis(from: document)
            let subdivideAnalysis = recipeSubdivideAnalysis(
                from: document,
                transformAnalysis: transformAnalysis
            )
            let inspection = ShellInspectedDocument(
                request: request,
                formatVersion: intValue(document.value(for: "format-version")),
                replayID: document.value(for: "id"),
                title: document.value(for: "title"),
                structureSummary: recipeSummary(from: document),
                isEditable: true,
                focusTargets: focusTargets,
                defaultFocusTargetID: focusTargets.first?.id,
                recipeTransformState: transformAnalysis.state,
                recipeSubdivideState: subdivideAnalysis.state
            )
            return ShellDocumentSession(inspection: inspection, originalText: text)
        case .scene:
            let text = try readText(at: request.url)
            let document = LineTextDocument(text: text)
            let focusTargets = sceneFocusTargets(from: document)
            let inspection = ShellInspectedDocument(
                request: request,
                formatVersion: intValue(document.value(for: "format-version")),
                replayID: document.value(for: "id"),
                title: document.value(for: "title"),
                structureSummary: sceneSummary(from: document),
                isEditable: true,
                focusTargets: focusTargets,
                defaultFocusTargetID: focusTargets.first?.id
            )
            return ShellDocumentSession(inspection: inspection, originalText: text)
        case .bundle:
            let manifestURL = manifestURL(for: request.url)
            let text = try readText(at: manifestURL)
            let document = LineTextDocument(text: text)
            let inspection = ShellInspectedDocument(
                request: request,
                formatVersion: intValue(document.value(for: "format-version")),
                replayID: document.value(for: "id"),
                title: document.value(for: "title"),
                structureSummary: bundleSummary(from: document),
                isEditable: false
            )
            return ShellDocumentSession(inspection: inspection, originalText: text)
        }
    }

    public func createPrimitiveStudy(
        template: ShellPrimitiveTemplate,
        at rawURL: URL,
        title rawTitle: String? = nil
    ) throws -> ShellDocumentSession {
        let url = rawURL.standardizedFileURL
        _ = try ShellOpenRequest(url: url)

        let replayID = url.deletingPathExtension().lastPathComponent
        let title = normalizedTitle(rawTitle, fallbackStem: replayID, defaultTitle: template.defaultTitle)
        let text = template.renderRecipeText(title: title, replayID: replayID, studyURL: url)

        let parentDirectory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)

        return try inspectSession(ShellOpenRequest(url: url))
    }

    @discardableResult
    public func saveTitle(_ rawTitle: String, for request: ShellOpenRequest) throws -> ShellInspectedDocument {
        try saveTitle(rawTitle, in: inspectSession(request)).inspection
    }

    @discardableResult
    public func saveTitle(_ rawTitle: String, in session: ShellDocumentSession) throws -> ShellDocumentSession {
        let newTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else {
            throw ShellDocumentStoreError.emptyTitle
        }

        switch session.inspection.request.kind {
        case .recipe:
            let url = session.inspection.request.url
            let currentText = try readText(at: url)
            guard currentText == session.originalText else {
                throw ShellDocumentStoreError.documentChangedSinceOpen(.recipe)
            }

            let document = LineTextDocument(text: currentText)
            let updatedText = document.updatingValue(
                for: "title",
                to: newTitle,
                preferredAfterKeys: ["id", "format-version"],
                beforeKeys: ["seed", "write", "step"]
            )
            try updatedText.write(to: url, atomically: true, encoding: .utf8)
            return try inspectSession(session.inspection.request)
        case .scene:
            let url = session.inspection.request.url
            let currentText = try readText(at: url)
            guard currentText == session.originalText else {
                throw ShellDocumentStoreError.documentChangedSinceOpen(.scene)
            }

            let document = LineTextDocument(text: currentText)
            let updatedText = document.updatingValue(
                for: "title",
                to: newTitle,
                preferredAfterKeys: ["id", "format-version"],
                beforeKeys: ["part", "write"]
            )
            try updatedText.write(to: url, atomically: true, encoding: .utf8)
            return try inspectSession(session.inspection.request)
        case .bundle:
            throw ShellDocumentStoreError.inspectOnlyDocument(.bundle)
        }
    }

    @discardableResult
    public func saveRecipeTransform(
        _ values: ShellRecipeTransformValues,
        in session: ShellDocumentSession
    ) throws -> ShellDocumentSession {
        guard session.inspection.request.kind == .recipe else {
            throw ShellDocumentStoreError.inspectOnlyDocument(session.inspection.request.kind)
        }

        let url = session.inspection.request.url
        let currentText = try readText(at: url)
        guard currentText == session.originalText else {
            throw ShellDocumentStoreError.documentChangedSinceOpen(.recipe)
        }

        let document = LineTextDocument(text: currentText)
        let analysis = recipeTransformAnalysis(from: document)
        guard analysis.state.isEditable else {
            throw ShellDocumentStoreError.unsupportedRecipeTransformEditing
        }

        let replacementLines = renderRecipeTransformLines(values)
        var updatedLines = document.lines
        if let trailingTransformLineRange = analysis.trailingTransformLineRange {
            updatedLines.replaceSubrange(trailingTransformLineRange, with: replacementLines)
        } else {
            updatedLines.append(contentsOf: replacementLines)
        }

        let updatedText = document.render(updatedLines)
        try updatedText.write(to: url, atomically: true, encoding: .utf8)
        return try inspectSession(session.inspection.request)
    }

    @discardableResult
    public func saveRecipeSubdivide(
        _ isApplied: Bool,
        in session: ShellDocumentSession
    ) throws -> ShellDocumentSession {
        guard session.inspection.request.kind == .recipe else {
            throw ShellDocumentStoreError.inspectOnlyDocument(session.inspection.request.kind)
        }

        let url = session.inspection.request.url
        let currentText = try readText(at: url)
        guard currentText == session.originalText else {
            throw ShellDocumentStoreError.documentChangedSinceOpen(.recipe)
        }

        let document = LineTextDocument(text: currentText)
        let transformAnalysis = recipeTransformAnalysis(from: document)
        let analysis = recipeSubdivideAnalysis(from: document, transformAnalysis: transformAnalysis)
        guard analysis.state.isEditable else {
            throw ShellDocumentStoreError.unsupportedRecipeSubdivideEditing
        }

        var updatedLines = document.lines
        if let ownedSubdivideLineRange = analysis.ownedSubdivideLineRange {
            if isApplied {
                updatedLines.replaceSubrange(ownedSubdivideLineRange, with: [renderOwnedRecipeSubdivideLine()])
            } else {
                updatedLines.removeSubrange(ownedSubdivideLineRange)
            }
        } else if isApplied {
            updatedLines.insert(renderOwnedRecipeSubdivideLine(), at: analysis.insertionLineIndex)
        } else {
            return try inspectSession(session.inspection.request)
        }

        let updatedText = document.render(updatedLines)
        try updatedText.write(to: url, atomically: true, encoding: .utf8)
        return try inspectSession(session.inspection.request)
    }

    private func readText(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func manifestURL(for bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent("manifest.bzmanifest", isDirectory: false)
    }

    private func intValue(_ text: String?) -> Int? {
        guard let text else { return nil }
        return Int(text)
    }

    private func recipeSummary(from document: LineTextDocument) -> String {
        let seed = document.value(for: "seed") ?? "unknown"
        return "seed=\(seed) steps=\(document.count(of: "step"))"
    }

    private func sceneSummary(from document: LineTextDocument) -> String {
        "parts=\(document.count(of: "part"))"
    }

    private func bundleSummary(from document: LineTextDocument) -> String {
        let components = document.value(for: "components") ?? "unknown"
        let geometryPath = document.value(for: "geometry-path") ?? "unknown"
        return "components=\(components) geometry-path=\(geometryPath)"
    }

    private func recipeFocusTargets(from document: LineTextDocument, request: ShellOpenRequest) -> [ShellFocusTarget] {
        let seedSpec = document.value(for: "seed") ?? "unknown"
        let seedKind = seedSpec.split(separator: ":", maxSplits: 1).first.map(String.init) ?? "unknown"
        let displayName = document.value(for: "title") ?? request.url.deletingPathExtension().lastPathComponent

        var properties = [
            ShellFocusProperty(label: "Seed", value: seedKind),
            ShellFocusProperty(label: "Steps", value: "\(document.count(of: "step"))"),
        ]
        if let writePath = document.value(for: "write") {
            properties.append(.init(label: "Write", value: writePath))
        }

        return [
            ShellFocusTarget(
                id: "study-root",
                name: displayName,
                kind: seedKind,
                summary: "primitive study",
                properties: properties
            ),
        ]
    }

    private func sceneFocusTargets(from document: LineTextDocument) -> [ShellFocusTarget] {
        document.values(for: "part").enumerated().map { index, partValue in
            let segments = partValue.split(separator: "|").map(String.init)
            let source = segments.first ?? "unknown"
            let name = URL(fileURLWithPath: source).deletingPathExtension().lastPathComponent
            let kind = URL(fileURLWithPath: source).pathExtension.lowercased()
            let placementTokens = Array(segments.dropFirst())
            let placementValue = placementTokens.isEmpty ? "none" : placementTokens.joined(separator: "; ")

            return ShellFocusTarget(
                id: "part-\(index)",
                name: name.isEmpty ? "part-\(index + 1)" : name,
                kind: kind.isEmpty ? "part" : kind,
                summary: "scene part",
                properties: [
                    .init(label: "Source", value: source),
                    .init(label: "Placement", value: placementValue),
                ]
            )
        }
    }

    private func normalizedTitle(_ rawTitle: String?, fallbackStem: String, defaultTitle: String) -> String {
        if let rawTitle {
            let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        let words = fallbackStem
            .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == " " })
            .map { token in
                let lowercased = token.lowercased()
                return lowercased.prefix(1).uppercased() + lowercased.dropFirst()
            }
        if !words.isEmpty {
            return words.joined(separator: " ")
        }

        return defaultTitle
    }

    private func recipeTransformAnalysis(from document: LineTextDocument) -> RecipeTransformAnalysis {
        let stepEntries = recipeStepEntries(from: document)
        guard !stepEntries.isEmpty else {
            return .editable(.identity)
        }

        var trailingBlockStart = stepEntries.count
        while trailingBlockStart > 0, stepEntries[trailingBlockStart - 1].transformKind != nil {
            trailingBlockStart -= 1
        }

        let hasAnyTransform = stepEntries.contains { $0.transformKind != nil }
        if trailingBlockStart == stepEntries.count {
            return hasAnyTransform ? .unsupported : .editable(.identity)
        }

        if stepEntries[..<trailingBlockStart].contains(where: { $0.transformKind != nil }) {
            return .unsupported
        }

        let trailingEntries = Array(stepEntries[trailingBlockStart...])
        var seenKinds = Set<RecipeTransformKind>()
        var values = ShellRecipeTransformValues.identity

        for entry in trailingEntries {
            guard let transformKind = entry.transformKind else {
                return .unsupported
            }
            guard seenKinds.insert(transformKind).inserted else {
                return .unsupported
            }

            switch transformKind {
            case .scale:
                guard let vector = parseScaleTransform(from: entry.value) else {
                    return .unsupported
                }
                values.scaleX = vector.x
                values.scaleY = vector.y
                values.scaleZ = vector.z
            case .rotateZ:
                guard let degrees = parseRotateZTransform(from: entry.value) else {
                    return .unsupported
                }
                values.rotateZDegrees = degrees
            case .translate:
                guard let vector = parseTranslateTransform(from: entry.value) else {
                    return .unsupported
                }
                values.translateX = vector.x
                values.translateY = vector.y
                values.translateZ = vector.z
            }
        }

        guard
            let firstLineIndex = trailingEntries.first?.lineIndex,
            let lastLineIndex = trailingEntries.last?.lineIndex
        else {
            return .editable(values)
        }
        return .editable(values, trailingTransformLineRange: firstLineIndex..<(lastLineIndex + 1))
    }

    private func recipeSubdivideAnalysis(
        from document: LineTextDocument,
        transformAnalysis: RecipeTransformAnalysis
    ) -> RecipeSubdivideAnalysis {
        let stepEntries = recipeStepEntries(from: document)
        if !transformAnalysis.state.isEditable, stepEntries.contains(where: { $0.transformKind != nil }) {
            return .unsupported
        }

        guard !stepEntries.isEmpty else {
            return .editable(isApplied: false, insertionLineIndex: document.lines.count)
        }

        let trailingTransformStart = trailingTransformStepStartIndex(for: stepEntries)
        let insertionLineIndex = trailingTransformStart < stepEntries.count
            ? stepEntries[trailingTransformStart].lineIndex
            : document.lines.count

        let subdivideEntries = stepEntries.enumerated().filter { isSubdivideStep($0.element.value) }
        guard !subdivideEntries.isEmpty else {
            return .editable(isApplied: false, insertionLineIndex: insertionLineIndex)
        }

        guard
            subdivideEntries.count == 1,
            let ownedIndex = ownedSubdivideStepIndex(
                in: stepEntries,
                trailingTransformStart: trailingTransformStart
            ),
            subdivideEntries[0].offset == ownedIndex
        else {
            return .unsupported
        }

        let lineIndex = stepEntries[ownedIndex].lineIndex
        return .editable(
            isApplied: true,
            ownedSubdivideLineRange: lineIndex..<(lineIndex + 1),
            insertionLineIndex: lineIndex
        )
    }

    private func recipeStepEntries(from document: LineTextDocument) -> [RecipeStepEntry] {
        document.lines.enumerated().compactMap { index, _ in
            guard document.key(at: index) == "step", let value = document.value(at: index) else {
                return nil
            }

            return RecipeStepEntry(
                lineIndex: index,
                value: value,
                transformKind: RecipeTransformKind(stepValue: value)
            )
        }
    }

    private func trailingTransformStepStartIndex(for stepEntries: [RecipeStepEntry]) -> Int {
        var trailingBlockStart = stepEntries.count
        while trailingBlockStart > 0, stepEntries[trailingBlockStart - 1].transformKind != nil {
            trailingBlockStart -= 1
        }
        return trailingBlockStart
    }

    private func ownedSubdivideStepIndex(
        in stepEntries: [RecipeStepEntry],
        trailingTransformStart: Int
    ) -> Int? {
        if trailingTransformStart == stepEntries.count {
            guard let lastIndex = stepEntries.indices.last else { return nil }
            return isShellOwnedSubdivideStep(stepEntries[lastIndex].value) ? lastIndex : nil
        }

        let candidateIndex = trailingTransformStart - 1
        guard candidateIndex >= 0 else { return nil }
        return isShellOwnedSubdivideStep(stepEntries[candidateIndex].value) ? candidateIndex : nil
    }

    private func isSubdivideStep(_ stepValue: String) -> Bool {
        stepName(for: stepValue) == "subdivide"
    }

    private func isShellOwnedSubdivideStep(_ stepValue: String) -> Bool {
        guard isSubdivideStep(stepValue) else {
            return false
        }

        let components = stepValue.split(separator: ":", maxSplits: 1).map(String.init)
        if components.count == 1 {
            return true
        }
        guard components.count == 2 else {
            return false
        }
        guard let parameters = Self.parseStepParameters(components[1]) else {
            return false
        }
        guard Set(parameters.keys) == ["repeat"], let repeatCount = Int(parameters["repeat"] ?? "") else {
            return false
        }
        return repeatCount == 1
    }

    private func stepName(for stepValue: String) -> String {
        stepValue
            .split(separator: ":", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? stepValue
    }

    private static func parseStepParameters(_ rawParameters: String) -> [String: String]? {
        var parameters: [String: String] = [:]
        for pair in rawParameters.split(separator: ",").map(String.init) {
            let keyValue = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard keyValue.count == 2 else {
                return nil
            }

            let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = keyValue[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, parameters[key] == nil else {
                return nil
            }
            parameters[key] = value
        }
        return parameters
    }

    private func parseScaleTransform(from stepValue: String) -> Vector3Values? {
        guard let step = StepSpecification(stepValue: stepValue), step.kind == .scale else {
            return nil
        }
        guard Set(step.parameters.keys) == ["x", "y", "z"] else {
            return nil
        }
        guard
            let x = Double(step.parameters["x"] ?? ""),
            let y = Double(step.parameters["y"] ?? ""),
            let z = Double(step.parameters["z"] ?? "")
        else {
            return nil
        }
        return Vector3Values(x: x, y: y, z: z)
    }

    private func parseRotateZTransform(from stepValue: String) -> Double? {
        guard let step = StepSpecification(stepValue: stepValue), step.kind == .rotateZ else {
            return nil
        }
        guard Set(step.parameters.keys) == ["degrees"] else {
            return nil
        }
        return Double(step.parameters["degrees"] ?? "")
    }

    private func parseTranslateTransform(from stepValue: String) -> Vector3Values? {
        guard let step = StepSpecification(stepValue: stepValue), step.kind == .translate else {
            return nil
        }
        guard Set(step.parameters.keys) == ["x", "y", "z"] else {
            return nil
        }
        guard
            let x = Double(step.parameters["x"] ?? ""),
            let y = Double(step.parameters["y"] ?? ""),
            let z = Double(step.parameters["z"] ?? "")
        else {
            return nil
        }
        return Vector3Values(x: x, y: y, z: z)
    }

    private func renderRecipeTransformLines(_ values: ShellRecipeTransformValues) -> [String] {
        [
            "step=scale:x=\(values.scaleX),y=\(values.scaleY),z=\(values.scaleZ)",
            "step=rotate-z:degrees=\(values.rotateZDegrees)",
            "step=translate:x=\(values.translateX),y=\(values.translateY),z=\(values.translateZ)",
        ]
    }

    private func renderOwnedRecipeSubdivideLine() -> String {
        "step=subdivide:repeat=1"
    }
}

private extension ShellDocumentStore {
    struct Vector3Values {
        let x: Double
        let y: Double
        let z: Double
    }

    struct RecipeTransformAnalysis {
        let state: ShellRecipeTransformState
        let trailingTransformLineRange: Range<Int>?

        static func editable(
            _ values: ShellRecipeTransformValues,
            trailingTransformLineRange: Range<Int>? = nil
        ) -> Self {
            Self(
                state: .init(values: values, isEditable: true, message: nil),
                trailingTransformLineRange: trailingTransformLineRange
            )
        }

        static let unsupported = Self(
            state: .init(
                values: .identity,
                isEditable: false,
                message: ShellDocumentStore.unsupportedRecipeTransformEditingMessage
            ),
            trailingTransformLineRange: nil
        )
    }

    struct RecipeSubdivideAnalysis {
        let state: ShellRecipeSubdivideState
        let ownedSubdivideLineRange: Range<Int>?
        let insertionLineIndex: Int

        static func editable(
            isApplied: Bool,
            ownedSubdivideLineRange: Range<Int>? = nil,
            insertionLineIndex: Int
        ) -> Self {
            Self(
                state: .init(isApplied: isApplied, isEditable: true, message: nil),
                ownedSubdivideLineRange: ownedSubdivideLineRange,
                insertionLineIndex: insertionLineIndex
            )
        }

        static let unsupported = Self(
            state: .init(
                isApplied: false,
                isEditable: false,
                message: ShellDocumentStore.unsupportedRecipeSubdivideEditingMessage
            ),
            ownedSubdivideLineRange: nil,
            insertionLineIndex: 0
        )
    }

    struct RecipeStepEntry {
        let lineIndex: Int
        let value: String
        let transformKind: RecipeTransformKind?
    }

    struct StepSpecification {
        let kind: RecipeTransformKind
        let parameters: [String: String]

        init?(stepValue: String) {
            guard let kind = RecipeTransformKind(stepValue: stepValue) else {
                return nil
            }

            let components = stepValue.split(separator: ":", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                return nil
            }

            guard let parameters = ShellDocumentStore.parseStepParameters(components[1]) else {
                return nil
            }

            self.kind = kind
            self.parameters = parameters
        }
    }

    enum RecipeTransformKind: String, Hashable {
        case scale = "scale"
        case rotateZ = "rotate-z"
        case translate = "translate"

        init?(stepValue: String) {
            let kind = stepValue
                .split(separator: ":", maxSplits: 1)
                .first
                .map(String.init)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let kind, let parsedKind = Self(rawValue: kind) else {
                return nil
            }
            self = parsedKind
        }
    }
}
