import SwiftUI

struct FileCommands: Commands {
    let viewModel: DocumentViewModel
    let sidebarVM: SidebarViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建") {
                if viewModel.isModified {
                    confirmDiscard { viewModel.newDocument() }
                } else {
                    viewModel.newDocument()
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开…") {
                Task {
                    if viewModel.isModified {
                        await confirmDiscardAsync { await viewModel.openDocument() }
                    } else {
                        await viewModel.openDocument()
                    }
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
        }

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
        }

        CommandGroup(after: .textEditing) {
            Button("查找/替换") {
                viewModel.showFindBar.toggle()
                if !viewModel.showFindBar { viewModel.findResult = nil }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }

    // MARK: - Helpers

    private func confirmDiscard(_ action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "是否放弃更改？"
        alert.informativeText = "你有未保存的更改，继续将丢失这些更改。"
        alert.addButton(withTitle: "放弃更改")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn { action() }
    }

    private func confirmDiscardAsync(_ action: @escaping () async -> Void) async {
        await MainActor.run {
            confirmDiscard { Task { await action() } }
        }
    }
}
