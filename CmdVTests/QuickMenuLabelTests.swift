import Testing
@testable import CmdV

@Suite("QuickMenuLabel")
struct QuickMenuLabelTests {
    @Test func titleWinsOverText() {
        let label = QuickMenuLabel.label(
            title: "My snippet", plainText: "actual content", fileNames: [], fallback: "Text")
        #expect(label == "My snippet")
    }

    @Test func blankTitleFallsThroughToText() {
        let label = QuickMenuLabel.label(
            title: "   \n ", plainText: "hello world", fileNames: [], fallback: "Text")
        #expect(label == "hello world")
    }

    @Test func firstLineOnlyAndTrimmed() {
        let label = QuickMenuLabel.label(
            title: nil, plainText: "  first line  \nsecond line", fileNames: [], fallback: "Text")
        #expect(label == "first line")
    }

    @Test func longTextIsTruncatedWithEllipsis() {
        let long = String(repeating: "a", count: 120)
        let label = QuickMenuLabel.label(title: nil, plainText: long, fileNames: [], fallback: "Text")
        #expect(label.count == QuickMenuLabel.maxLength)
        #expect(label.hasSuffix("…"))
    }

    @Test func exactLimitIsNotTruncated() {
        let exact = String(repeating: "b", count: QuickMenuLabel.maxLength)
        let label = QuickMenuLabel.label(title: nil, plainText: exact, fileNames: [], fallback: "Text")
        #expect(label == exact)
    }

    @Test func fileNamesJoined() {
        let label = QuickMenuLabel.label(
            title: nil, plainText: nil, fileNames: ["a.png", "b.png"], fallback: "File")
        #expect(label == "a.png, b.png")
    }

    @Test func fallbackWhenNothingUsable() {
        let label = QuickMenuLabel.label(
            title: nil, plainText: "  \n  ", fileNames: [], fallback: "Image 800×600")
        #expect(label == "Image 800×600")
    }
}
