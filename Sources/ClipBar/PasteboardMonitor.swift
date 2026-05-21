import AppKit
import ClipboardCore
import CryptoKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private let store: ClipboardStore
    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private let imageFolder: URL

    init(store: ClipboardStore, pasteboard: NSPasteboard = .general) {
        self.store = store
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount

        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.imageFolder = base
            .appendingPathComponent("ClipBar", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
    }

    func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string) {
            _ = try? store.addText(text)
            return
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let data = image.tiffRepresentation else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: imageFolder,
                withIntermediateDirectories: true
            )
            let hash = Self.hash(data)
            let fileURL = imageFolder.appendingPathComponent("\(hash).tiff")
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: [.atomic])
            }
            try store.addImage(imagePath: fileURL.path, contentHash: hash)
        } catch {
            // Clipboard capture should never interrupt the user's current app.
        }
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
