import Foundation
import Parsing

public struct EditorInformation {
    public struct LineAnnotation {
        public var type: String
        public var line: Int
        public var message: String
    }

    public struct SourceEditorContent {
        /// The content of the source editor.
        public var content: String
        /// The content of the source editor in lines.
        public var lines: [String]
        /// The selection ranges of the source editor.
        public var selections: [CursorRange]
        /// The cursor position of the source editor.
        public var cursorPosition: CursorPosition
        /// Line annotations of the source editor.
        public var lineAnnotations: [LineAnnotation]

        public var selectedContent: String {
            if let range = selections.first {
                let startIndex = min(
                    max(0, range.start.line),
                    lines.endIndex - 1
                )
                let endIndex = min(
                    max(startIndex, range.end.line),
                    lines.endIndex - 1
                )
                let selectedContent = lines[startIndex...endIndex]
                return selectedContent.joined()
            }
            return ""
        }

        public init(
            content: String,
            lines: [String],
            selections: [CursorRange],
            cursorPosition: CursorPosition,
            lineAnnotations: [String]
        ) {
            self.content = content
            self.lines = lines
            self.selections = selections
            self.cursorPosition = cursorPosition
            self.lineAnnotations = lineAnnotations.map(EditorInformation.parseLineAnnotation)
        }
    }

    public let editorContent: SourceEditorContent?
    public let selectedContent: String
    public let selectedLines: [String]
    public let documentURL: URL
    public let projectURL: URL
    public let relativePath: String
    public let language: CodeLanguage

    public init(
        editorContent: SourceEditorContent?,
        selectedContent: String,
        selectedLines: [String],
        documentURL: URL,
        projectURL: URL,
        relativePath: String,
        language: CodeLanguage
    ) {
        self.editorContent = editorContent
        self.selectedContent = selectedContent
        self.selectedLines = selectedLines
        self.documentURL = documentURL
        self.projectURL = projectURL
        self.relativePath = relativePath
        self.language = language
    }

    public func code(in range: CursorRange) -> String {
        return EditorInformation.code(in: editorContent?.lines ?? [], inside: range).code
    }

    public static func lines(in code: [String], containing range: CursorRange) -> [String] {
        let startIndex = min(max(0, range.start.line), code.endIndex - 1)
        let endIndex = min(max(startIndex, range.end.line), code.endIndex - 1)
        let selectedLines = code[startIndex...endIndex]
        return Array(selectedLines)
    }

    public static func code(
        in code: [String],
        inside range: CursorRange
    ) -> (code: String, lines: [String]) {
        let rangeLines = lines(in: code, containing: range)
        var content = rangeLines
        if !content.isEmpty {
            content[content.endIndex - 1] = String(
                content[content.endIndex - 1].dropLast(
                    content[content.endIndex - 1].count - range.end.character
                )
            )
            content[0] = String(content[0].dropFirst(range.start.character))
        }
        return (content.joined(), rangeLines)
    }

    /// Error Line 25: FileName.swift:25 Cannot convert Type
    static func parseLineAnnotation(_ annotation: String) -> LineAnnotation {
        let lineAnnotationParser = Parse(input: Substring.self) {
            PrefixUpTo(":")
            ":"
            PrefixUpTo(":")
            ":"
            Int.parser()
            Prefix(while: { _ in true })
        }.map { (prefix: Substring, _: Substring, line: Int, message: Substring) in
            let type = String(prefix.split(separator: " ").first ?? prefix)
            return LineAnnotation(
                type: type.trimmingCharacters(in: .whitespacesAndNewlines),
                line: line,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        do {
            return try lineAnnotationParser.parse(annotation[...])
        } catch {
            return .init(type: "", line: 0, message: annotation)
        }
    }
}

