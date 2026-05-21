import Foundation

public protocol ClipboardStorage {
    func loadItems() throws -> [ClipboardItem]
    func saveItems(_ items: [ClipboardItem]) throws
}

public final class InMemoryClipboardStorage: ClipboardStorage {
    private var savedItems: [ClipboardItem]

    public init(items: [ClipboardItem] = []) {
        self.savedItems = items
    }

    public func loadItems() throws -> [ClipboardItem] {
        savedItems
    }

    public func saveItems(_ items: [ClipboardItem]) throws {
        savedItems = items
    }
}

public final class JSONClipboardStorage: ClipboardStorage {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadItems() throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([ClipboardItem].self, from: data)
    }

    public func saveItems(_ items: [ClipboardItem]) throws {
        let folder = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public extension JSONClipboardStorage {
    static func appDefault(appName: String = "ClipBar") -> JSONClipboardStorage {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = base
            .appendingPathComponent(appName, isDirectory: true)
            .appendingPathComponent("clipboard-items.json")
        return JSONClipboardStorage(fileURL: fileURL)
    }
}
