import AppKit
import Carbon
import Foundation

struct KeyCombo: Codable, Equatable, Identifiable {
    var id: String { rawValue }

    let keyCode: UInt32
    let modifiers: UInt32
    let keyName: String

    var rawValue: String {
        "\(keyCode):\(modifiers):\(keyName)"
    }

    init(keyCode: UInt32, modifiers: UInt32, keyName: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = keyName
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]) else {
            return nil
        }
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyName = parts[2]
    }

    var display: String {
        "\(modifierDisplay)\(keyName)"
    }

    var totalKeyCount: Int {
        modifierCount + 1
    }

    func matches(_ event: NSEvent) -> Bool {
        UInt32(event.keyCode) == keyCode
            && Self.carbonModifiers(from: event.modifierFlags) == modifiers
    }

    static func defaultPanelHotKey() -> KeyCombo {
        KeyCombo(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey),
            keyName: "Space"
        )
    }

    static func defaultPinnedShortcut(_ number: Int) -> KeyCombo {
        KeyCombo(
            keyCode: UInt32(kVK_ANSI_1 + max(0, min(8, number - 1))),
            modifiers: UInt32(optionKey),
            keyName: "\(number)"
        )
    }

    static func from(event: NSEvent) -> KeyCombo? {
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let modifierCount = Self.modifierCount(modifiers)
        guard modifierCount <= 2,
              let keyName = keyName(for: UInt32(event.keyCode), fallback: event.charactersIgnoringModifiers),
              !keyName.isEmpty else {
            return nil
        }

        let combo = KeyCombo(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyName: keyName
        )
        return combo.totalKeyCount <= 3 ? combo : nil
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if flags.contains(.option) {
            result |= UInt32(optionKey)
        }
        if flags.contains(.control) {
            result |= UInt32(controlKey)
        }
        if flags.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        return result
    }

    private var modifierDisplay: String {
        var result = ""
        if modifiers & UInt32(controlKey) != 0 {
            result += "⌃"
        }
        if modifiers & UInt32(optionKey) != 0 {
            result += "⌥"
        }
        if modifiers & UInt32(shiftKey) != 0 {
            result += "⇧"
        }
        if modifiers & UInt32(cmdKey) != 0 {
            result += "⌘"
        }
        return result
    }

    private var modifierCount: Int {
        Self.modifierCount(modifiers)
    }

    private static func modifierCount(_ modifiers: UInt32) -> Int {
        [
            UInt32(controlKey),
            UInt32(optionKey),
            UInt32(shiftKey),
            UInt32(cmdKey)
        ].filter { modifiers & $0 != 0 }.count
    }

    private static func keyName(for keyCode: UInt32, fallback: String?) -> String? {
        switch Int(keyCode) {
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Escape:
            return "Esc"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Delete"
        default:
            if let fallback,
               let first = fallback.uppercased().first {
                return String(first)
            }
            return nil
        }
    }
}
