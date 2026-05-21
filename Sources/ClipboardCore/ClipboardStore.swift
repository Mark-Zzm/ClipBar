import Foundation
import Combine

@MainActor
public final class ClipboardStore: ObservableObject {
    @Published public private(set) var items: [ClipboardItem]

    private let storage: ClipboardStorage
    private let onItemsRemoved: ([ClipboardItem]) -> Void
    private var limit: Int

    public init(
        storage: ClipboardStorage,
        limit: Int = 1000,
        onItemsRemoved: @escaping ([ClipboardItem]) -> Void = { _ in }
    ) {
        self.storage = storage
        self.onItemsRemoved = onItemsRemoved
        self.limit = max(1, limit)
        self.items = (try? storage.loadItems()) ?? []
        sortNewestFirst()
    }

    public func setLimit(_ newLimit: Int) throws {
        limit = max(1, newLimit)
        try enforceLimitAndSave()
    }

    @discardableResult
    public func addText(
        _ text: String,
        createdAt: Date = Date()
    ) throws -> ClipboardItem {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return items.first ?? ClipboardItem(
                type: .text,
                createdAt: createdAt,
                textPreview: "",
                contentHash: ""
            )
        }

        let hash = ClipboardHasher.hash(normalized)
        if items.first?.contentHash == hash {
            return items[0]
        }

        let item = ClipboardItem(
            type: .text,
            createdAt: createdAt,
            textContent: text,
            textPreview: Self.preview(for: text),
            contentHash: hash
        )
        items.insert(item, at: 0)
        try enforceLimitAndSave()
        return item
    }

    @discardableResult
    public func addImage(
        imagePath: String,
        contentHash: String,
        createdAt: Date = Date()
    ) throws -> ClipboardItem {
        if items.first?.contentHash == contentHash {
            return items[0]
        }

        let item = ClipboardItem(
            type: .image,
            createdAt: createdAt,
            textPreview: "Image",
            imagePath: imagePath,
            contentHash: contentHash
        )
        items.insert(item, at: 0)
        try enforceLimitAndSave()
        return item
    }

    public func search(_ query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return items
        }

        return items.filter { item in
            guard item.type == .text else {
                return false
            }

            return item.textContent?.localizedCaseInsensitiveContains(trimmed) == true
                || item.textPreview.localizedCaseInsensitiveContains(trimmed)
        }
    }

    public func pin(itemID: UUID, shortcut: Int) throws {
        guard (1...9).contains(shortcut) else {
            throw ClipboardStoreError.invalidShortcut
        }
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw ClipboardStoreError.itemNotFound
        }

        for candidate in items.indices where items[candidate].pinShortcut == shortcut {
            items[candidate].isPinned = false
            items[candidate].pinShortcut = nil
        }

        items[index].isPinned = true
        items[index].pinShortcut = shortcut
        try persist()
    }

    public func reorderPinnedItems(from source: Int, to destination: Int) throws {
        var pinned = pinnedItems()
        guard pinned.indices.contains(source) else {
            return
        }

        let item = pinned.remove(at: source)
        let insertionIndex = min(max(destination, 0), pinned.count)
        pinned.insert(item, at: insertionIndex)

        for (offset, pinnedItem) in pinned.enumerated() {
            guard let index = items.firstIndex(where: { $0.id == pinnedItem.id }) else {
                continue
            }
            items[index].isPinned = true
            items[index].pinShortcut = offset + 1
        }

        try persist()
    }

    public func unpin(itemID: UUID) throws {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            throw ClipboardStoreError.itemNotFound
        }

        items[index].isPinned = false
        items[index].pinShortcut = nil
        try persist()
    }

    public func delete(itemID: UUID) throws {
        let removed = items.filter { $0.id == itemID }
        items.removeAll { $0.id == itemID }
        onItemsRemoved(removed)
        try persist()
    }

    public func clearHistoryKeepingPinned() throws {
        let removed = items.filter { !$0.isPinned }
        items = items.filter(\.isPinned)
        sortNewestFirst()
        onItemsRemoved(removed)
        try persist()
    }

    public func pinnedItems() -> [ClipboardItem] {
        items
            .filter(\.isPinned)
            .sorted { ($0.pinShortcut ?? 99) < ($1.pinShortcut ?? 99) }
    }

    public func item(forShortcut shortcut: Int) -> ClipboardItem? {
        items.first { $0.pinShortcut == shortcut }
    }

    private func enforceLimitAndSave() throws {
        let pinned = items.filter(\.isPinned)
        let unpinned = items.filter { !$0.isPinned }
        let keptUnpinned = Array(unpinned.prefix(limit))
        let removed = Array(unpinned.dropFirst(limit))
        items = keptUnpinned + pinned
        sortNewestFirstKeepingPinnedShortcuts()
        onItemsRemoved(removed)
        try persist()
    }

    private func sortNewestFirst() {
        items.sort { $0.createdAt > $1.createdAt }
    }

    private func sortNewestFirstKeepingPinnedShortcuts() {
        items.sort {
            if $0.createdAt == $1.createdAt {
                return ($0.pinShortcut ?? 99) < ($1.pinShortcut ?? 99)
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func persist() throws {
        try storage.saveItems(items)
    }

    private static func preview(for text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        if collapsed.count <= 120 {
            return collapsed
        }

        return String(collapsed.prefix(120)) + "..."
    }
}

enum ClipboardHasher {
    static func hash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
