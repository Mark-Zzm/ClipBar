import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var didConfigure = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configure(with: AppState.shared)
        AppState.shared.start()
    }

    func configure(with appState: AppState) {
        guard !didConfigure else {
            return
        }
        didConfigure = true

        let controller = StatusBarController(appState: appState)
        statusBarController = controller
        appState.panelController = controller
    }
}
