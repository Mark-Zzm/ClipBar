import AppKit
import SwiftUI

struct KeyRecorderView: NSViewRepresentable {
    @Binding var combo: KeyCombo
    var label: String

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.label = label
        view.combo = combo
        view.onComplete = { combo in
            self.combo = combo
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.label = label
        nsView.combo = combo
        nsView.onComplete = { combo in
            self.combo = combo
        }
    }
}

final class KeyRecorderNSView: NSView {
    var onComplete: ((KeyCombo) -> Void)?
    var label: String = "" {
        didSet { needsDisplay = true }
    }
    var combo: KeyCombo = .defaultPanelHotKey() {
        didSet { needsDisplay = true }
    }

    private var isRecording = false
    private var candidate: KeyCombo?
    private var pressedKeyCodes = Set<UInt16>()

    override var acceptsFirstResponder: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 180, height: 32)
    }

    override func mouseDown(with event: NSEvent) {
        startRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        pressedKeyCodes.insert(event.keyCode)
        if let combo = KeyCombo.from(event: event) {
            candidate = combo
        }
        needsDisplay = true
    }

    override func keyUp(with event: NSEvent) {
        guard isRecording else {
            super.keyUp(with: event)
            return
        }

        pressedKeyCodes.remove(event.keyCode)
        completeIfAllKeysReleased(event.modifierFlags)
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }

        completeIfAllKeysReleased(event.modifierFlags)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()

        let text = isRecording ? "按下组合键，全部松开完成" : "\(label)：\(combo.display)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: isRecording ? .medium : .regular),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(
            x: max(10, (bounds.width - size.width) / 2),
            y: (bounds.height - size.height) / 2
        )
        text.draw(at: point, withAttributes: attributes)
    }

    private func startRecording() {
        isRecording = true
        candidate = nil
        pressedKeyCodes.removeAll()
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    private func completeIfAllKeysReleased(_ flags: NSEvent.ModifierFlags) {
        let activeModifiers = flags.intersection([.command, .option, .control, .shift])
        guard pressedKeyCodes.isEmpty,
              activeModifiers.isEmpty,
              let candidate else {
            return
        }

        isRecording = false
        combo = candidate
        onComplete?(candidate)
        self.candidate = nil
        needsDisplay = true
    }
}
