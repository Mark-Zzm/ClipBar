import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLoginController {
    static func setEnabled(_ enabled: Bool) {
        guard Bundle.main.bundleIdentifier != nil else {
            return
        }

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                UserDefaults.standard.set(false, forKey: "launchAtLoginEnabled")
            }
        }
    }

    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
