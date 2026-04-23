import SwiftUI

// MARK: - Notification Names (tab / palette commands)

extension Notification.Name {
    static let showCommandPalette = Notification.Name("MarkdownEditor.showCommandPalette")
    static let openNewTab         = Notification.Name("MarkdownEditor.openNewTab")
    static let closeActiveTab     = Notification.Name("MarkdownEditor.closeActiveTab")
    static let selectPreviousTab  = Notification.Name("MarkdownEditor.selectPreviousTab")
    static let selectNextTab      = Notification.Name("MarkdownEditor.selectNextTab")
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var tabsVM: TabsViewModel

    @State private var activePanel: ActivityBarPanel? = .explorer
    @State private var showCommandPalette: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {

                // ── Activity Bar (48px, always visible) ──────────────────────
                ActivityBarView(
                    activePanel: $activePanel,
                    onOpenFolder: { Task { await sidebarVM.openWorkspaceFolder() } }
                )


                Divider()

                HSplitView {
                    // ── Side Panel (collapsible) ──────────────────────────────
                    if activePanel != nil {
                        SidePanelView(activePanel: $activePanel)
                            .frame(minWidth: 180, maxWidth: 200)
                    }

                    VStack(spacing: 0) {
                        TabBarView()

                        ZStack(alignment: .top) {
                            HSplitView {
                                EditorView()
                                    .frame(minWidth: 200, maxWidth: .infinity)

                                if viewModel.showPreview {
                                    PreviewView()
                                        .frame(minWidth: 200, maxWidth: .infinity)
                                }
                            }

                            if viewModel.showFindBar {
                                FindBarView()
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.showFindBar)
                    }
                    .frame(minWidth: 400)
                }
            }

            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
        .toolbar {
            PreviewToggleButton()
//            Button {
//                viewModel.showPreview.toggle()
//            } label: {
//                Image(systemName: viewModel.showPreview ? "sidebar.right" : "sidebar.left")
//                    .font(.system(size: 13))
//                    .foregroundStyle(.secondary)
//                    // 1. 设置你想要的点击区域大小 (36x36 甚至更大)
//                    .frame(width: 36, height: 36)
//                    // 2. 核心：强制将这个 36x36 的矩形区域作为实际点击区域
//                    .contentShape(Rectangle())
//            }
//            .buttonStyle(.plain)
//            .help(viewModel.showPreview ? "隐藏预览" : "显示预览")
        }
        // Command Palette overlay
        .overlay {
            if showCommandPalette {
                CommandPaletteView(
                    isPresented: $showCommandPalette,
                    onSelectFile: { url, content in openFileInTab(url: url, content: content) },
                    onSelectTab:  { id in switchTab(to: id) }
                )
            }
        }
        .onAppear {
            sidebarVM.bind(to: viewModel)
            if let id = tabsVM.activeTabID { tabsVM.loadTab(id: id, into: viewModel) }
        }
        // ── Notification-based commands (from FileCommands / keyboard shortcuts) ──
        .onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
            showCommandPalette.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewTab)) { note in
            if let url     = note.userInfo?["url"]     as? URL,
               let content = note.userInfo?["content"] as? String {
                openFileInTab(url: url, content: content)
            } else {
                openNewTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeActiveTab)) { _ in
            closeActiveTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectPreviousTab)) { _ in
            tabsVM.snapshotActiveTab(from: viewModel)
            tabsVM.selectPreviousTab()
            if let id = tabsVM.activeTabID { tabsVM.loadTab(id: id, into: viewModel) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectNextTab)) { _ in
            tabsVM.snapshotActiveTab(from: viewModel)
            tabsVM.selectNextTab()
            if let id = tabsVM.activeTabID { tabsVM.loadTab(id: id, into: viewModel) }
        }
    }

    // MARK: - Tab Helpers

    private func switchTab(to id: UUID) {
        guard id != tabsVM.activeTabID else { return }
        tabsVM.snapshotActiveTab(from: viewModel)
        tabsVM.activateTab(id: id)
        tabsVM.loadTab(id: id, into: viewModel)
    }

    private func openNewTab() {
        tabsVM.snapshotActiveTab(from: viewModel)
        let id = tabsVM.addTab()
        tabsVM.loadTab(id: id, into: viewModel)
    }

    private func openFileInTab(url: URL, content: String) {
        if let existing = tabsVM.tabs.first(where: { $0.url == url }) {
            switchTab(to: existing.id)
            return
        }
        tabsVM.snapshotActiveTab(from: viewModel)
        let id = tabsVM.openTab(url: url, content: content)
        tabsVM.loadTab(id: id, into: viewModel)
    }

    private func closeActiveTab() {
        guard let id = tabsVM.activeTabID else { return }
        if tabsVM.activeTab?.isModified == true {
            let alert = NSAlert()
            alert.messageText = "关闭未保存的文件？"
            alert.informativeText = "\(tabsVM.activeTab?.title ?? "未命名") 有未保存的更改。"
            alert.addButton(withTitle: "关闭")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        tabsVM.closeTab(id: id)
        if let newID = tabsVM.activeTabID { tabsVM.loadTab(id: newID, into: viewModel) }
    }
}


struct PreviewToggleButton: View {
    @EnvironmentObject var viewModel: DocumentViewModel
    @State private var isHovering: Bool = false
    
    var body: some View {
        Button {
            viewModel.showPreview.toggle()
        } label: {
            Image(systemName: viewModel.showPreview ? "sidebar.right" : "sidebar.left")
                .font(.system(size: 13))
                // 悬停时图标也可以稍微加深
                .foregroundStyle(isHovering ? .primary : .secondary)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                // 核心：根据悬停状态改变背景（这里使用带圆角的半透明层）
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(viewModel.showPreview ? "隐藏预览" : "显示预览")
        // 监听鼠标悬停事件
        .onHover { hovering in
            // 加入轻微的动画让过渡更自然
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
