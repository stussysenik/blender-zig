import Foundation

struct LineTextDocument {
    let lines: [String]
    let hadTrailingNewline: Bool

    init(text: String) {
        self.hadTrailingNewline = text.hasSuffix("\n")
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if self.hadTrailingNewline, lines.last == "" {
            lines.removeLast()
        }
        self.lines = lines
    }

    func value(for key: String) -> String? {
        guard let index = entryIndex(for: key) else { return nil }
        return Self.lineValue(for: lines[index])
    }

    func count(of key: String) -> Int {
        lines.reduce(into: 0) { count, line in
            if Self.lineKey(for: line) == key {
                count += 1
            }
        }
    }

    func values(for key: String) -> [String] {
        lines.compactMap { line in
            guard Self.lineKey(for: line) == key else { return nil }
            return Self.lineValue(for: line)
        }
    }

    func key(at index: Int) -> String? {
        Self.lineKey(for: lines[index])
    }

    func value(at index: Int) -> String? {
        Self.lineValue(for: lines[index])
    }

    func updatingValue(
        for key: String,
        to newValue: String,
        preferredAfterKeys: [String],
        beforeKeys: [String]
    ) -> String {
        var updatedLines = lines
        let renderedLine = "\(key)=\(newValue)"

        if let index = entryIndex(for: key) {
            updatedLines[index] = renderedLine
            return render(updatedLines)
        }

        let insertionIndex = metadataInsertionIndex(
            preferredAfterKeys: preferredAfterKeys,
            beforeKeys: beforeKeys
        )
        updatedLines.insert(renderedLine, at: insertionIndex)
        return render(updatedLines)
    }

    private func entryIndex(for key: String) -> Int? {
        lines.firstIndex { Self.lineKey(for: $0) == key }
    }

    private func metadataInsertionIndex(
        preferredAfterKeys: [String],
        beforeKeys: [String]
    ) -> Int {
        for preferredKey in preferredAfterKeys {
            if let index = entryIndex(for: preferredKey) {
                return index + 1
            }
        }

        for (index, line) in lines.enumerated() {
            guard let key = Self.lineKey(for: line) else { continue }
            if beforeKeys.contains(key) {
                return index
            }
        }

        return lines.count
    }

    func render(_ renderedLines: [String]) -> String {
        var text = renderedLines.joined(separator: "\n")
        if hadTrailingNewline || !text.isEmpty {
            text.append("\n")
        }
        return text
    }

    private static func lineKey(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separatorIndex = trimmed.firstIndex(of: "=") else {
            return nil
        }
        return String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
    }

    private static func lineValue(for line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: "=") else { return nil }
        return String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespaces)
    }
}
