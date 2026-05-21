import ApplicationServices
import Foundation

@MainActor
enum AccessibilityPermissionController {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessPrompt() -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary

        return AXIsProcessTrustedWithOptions(options)
    }

    static var statusText: String {
        isTrusted ? "已开启" : "未开启"
    }
}
