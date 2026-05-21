import AppKit
import SwiftUI

@MainActor
protocol PanelControlling: AnyObject {
    func togglePanel()
    func closePanel()
}

@MainActor
final class StatusBarController: NSObject, PanelControlling, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipBar")
            button.action = #selector(togglePanelFromButton)
            button.target = self
        }

        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 720, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPanelView()
                .environmentObject(appState)
                .frame(width: 720, height: 500)
        )
    }

    func togglePanel() {
        if popover.isShown {
            closePanel()
        } else {
            showPanel()
        }
    }

    func closePanel() {
        popover.performClose(nil)
    }

    private func showPanel() {
        captureTargetApplication()
        guard let button = statusItem.button else {
            return
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func captureTargetApplication() {
        appState.captureCurrentFrontmostApplication()
    }

    @objc private func togglePanelFromButton() {
        togglePanel()
    }
}
