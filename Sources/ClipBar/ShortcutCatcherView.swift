import AppKit
import SwiftUI

struct ShortcutCatcherView: NSViewRepresentable {
    @EnvironmentObject private var appState: AppState

    func makeNSView(context: Context) -> KeyCatchingNSView {
        let view = KeyCatchingNSView()
        view.onKeyDown = { event in
            handle(event)
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: KeyCatchingNSView, context: Context) {
        nsView.onKeyDown = { event in
            handle(event)
        }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        for slot in 1...9 {
            guard let combo = appState.shortcutCombo(forPinnedSlot: slot),
                  combo.matches(event) else {
                continue
            }
            appState.reusePinnedShortcut(slot)
            return true
        }
        return false
    }
}

final class KeyCatchingNSView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true {
            return
        }
        super.keyDown(with: event)
    }
}
