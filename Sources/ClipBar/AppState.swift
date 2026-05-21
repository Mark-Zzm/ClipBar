import AppKit
import Carbon
import ClipboardCore
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var store: ClipboardStore
    @Published var selectedFilter: ClipboardFilter = .all
    @Published var statusMessage: String = ""
    @Published var pasteAction: PasteAction {
        didSet {
            UserDefaults.standard.set(pasteAction.rawValue, forKey: Self.pasteActionKey)
        }
    }
    @Published var launchAtLoginEnabled: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLoginEnabled, forKey: Self.launchAtLoginKey)
            LaunchAtLoginController.setEnabled(launchAtLoginEnabled)
        }
    }
    @Published var storageLimit: Int {
        didSet {
            UserDefaults.standard.set(storageLimit, forKey: Self.storageLimitKey)
            try? store.setLimit(storageLimit)
        }
    }
    @Published var pinnedShortcutStyle: ShortcutStyle {
        didSet {
            UserDefaults.standard.set(pinnedShortcutStyle.rawValue, forKey: Self.pinnedShortcutStyleKey)
        }
    }
    @Published var panelHotKeyMode: HotKeyMode {
        didSet {
            UserDefaults.standard.set(panelHotKeyMode.rawValue, forKey: Self.panelHotKeyModeKey)
            registerPanelHotKey()
        }
    }
    @Published var panelCustomHotKey: KeyCombo {
        didSet {
            UserDefaults.standard.set(panelCustomHotKey.rawValue, forKey: Self.panelCustomHotKeyKey)
            registerPanelHotKey()
        }
    }
    @Published var pinnedCustomHotKeys: [Int: KeyCombo] {
        didSet {
            persistPinnedCustomHotKeys()
        }
    }
    @Published var lastTargetApplication: NSRunningApplication?

    private static let pasteActionKey = "pasteAction"
    private static let launchAtLoginKey = "launchAtLoginEnabled"
    private static let storageLimitKey = "storageLimit"
    private static let pinnedShortcutStyleKey = "pinnedShortcutStyle"
    private static let panelHotKeyModeKey = "panelHotKeyMode"
    private static let panelCustomHotKeyKey = "panelCustomHotKey"
    private static let pinnedCustomHotKeysKey = "pinnedCustomHotKeys"
    private static let storageAppName = Bundle.main.object(
        forInfoDictionaryKey: "ClipBarStorageAppName"
    ) as? String ?? "ClipBar"

    private let monitor: PasteboardMonitor
    private let pasteController = PasteController()
    private let settingsWindowController = SettingsWindowController()
    private var activationObserver: NSObjectProtocol?
    weak var panelController: PanelControlling? {
        didSet {
            globalHotKeyController?.onPressed = { [weak self] in
                self?.captureCurrentFrontmostApplication()
                self?.panelController?.togglePanel()
            }
        }
    }
    private var globalHotKeyController: GlobalHotKeyController?
    private var didStart = false

    private init() {
        let limit = UserDefaults.standard.object(forKey: Self.storageLimitKey) as? Int ?? 1000
        let storedPasteAction = UserDefaults.standard.string(forKey: Self.pasteActionKey)
            .flatMap(PasteAction.init(rawValue:)) ?? .pasteToFrontmostApp
        let storedShortcutStyle = UserDefaults.standard.string(forKey: Self.pinnedShortcutStyleKey)
            .flatMap(ShortcutStyle.init(rawValue:)) ?? .optionNumber
        let storedPanelHotKeyMode = UserDefaults.standard.string(forKey: Self.panelHotKeyModeKey)
            .flatMap(HotKeyMode.init(rawValue:)) ?? .preset
        let storedPanelCustomHotKey = UserDefaults.standard.string(forKey: Self.panelCustomHotKeyKey)
            .flatMap(KeyCombo.init(rawValue:)) ?? KeyCombo.defaultPanelHotKey()
        let store = ClipboardStore(
            storage: JSONClipboardStorage.appDefault(appName: Self.storageAppName),
            limit: limit,
            onItemsRemoved: ImageFilePruner.removeFiles
        )
        self.store = store
        self.monitor = PasteboardMonitor(store: store)
        self.storageLimit = limit
        self.pasteAction = storedPasteAction
        self.launchAtLoginEnabled = UserDefaults.standard.bool(forKey: Self.launchAtLoginKey)
        self.pinnedShortcutStyle = storedShortcutStyle
        self.panelHotKeyMode = storedPanelHotKeyMode
        self.panelCustomHotKey = storedPanelCustomHotKey
        self.pinnedCustomHotKeys = Self.loadPinnedCustomHotKeys()
    }

    func start() {
        guard !didStart else {
            return
        }
        didStart = true
        monitor.start()
        startTrackingFrontmostApplications()
        let hotKeyController = GlobalHotKeyController()
        hotKeyController.onPressed = { [weak self] in
            self?.captureCurrentFrontmostApplication()
            self?.panelController?.togglePanel()
        }
        globalHotKeyController = hotKeyController
        registerPanelHotKey()
    }

    func displayedItems(searchText: String) -> [ClipboardItem] {
        let base = store.search(searchText)
        switch selectedFilter {
        case .all:
            return base
        case .text:
            return base.filter { $0.type == .text }
        case .images:
            return searchText.isEmpty ? store.items.filter { $0.type == .image } : []
        case .pinned:
            return base.filter(\.isPinned)
        }
    }

    func reuse(_ item: ClipboardItem) {
        let targetApplication = lastTargetApplication ?? currentNonClipBarFrontmostApplication()
        if pasteAction == .pasteToFrontmostApp {
            panelController?.closePanel()
        }

        pasteController.reuse(
            item,
            pasteAction: pasteAction,
            targetApplication: targetApplication
        ) { [weak self] result in
            self?.statusMessage = result.message
        }
    }

    func togglePin(_ item: ClipboardItem) {
        do {
            if item.isPinned {
                try store.unpin(itemID: item.id)
                statusMessage = "已取消固定"
                return
            }

            guard let shortcut = nextAvailableShortcut() else {
                statusMessage = "最多只能固定 9 条常用内容"
                return
            }

            try store.pin(itemID: item.id, shortcut: shortcut)
            statusMessage = "已固定到快捷键 \(shortcut)"
        } catch {
            statusMessage = "固定失败"
        }
    }

    func pin(_ item: ClipboardItem, toSlot slot: Int) {
        do {
            try store.pin(itemID: item.id, shortcut: slot)
            statusMessage = "已固定到位置 \(slot)"
        } catch {
            statusMessage = "固定失败"
        }
    }

    func reorderPinned(from source: Int, to destination: Int) {
        do {
            try store.reorderPinnedItems(from: source, to: destination)
            statusMessage = "固定内容顺序已更新"
        } catch {
            statusMessage = "调整顺序失败"
        }
    }

    func delete(_ item: ClipboardItem) {
        do {
            try store.delete(itemID: item.id)
            statusMessage = "已删除"
        } catch {
            statusMessage = "删除失败"
        }
    }

    func clearHistory() {
        do {
            try store.clearHistoryKeepingPinned()
            statusMessage = "已清空普通历史，固定内容保留"
        } catch {
            statusMessage = "清空失败"
        }
    }

    func reusePinnedShortcut(_ shortcut: Int) {
        guard let item = store.item(forShortcut: shortcut) else {
            statusMessage = "快捷键 \(shortcut) 还没有固定内容"
            return
        }
        reuse(item)
    }

    func shortcutCombo(forPinnedSlot slot: Int) -> KeyCombo? {
        switch pinnedShortcutStyle {
        case .custom:
            return pinnedCustomHotKeys[slot]
        case .disabled:
            return nil
        default:
            return pinnedShortcutStyle.combo(for: slot)
        }
    }

    func shortcutDisplay(forPinnedSlot slot: Int) -> String {
        shortcutCombo(forPinnedSlot: slot)?.display ?? "\(slot)"
    }

    func setCustomPinnedHotKey(_ combo: KeyCombo, forSlot slot: Int) {
        pinnedCustomHotKeys[slot] = combo
    }

    func showSettings() {
        settingsWindowController.show(appState: self)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func captureCurrentFrontmostApplication() {
        guard let frontmost = currentNonClipBarFrontmostApplication() else {
            return
        }
        lastTargetApplication = frontmost
    }

    private func currentNonClipBarFrontmostApplication() -> NSRunningApplication? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }
        return frontmost
    }

    private func startTrackingFrontmostApplications() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                return
            }
            Task { @MainActor in
                self?.lastTargetApplication = app
            }
        }
    }

    private func registerPanelHotKey() {
        guard let globalHotKeyController else {
            return
        }
        switch panelHotKeyMode {
        case .preset:
            globalHotKeyController.register(combo: KeyCombo.defaultPanelHotKey())
        case .custom:
            globalHotKeyController.register(combo: panelCustomHotKey)
        case .disabled:
            globalHotKeyController.register(combo: nil)
        }
    }

    private func persistPinnedCustomHotKeys() {
        let encoded = Dictionary(uniqueKeysWithValues: pinnedCustomHotKeys.map { (String($0.key), $0.value.rawValue) })
        UserDefaults.standard.set(encoded, forKey: Self.pinnedCustomHotKeysKey)
    }

    private static func loadPinnedCustomHotKeys() -> [Int: KeyCombo] {
        guard let stored = UserDefaults.standard.dictionary(forKey: pinnedCustomHotKeysKey) as? [String: String] else {
            return Dictionary(uniqueKeysWithValues: (1...9).map { ($0, KeyCombo.defaultPinnedShortcut($0)) })
        }

        var result: [Int: KeyCombo] = [:]
        for (key, value) in stored {
            guard let slot = Int(key),
                  let combo = KeyCombo(rawValue: value) else {
                continue
            }
            result[slot] = combo
        }

        for slot in 1...9 where result[slot] == nil {
            result[slot] = KeyCombo.defaultPinnedShortcut(slot)
        }
        return result
    }

    private func nextAvailableShortcut() -> Int? {
        let used = Set(store.pinnedItems().compactMap(\.pinShortcut))
        return (1...9).first { !used.contains($0) }
    }
}

enum PasteAction: String, CaseIterable, Identifiable {
    case pasteToFrontmostApp
    case copyToClipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pasteToFrontmostApp:
            return "点击后直接粘贴"
        case .copyToClipboard:
            return "点击后只复制到剪切板"
        }
    }

    var description: String {
        switch self {
        case .pasteToFrontmostApp:
            return "需要辅助功能权限，会自动回到前台 App 并粘贴。"
        case .copyToClipboard:
            return "更稳妥，点击后你再手动 Cmd+V。"
        }
    }
}

enum ShortcutStyle: String, CaseIterable, Identifiable {
    case optionNumber
    case controlNumber
    case commandNumber
    case controlOptionNumber
    case custom
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionNumber:
            return "Option + 1-9"
        case .controlNumber:
            return "Control + 1-9"
        case .commandNumber:
            return "Command + 1-9"
        case .controlOptionNumber:
            return "Control + Option + 1-9"
        case .custom:
            return "自定义每个固定位"
        case .disabled:
            return "关闭快捷位快捷键"
        }
    }

    func combo(for slot: Int) -> KeyCombo? {
        let keyCode = UInt32(kVK_ANSI_1 + max(0, min(8, slot - 1)))
        switch self {
        case .optionNumber:
            return KeyCombo(keyCode: keyCode, modifiers: UInt32(optionKey), keyName: "\(slot)")
        case .controlNumber:
            return KeyCombo(keyCode: keyCode, modifiers: UInt32(controlKey), keyName: "\(slot)")
        case .commandNumber:
            return KeyCombo(keyCode: keyCode, modifiers: UInt32(cmdKey), keyName: "\(slot)")
        case .controlOptionNumber:
            return KeyCombo(keyCode: keyCode, modifiers: UInt32(controlKey | optionKey), keyName: "\(slot)")
        case .custom, .disabled:
            return nil
        }
    }

    func display(shortcut: Int) -> String {
        combo(for: shortcut)?.display ?? "\(shortcut)"
    }
}

enum HotKeyMode: String, CaseIterable, Identifiable {
    case preset
    case custom
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preset:
            return "Control + Option + Space"
        case .custom:
            return "自定义快捷键"
        case .disabled:
            return "关闭一键唤起"
        }
    }
}

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case text = "文本"
    case images = "图片"
    case pinned = "固定"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .all:
            return "clock"
        case .text:
            return "text.alignleft"
        case .images:
            return "photo"
        case .pinned:
            return "pin"
        }
    }
}
