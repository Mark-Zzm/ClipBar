import ClipboardCore
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsVisual {
    static let accent = Color(nsColor: .systemTeal)
    static let glassFill = Color(nsColor: .windowBackgroundColor).opacity(0.86)
    static let controlFill = Color(nsColor: .controlBackgroundColor).opacity(0.68)
    static let strongControlFill = Color(nsColor: .controlBackgroundColor).opacity(0.86)
    static let separator = Color(nsColor: .separatorColor).opacity(0.24)
    static let softSeparator = Color(nsColor: .separatorColor).opacity(0.14)
    static let shadow = Color.black.opacity(0.08)
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var draggingPinnedID: UUID?
    @State private var accessibilityStatus = AccessibilityPermissionController.statusText

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                settingsForm
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.72))
            }
        }
        .onAppear {
            refreshAccessibilityStatus()
        }
    }

    private var settingsForm: some View {
        VStack(spacing: 0) {
            SettingsFormRow(title: "开机自动运行", systemImage: "power") {
                HStack {
                    Text("登录 macOS 后自动启动 ClipBar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: $appState.launchAtLoginEnabled)
                        .labelsHidden()
                }
            }

            FormDivider()

            SettingsFormRow(title: "历史保存上限", systemImage: "tray.full") {
                HStack {
                    Text("控制普通历史记录的最大保存数量")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Stepper(
                        "\(appState.storageLimit) 条",
                        value: $appState.storageLimit,
                        in: 50...5000,
                        step: 50
                    )
                    .frame(width: 150, alignment: .trailing)
                }
            }

            FormDivider()

            SettingsFormRow(title: "点击历史记录时", systemImage: "cursorarrow.click") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("点击历史记录时", selection: $appState.pasteAction) {
                        ForEach(PasteAction.allCases) { action in
                            Text(action.title).tag(action)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()

                    Text(appState.pasteAction.description)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FormDivider()

            SettingsFormRow(title: "固定内容快捷键", systemImage: "command") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $appState.pinnedShortcutStyle) {
                        ForEach(ShortcutStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    if appState.pinnedShortcutStyle == .custom {
                        customPinnedShortcuts
                    }

                    Text("固定内容最多 9 条。默认使用 Option + 1-9，避免和搜索框输入数字冲突。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FormDivider()

            SettingsFormRow(title: "一键唤起面板", systemImage: "keyboard") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("", selection: $appState.panelHotKeyMode) {
                        ForEach(HotKeyMode.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)

                    if appState.panelHotKeyMode == .custom {
                        KeyRecorderView(
                            combo: $appState.panelCustomHotKey,
                            label: "一键唤起"
                        )
                        .frame(width: 260, height: 32)
                    }
                }
            }

            FormDivider()

            SettingsFormRow(title: "固定内容", systemImage: "pin") {
                VStack(alignment: .leading, spacing: 9) {
                    Text("拖拽下方固定内容可以调整顺序；顺序会自动映射到固定位 1-9。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    pinnedList
                        .frame(height: 196)
                }
            }

            FormDivider()

            SettingsFormRow(title: "辅助功能权限", systemImage: "hand.raised") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("直接粘贴需要 macOS 辅助功能权限。未授权时会降级为只复制到剪切板。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Label(
                            accessibilityStatus,
                            systemImage: AccessibilityPermissionController.isTrusted
                                ? "checkmark.circle.fill"
                                : "exclamationmark.triangle.fill"
                        )
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AccessibilityPermissionController.isTrusted ? Color.green : Color.orange)

                        Spacer()

                        Button("刷新") {
                            refreshAccessibilityStatus()
                        }
                    }

                    HStack(spacing: 8) {
                        Button("请求辅助功能权限") {
                            AccessibilityPermissionController.requestAccessPrompt()
                            refreshAccessibilityStatus()
                        }

                        Button("打开辅助功能设置") {
                            LaunchAtLoginController.openAccessibilitySettings()
                        }
                    }
                }
            }

            FormDivider()

            SettingsFormRow(title: "清空数据", systemImage: "trash", isDestructive: true) {
                HStack {
                    Button(role: .destructive) {
                        appState.clearHistory()
                    } label: {
                        Label("清空普通历史", systemImage: "trash")
                    }

                    Spacer()

                    Text(appState.statusMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SettingsVisual.glassFill)
                )
                .shadow(color: SettingsVisual.shadow, radius: 18, y: 8)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SettingsVisual.separator, lineWidth: 0.5)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ClipBar 设置")
                .font(.system(size: 18, weight: .semibold))
            Text("调整复用方式、快捷键、固定内容和系统权限。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }

    private var customPinnedShortcuts: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(1...9, id: \.self) { slot in
                SettingsRow(title: "固定 \(slot)") {
                    KeyRecorderView(
                        combo: bindingForPinnedShortcut(slot),
                        label: "快捷键"
                    )
                    .frame(width: 220, height: 32)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func refreshAccessibilityStatus() {
        accessibilityStatus = AccessibilityPermissionController.statusText
    }

    private var pinnedList: some View {
        let pinnedItems = appState.store.pinnedItems()

        return ScrollView {
            VStack(spacing: 6) {
                if pinnedItems.isEmpty {
                    Text("还没有固定内容")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 72)
                } else {
                    ForEach(Array(pinnedItems.enumerated()), id: \.element.id) { index, item in
                        PinnedSettingsRow(index: index, item: item) {
                            try? appState.store.unpin(itemID: item.id)
                        }
                        .onDrag {
                            draggingPinnedID = item.id
                            return NSItemProvider(object: item.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: PinnedDropDelegate(
                                destinationID: item.id,
                                draggingID: $draggingPinnedID,
                                appState: appState
                            )
                        )
                    }
                }
            }
            .padding(1)
        }
    }

    private func bindingForPinnedShortcut(_ slot: Int) -> Binding<KeyCombo> {
        Binding(
            get: {
                appState.pinnedCustomHotKeys[slot] ?? KeyCombo.defaultPinnedShortcut(slot)
            },
            set: { combo in
                appState.setCustomPinnedHotKey(combo, forSlot: slot)
            }
        )
    }
}

private struct SettingsFormRow<Content: View>: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let content: Content

    init(
        title: String,
        systemImage: String,
        isDestructive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isDestructive ? Color.red.opacity(0.78) : SettingsVisual.accent)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDestructive ? Color.red.opacity(0.88) : .primary)
            }
            .frame(width: 138, alignment: .leading)
            .padding(.top, 2)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

private struct FormDivider: View {
    var body: some View {
        Rectangle()
            .fill(SettingsVisual.softSeparator)
            .frame(height: 0.5)
            .padding(.leading, 172)
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .frame(width: 68, alignment: .leading)

            content

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24)
    }
}

private struct PinnedSettingsRow: View {
    let index: Int
    let item: ClipboardItem
    let unpin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 14)

            Text("\(index + 1)")
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(SettingsVisual.accent)
                .frame(width: 20, height: 20)
                .background(SettingsVisual.accent.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(item.textPreview)
                .font(.system(size: 11))
                .lineLimit(1)

            Spacer()

            Button("取消固定", action: unpin)
                .buttonStyle(.borderless)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(SettingsVisual.strongControlFill)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SettingsVisual.separator, lineWidth: 0.5)
        )
    }
}

private struct PinnedDropDelegate: DropDelegate {
    let destinationID: UUID
    @Binding var draggingID: UUID?
    let appState: AppState

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != destinationID else {
            return
        }

        let pinned = appState.store.pinnedItems()
        guard let source = pinned.firstIndex(where: { $0.id == draggingID }),
              let destination = pinned.firstIndex(where: { $0.id == destinationID }) else {
            return
        }

        appState.reorderPinned(from: source, to: destination)
    }
}
