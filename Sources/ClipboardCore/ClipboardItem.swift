import Foundation

public enum ClipboardItemType: String, Codable, Equatable, Sendable {
    case text
    case image
}

public struct ClipboardItem: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let type: ClipboardItemType
    public var createdAt: Date
    public var textContent: String?
    public var textPreview: String
    public var imagePath: String?
    public var contentHash: String
    public var isPinned: Bool
    public var pinShortcut: Int?

    public init(
        id: UUID = UUID(),
        type: ClipboardItemType,
        createdAt: Date,
        textContent: String? = nil,
        textPreview: String,
        imagePath: String? = nil,
        contentHash: String,
        isPinned: Bool = false,
        pinShortcut: Int? = nil
    ) {
        self.id = id
        self.type = type
        self.createdAt = createdAt
        self.textContent = textContent
        self.textPreview = textPreview
        self.imagePath = imagePath
        self.contentHash = contentHash
        self.isPinned = isPinned
        self.pinShortcut = pinShortcut
    }
}

public enum ClipboardStoreError: Error, Equatable {
    case invalidShortcut
    case itemNotFound
}
