import Testing
import Foundation

// Local copy of TerminalNameSummarizer.sanitize for unit testing.
// Keep in sync with TerminalNameSummarizer.swift.
private func sanitizeName(_ raw: String) -> String? {
    let firstLine = raw
        .components(separatedBy: CharacterSet.newlines)
        .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""

    var name = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    let strippable: Set<Character> = ["\"", "'", "`", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "."]
    while let first = name.first, strippable.contains(first) { name.removeFirst() }
    while let last = name.last, strippable.contains(last) { name.removeLast() }
    name = name.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !name.isEmpty else { return nil }
    let maxLength = 40
    if name.count > maxLength {
        name = String(name.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard !name.isEmpty else { return nil }
    return name.capitalized
}

@Suite("TerminalNameSummarizer — sanitize")
struct TerminalNameSanitizerTests {

    @Test("Title-cases a plain string")
    func titleCase() {
        #expect(sanitizeName("fix broken tests") == "Fix Broken Tests")
    }

    @Test("Strips straight double quotes")
    func stripsDoubleQuotes() {
        #expect(sanitizeName("\"Fix Tests\"") == "Fix Tests")
    }

    @Test("Strips straight single quotes")
    func stripsSingleQuotes() {
        #expect(sanitizeName("'Fix Tests'") == "Fix Tests")
    }

    @Test("Strips curly double quotes")
    func stripsCurlyDoubleQuotes() {
        #expect(sanitizeName("\u{201C}Fix Tests\u{201D}") == "Fix Tests")
    }

    @Test("Strips curly single quotes")
    func stripsCurlySingleQuotes() {
        #expect(sanitizeName("\u{2018}Fix Tests\u{2019}") == "Fix Tests")
    }

    @Test("Strips trailing period")
    func stripsTrailingPeriod() {
        #expect(sanitizeName("Fix tests.") == "Fix Tests")
    }

    @Test("Uses first non-empty line when output has multiple lines")
    func firstNonEmptyLine() {
        #expect(sanitizeName("\nFix tests\nSome other line") == "Fix Tests")
    }

    @Test("Returns nil for empty input")
    func emptyInput() {
        #expect(sanitizeName("") == nil)
    }

    @Test("Returns nil for whitespace-only input")
    func whitespaceOnly() {
        #expect(sanitizeName("   \n  ") == nil)
    }

    @Test("Returns nil for input that is only strippable characters")
    func onlyStrippableCharacters() {
        #expect(sanitizeName("\"\"\"") == nil)
    }

    @Test("Caps output at 40 characters")
    func capsAt40Characters() {
        let long = String(repeating: "A", count: 50)
        let result = sanitizeName(long)
        #expect(result?.count == 40)
    }

    @Test("Trims whitespace after truncation")
    func trimsAfterTruncation() {
        // 39 Xs followed by a space and more chars — truncation at 40 yields trailing space
        let input = String(repeating: "X", count: 39) + " extra"
        let result = sanitizeName(input)
        #expect(result?.last != " ")
    }
}
