import Foundation
import Testing
@testable import CmdV

struct ItemClassifierTests {
    @Test func fileURLsWinOverEverything() {
        let kind = ItemClassifier.classify(
            plainText: "https://example.com",
            hasImage: true,
            fileURLs: [URL(fileURLWithPath: "/tmp/x.txt")]
        )
        #expect(kind == .file)
    }

    @Test func imageWinsOverText() {
        let kind = ItemClassifier.classify(plainText: "screenshot", hasImage: true, fileURLs: [])
        #expect(kind == .image)
    }

    @Test(arguments: ["#fff", "#FFAA00", "#ffaa0080", "rgb(255, 0, 128)", "rgba(0,0,0,0.5)"])
    func colorsAreDetected(text: String) {
        #expect(ItemClassifier.classify(plainText: text, hasImage: false, fileURLs: []) == .color)
    }

    @Test(arguments: ["#nothex", "rgb(300)", "fff", "# fff"])
    func nonColorsAreNotColors(text: String) {
        #expect(ItemClassifier.classify(plainText: text, hasImage: false, fileURLs: []) != .color)
    }

    @Test(arguments: ["https://example.com", "http://a.io/path?q=1", "https://sub.domain.dev/x#y"])
    func linksAreDetected(text: String) {
        #expect(ItemClassifier.classify(plainText: text, hasImage: false, fileURLs: []) == .link)
    }

    @Test(arguments: [
        "visit https://example.com today",
        "example.com",
        "not a url at all",
    ])
    func proseWithURLsIsText(text: String) {
        #expect(ItemClassifier.classify(plainText: text, hasImage: false, fileURLs: []) == .text)
    }

    @Test func swiftCodeIsDetected() {
        let code = """
        func greet(name: String) -> String {
            return "Hello, \\(name)"
        }
        """
        #expect(ItemClassifier.classify(plainText: code, hasImage: false, fileURLs: []) == .code)
    }

    @Test func pythonCodeIsDetected() {
        let code = """
        def add(a, b):
            return a + b
        """
        #expect(ItemClassifier.classify(plainText: code, hasImage: false, fileURLs: []) == .code)
    }

    @Test func plainProseIsText() {
        let prose = """
        Dear team,
        The meeting has been moved to Thursday.
        Best regards
        """
        #expect(ItemClassifier.classify(plainText: prose, hasImage: false, fileURLs: []) == .text)
    }
}
