import ClipboardCore
import SwiftUI
import UniformTypeIdentifiers

private enum ClipBarVisual {
    static let accent = Color(nsColor: .systemTeal)
    static let glassFill = Color(nsColor: .windowBackgroundColor).opacity(0.82)
    static let glassStrongFill = Color(nsColor: .windowBackgroundColor).opacity(0.9)
    static let controlFill = Color(nsColor: .controlBackgroundColor).opacity(0.66)
    static let controlStrongFill = Color(nsColor: .controlBackgroundColor).opacity(0.84)
    static let separator = Color(nsColor: .separatorColor).opacity(0.34)
    static let softSeparator = Color(nsColor: .separatorColor).opacity(0.18)
    static let shadow = Color.black.opacity(0.08)
}

struct ClipboardPanelView: View {
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var draggingPinnedID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header

            ClipBarDivider()

            HStack(spacing: 0) {
                sidebar

                ClipBarDivider()

                content
            }

            ClipBarDivider()

            footer
        }
        .background {
            ZStack {
                Rectangle()
                    .fill(.regularMaterial)
                Rectangle()
                    .fill(ClipBarVisual.glassFill)
            }
        }
        .overlay(ShortcutCatcherView().frame(width: 0, height: 0))
    }

    private var header: some View {
        VStack(spacing: 10) {
            PanelSearchField(text: $searchText)

            pinnedStrip
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(ClipBarVisual.glassStrongFill)
        }
    }

    private var pinnedStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { shortcut in
                let item = appState.store.item(forShortcut: shortcut)
                PinnedSlotView(
                    shortcut: shortcut,
                    title: item?.textPreview ?? "空",
                    isAssigned: item != nil,
                    help: item == nil
                        ? "快捷位 \(shortcut) 未设置"
                        : "按 \(appState.shortcutDisplay(forPinnedSlot: shortcut)) 复用"
                ) {
                    appState.reusePinnedShortcut(shortcut)
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ClipboardFilter.allCases) { filter in
                SidebarFilterButton(
                    filter: filter,
                    isSelected: appState.selectedFilter == filter
                ) {
                    appState.selectedFilter = filter
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                SidebarUtilityButton(title: "设置...", systemImage: "gearshape") {
                    appState.showSettings()
                }

                SidebarUtilityButton(title: "退出", systemImage: "power", isDestructive: true) {
                    appState.quit()
                }
                .help("完全退出 ClipBar")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .frame(width: 116)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color(nsColor: .controlBackgroundColor).opacity(0.48))
        }
    }

    private var content: some View {
        let items = appState.displayedItems(searchText: searchText)

        return Group {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: searchText.isEmpty ? "clipboard" : "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "复制文本或图片后会出现在这里" : "没有找到匹配的文本")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(items) { item in
                    ClipboardRowView(
                        item: item,
                        isPinnedReorderEnabled: appState.selectedFilter == .pinned && searchText.isEmpty,
                        draggingPinnedID: $draggingPinnedID
                    )
                        .environmentObject(appState)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.46))
            }
        }
    }

    private var footer: some View {
        let defaultMessage = appState.selectedFilter == .pinned
            ? "拖拽固定内容可调整 1-9 顺序；点击复制图标复用"
            : "点击记录复用；固定内容快捷键：\(appState.pinnedShortcutStyle.title)"

        return HStack {
            Text(appState.statusMessage.isEmpty ? defaultMessage : appState.statusMessage)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("\(appState.store.items.count) 条")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(ClipBarVisual.glassStrongFill)
        }
    }

}

struct ClipboardRowView: View {
    @EnvironmentObject private var appState: AppState
    let item: ClipboardItem
    let isPinnedReorderEnabled: Bool
    @Binding var draggingPinnedID: UUID?

    var body: some View {
        HStack(spacing: 9) {
            if isPinnedReorderEnabled {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 16)
                    .help("拖拽调整固定位顺序")
            }

            preview

            VStack(alignment: .leading, spacing: 4) {
                Text(item.textPreview)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(item.createdAt, style: .date)
                    Text(item.createdAt, style: .time)
                    if let shortcut = item.pinShortcut {
                        Text("固定 \(shortcut)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            RowActionButton(systemImage: "doc.on.clipboard", help: "复用") {
                appState.reuse(item)
            }

            pinMenu

            RowActionButton(systemImage: "trash", help: "删除", isDestructive: true) {
                appState.delete(item)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ClipBarVisual.controlFill)
                )
                .shadow(color: ClipBarVisual.shadow, radius: 7, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ClipBarVisual.separator, lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isPinnedReorderEnabled else {
                return
            }
            appState.reuse(item)
        }
        .modifier(PinnedReorderModifier(
            isEnabled: isPinnedReorderEnabled,
            item: item,
            draggingPinnedID: $draggingPinnedID,
            appState: appState
        ))
    }

    @ViewBuilder
    private var preview: some View {
        switch item.type {
        case .text:
            Image(systemName: "text.alignleft")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .regular))
                .frame(width: 34, height: 34)
                .background(ClipBarVisual.glassStrongFill)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(ClipBarVisual.softSeparator, lineWidth: 0.5)
                )
        case .image:
            if let path = item.imagePath,
               let image = NSImage(contentsOfFile: path) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ClipBarVisual.separator, lineWidth: 0.5)
                    )
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 34, height: 34)
                    .background(ClipBarVisual.glassStrongFill)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(ClipBarVisual.softSeparator, lineWidth: 0.5)
                    )
            }
        }
    }

    private var pinMenu: some View {
        Menu {
            ForEach(1...9, id: \.self) { slot in
                let current = appState.store.item(forShortcut: slot)
                Button {
                    appState.pin(item, toSlot: slot)
                } label: {
                    Text("固定到 \(slot)：\(current?.textPreview ?? "空")")
                }
            }

            if item.isPinned {
                Divider()
                Button("取消固定") {
                    appState.togglePin(item)
                }
            }
        } label: {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(item.isPinned ? ClipBarVisual.accent : Color.secondary)
                .background(ClipBarVisual.controlStrongFill)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .help("选择固定位")
    }
}

private struct PanelSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("搜索复制过的文本", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(ClipBarVisual.controlStrongFill)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ClipBarVisual.separator, lineWidth: 0.5)
        )
    }
}

private struct PinnedSlotView: View {
    let shortcut: Int
    let title: String
    let isAssigned: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text("\(shortcut)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 17, height: 17)
                    .foregroundStyle(isAssigned ? ClipBarVisual.accent : Color.secondary)
                    .background(slotBadgeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

                Text(title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundStyle(isAssigned ? Color.primary : Color.secondary.opacity(0.55))
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            .background(slotBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isAssigned ? ClipBarVisual.separator : ClipBarVisual.softSeparator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var slotBackground: Color {
        isAssigned
            ? ClipBarVisual.controlStrongFill
            : Color(nsColor: .controlBackgroundColor).opacity(0.34)
    }

    private var slotBadgeBackground: Color {
        isAssigned
            ? ClipBarVisual.accent.opacity(0.14)
            : Color(nsColor: .separatorColor).opacity(0.24)
    }
}

private struct SidebarFilterButton: View {
    let filter: ClipboardFilter
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(filter.rawValue)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
            } icon: {
                Image(systemName: filter.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
            }
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? ClipBarVisual.accent.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? ClipBarVisual.accent.opacity(0.18) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarUtilityButton: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
                    .font(.system(size: 12))
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
            }
            .foregroundStyle(isDestructive ? Color.red.opacity(0.78) : Color.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .frame(height: 28)
        }
        .buttonStyle(.plain)
    }
}

private struct RowActionButton: View {
    let systemImage: String
    let help: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .foregroundStyle(isDestructive ? Color.red.opacity(0.82) : Color.secondary)
                .background(ClipBarVisual.controlStrongFill)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(ClipBarVisual.softSeparator, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ClipBarDivider: View {
    var body: some View {
        Divider()
            .overlay(ClipBarVisual.softSeparator)
    }
}

private struct PinnedReorderModifier: ViewModifier {
    let isEnabled: Bool
    let item: ClipboardItem
    @Binding var draggingPinnedID: UUID?
    let appState: AppState

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .onDrag {
                    draggingPinnedID = item.id
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: PanelPinnedDropDelegate(
                        destinationID: item.id,
                        draggingID: $draggingPinnedID,
                        appState: appState
                    )
                )
        } else {
            content
        }
    }
}

private struct PanelPinnedDropDelegate: DropDelegate {
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
