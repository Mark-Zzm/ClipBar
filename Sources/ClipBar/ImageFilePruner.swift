import ClipboardCore
import Foundation

enum ImageFilePruner {
    static func removeFiles(for items: [ClipboardItem]) {
        for item in items where item.type == .image {
            guard let path = item.imagePath else {
                continue
            }
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
