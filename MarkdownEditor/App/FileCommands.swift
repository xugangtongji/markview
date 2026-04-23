import SwiftUI

struct FileCommands: Commands {
    let viewModel: DocumentViewModel
    let sidebarVM: SidebarViewModel
    let tabsVM: TabsViewModel

    var body: some Commands {

        // MARK: - File Menu

        CommandGroup(replacing: .newItem) {
            Button("新建标签页") {
                NotificationCenter.default.post(name: .openNewTab, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开…") {
                Task {
                    let service = FileService()
                    guard let result = await service.openDocument() else { return }
                    NotificationCenter.default.post(
                        name: .openNewTab,
                        object: nil,
                        userInfo: ["url": result.url, "content": result.content]
                    )
                }
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("存储") {
                Task { await viewModel.saveDocument() }
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("存储为…") {
                Task { await viewModel.saveDocumentAs() }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()

            Button("关闭标签页") {
                NotificationCenter.default.post(name: .closeActiveTab, object: nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        // MARK: - Edit Menu (pasteboard)

        CommandGroup(replacing: .pasteboard) {
            Button("剪切")  { NSApp.sendAction(#selector(NSText.cut(_:)),       to: nil, from: nil) }
                .keyboardShortcut("x")
            Button("拷贝")  { NSApp.sendAction(#selector(NSText.copy(_:)),      to: nil, from: nil) }
                .keyboardShortcut("c")
            Button("粘贴")  { NSApp.sendAction(#selector(NSText.paste(_:)),     to: nil, from: nil) }
                .keyboardShortcut("v")
            Button("全选")  { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                .keyboardShortcut("a")
        }

        // MARK: - View Menu

        CommandGroup(after: .sidebar) {
            Button(sidebarVM.isVisible ? "隐藏侧边栏" : "显示侧边栏") {
                sidebarVM.isVisible.toggle()
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("打开文件夹…") {
                Task { await sidebarVM.openWorkspaceFolder() }
            }

            Divider()

            Button(viewModel.showPreview ? "隐藏预览" : "显示预览") {
                viewModel.showPreview.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("命令面板…") {
                NotificationCenter.default.post(name: .showCommandPalette, object: nil)
            }
            .keyboardShortcut("p", modifiers: .command)

            Divider()

            Button("上一个标签页") {
                NotificationCenter.default.post(name: .selectPreviousTab, object: nil)
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])

            Button("下一个标签页") {
                NotificationCenter.default.post(name: .selectNextTab, object: nil)
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
        }

        // MARK: - Find

        CommandGroup(after: .textEditing) {
            Button("查找/替换") {
                viewModel.showFindBar.toggle()
                if !viewModel.showFindBar { viewModel.findResult = nil }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }
}
