import Foundation
import Testing
@testable import CmdV

struct PasteStackTests {
    private func capture(_ text: String) -> ClipboardCapture {
        ClipboardCapture(
            types: ["public.utf8-plain-text"],
            plainText: text,
            rtfData: nil,
            htmlString: nil,
            imageData: nil,
            imageIsPNG: false,
            fileURLs: [],
            sourceAppBundleID: nil,
            capturedAt: Date()
        )
    }

    @Test func pastesInCopyOrder() {
        var queue = PasteStackQueue()
        queue.append(capture("one"))
        queue.append(capture("two"))
        queue.append(capture("three"))
        #expect(queue.next()?.capture.plainText == "one")
        #expect(queue.next()?.capture.plainText == "two")
        #expect(queue.next()?.capture.plainText == "three")
        #expect(queue.next() == nil)
    }

    @Test func reverseFlipsOrder() {
        var queue = PasteStackQueue()
        queue.append(capture("one"))
        queue.append(capture("two"))
        queue.toggleReversed()
        #expect(queue.next()?.capture.plainText == "two")
        queue.toggleReversed()
        #expect(queue.next()?.capture.plainText == "one")
    }

    @Test func pasteOrderReflectsReversal() {
        var queue = PasteStackQueue()
        queue.append(capture("one"))
        queue.append(capture("two"))
        #expect(queue.pasteOrder.map(\.capture.plainText) == ["one", "two"])
        queue.toggleReversed()
        #expect(queue.pasteOrder.map(\.capture.plainText) == ["two", "one"])
    }

    @Test func removeDeletesEntry() {
        var queue = PasteStackQueue()
        queue.append(capture("keep"))
        queue.append(capture("drop"))
        let dropID = queue.entries[1].id
        queue.remove(id: dropID)
        #expect(queue.count == 1)
        #expect(queue.next()?.capture.plainText == "keep")
    }

    @Test func labelsAreDerivedFromContent() {
        var queue = PasteStackQueue()
        queue.append(capture("  hello world  "))
        #expect(queue.entries[0].label == "hello world")
        #expect(queue.entries[0].kind == .text)
    }

    @Test func clearEmptiesAndResetsOrder() {
        var queue = PasteStackQueue()
        queue.append(capture("x"))
        queue.toggleReversed()
        queue.clear()
        #expect(queue.isEmpty)
        #expect(!queue.isReversed)
    }
}
