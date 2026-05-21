import ClipboardCore
import Foundation

@MainActor
func runChecks() throws {
    try checkDuplicateTextIsSkipped()
    try checkSearchTextOnlyNewestFirst()
    try checkLimitPrunesOldestUnpinned()
    try checkPinShortcutValidation()
    try checkClearHistoryKeepsPinned()
}

@MainActor
func checkDuplicateTextIsSkipped() throws {
    let store = ClipboardStore(storage: InMemoryClipboardStorage(), limit: 1000)
    try store.addText("Hello", createdAt: Date(timeIntervalSince1970: 1))
    try store.addText("Hello", createdAt: Date(timeIntervalSince1970: 2))
    expect(store.items.count == 1, "duplicate text should be skipped")
    expect(store.items.first?.textContent == "Hello", "first text should be Hello")
}

@MainActor
func checkSearchTextOnlyNewestFirst() throws {
    let store = ClipboardStore(storage: InMemoryClipboardStorage(), limit: 1000)
    try store.addText("Invoice header", createdAt: Date(timeIntervalSince1970: 1))
    try store.addImage(
        imagePath: "/tmp/shot.png",
        contentHash: "image-1",
        createdAt: Date(timeIntervalSince1970: 2)
    )
    try store.addText("Meeting invoice notes", createdAt: Date(timeIntervalSince1970: 3))

    let results = store.search("invoice")
    expect(
        results.map(\.textContent) == ["Meeting invoice notes", "Invoice header"],
        "search should match text records newest first"
    )
}

@MainActor
func checkLimitPrunesOldestUnpinned() throws {
    let store = ClipboardStore(storage: InMemoryClipboardStorage(), limit: 2)
    let first = try store.addText("one", createdAt: Date(timeIntervalSince1970: 1))
    try store.pin(itemID: first.id, shortcut: 1)
    try store.addText("two", createdAt: Date(timeIntervalSince1970: 2))
    try store.addText("three", createdAt: Date(timeIntervalSince1970: 3))
    try store.addText("four", createdAt: Date(timeIntervalSince1970: 4))

    expect(store.items.map(\.textContent) == ["four", "three", "one"], "limit should prune oldest unpinned")
    expect(store.items.last?.isPinned == true, "pinned item should survive pruning")
}

@MainActor
func checkPinShortcutValidation() throws {
    let store = ClipboardStore(storage: InMemoryClipboardStorage(), limit: 1000)
    let item = try store.addText("Pinned", createdAt: Date())

    do {
        try store.pin(itemID: item.id, shortcut: 10)
        throw CheckFailure("shortcut 10 should fail")
    } catch ClipboardStoreError.invalidShortcut {
    }

    try store.pin(itemID: item.id, shortcut: 9)
    expect(store.items.first?.pinShortcut == 9, "shortcut 9 should be accepted")
}

@MainActor
func checkClearHistoryKeepsPinned() throws {
    let store = ClipboardStore(storage: InMemoryClipboardStorage(), limit: 1000)
    let pinned = try store.addText("Address", createdAt: Date(timeIntervalSince1970: 1))
    try store.pin(itemID: pinned.id, shortcut: 1)
    try store.addText("Temporary", createdAt: Date(timeIntervalSince1970: 2))

    try store.clearHistoryKeepingPinned()

    expect(store.items.count == 1, "clear should keep one pinned item")
    expect(store.items.first?.textContent == "Address", "pinned content should remain")
    expect(store.items.first?.pinShortcut == 1, "pinned shortcut should remain")
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

do {
    try await MainActor.run {
        try runChecks()
    }
    print("CoreChecks passed")
} catch {
    fputs("CoreChecks failed: \(error)\n", stderr)
    exit(1)
}
