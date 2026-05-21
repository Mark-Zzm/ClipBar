import AppKit
import ApplicationServices
import ClipboardCore
import Foundation

@MainActor
final class PasteController {
    func reuse(
        _ item: ClipboardItem,
        pasteAction: PasteAction,
        targetApplication: NSRunningApplication?,
        completion: @escaping (PasteResult) -> Void
    ) {
        guard copyToPasteboard(item) else {
            completion(PasteResult(message: "无法复用这条记录"))
            return
        }

        guard pasteAction == .pasteToFrontmostApp else {
            completion(PasteResult(message: "已复制到剪切板"))
            return
        }

        guard let targetApplication else {
            completion(PasteResult(message: "已复制到剪切板；未识别到唤起前的目标 App"))
            return
        }

        let targetName = targetApplication.localizedName ?? "目标 App"
        NSApp.hide(nil)
        targetApplication.unhide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            targetApplication.activate(options: [.activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard self.isFrontmost(targetApplication) else {
                let currentName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知 App"
                completion(PasteResult(message: "已复制到剪切板；目标未激活（当前：\(currentName)，目标：\(targetName)）"))
                return
            }

            if let automationError = self.sendPasteShortcutWithSystemEvents(to: targetApplication) {
                guard AccessibilityPermissionController.isTrusted else {
                    AccessibilityPermissionController.requestAccessPrompt()
                    completion(PasteResult(message: "已复制到剪切板；直接粘贴需要重新允许辅助功能权限"))
                    return
                }

                self.sendPasteShortcutWithCGEvent()
                completion(PasteResult(message: "已向 \(targetName) 发送备用粘贴；自动化失败：\(automationError)"))
                return
            }

            completion(PasteResult(message: "已向 \(targetName) 发送粘贴"))
        }
    }

    private func copyToPasteboard(_ item: ClipboardItem) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            guard let text = item.textContent else {
                return false
            }
            return pasteboard.setString(text, forType: .string)
        case .image:
            guard let path = item.imagePath,
                  let image = NSImage(contentsOfFile: path) else {
                return false
            }
            return pasteboard.writeObjects([image])
        }
    }

    private func sendPasteShortcutWithSystemEvents(to application: NSRunningApplication) -> String? {
        let activateCommand: String
        if let bundleIdentifier = application.bundleIdentifier {
            activateCommand = "tell application id \"\(bundleIdentifier)\" to activate"
        } else {
            activateCommand = ""
        }

        let source = """
        \(activateCommand)
        delay 0.08
        tell application "System Events" to keystroke "v" using command down
        """

        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error?[NSAppleScript.errorMessage] as? String
    }

    private func sendPasteShortcutWithCGEvent() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func isFrontmost(_ application: NSRunningApplication) -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            return false
        }

        if frontmost.processIdentifier == application.processIdentifier {
            return true
        }

        guard let expectedBundleIdentifier = application.bundleIdentifier,
              let currentBundleIdentifier = frontmost.bundleIdentifier else {
            return false
        }

        return expectedBundleIdentifier == currentBundleIdentifier
    }
}

struct PasteResult {
    let message: String
}
