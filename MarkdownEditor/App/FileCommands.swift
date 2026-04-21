import SwiftUI

struct FileCommands: Commands {
    let viewModel: DocumentViewModel

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

        CommandGroup(after: .sidebar) {
            Button(viewModel.showPreview ? "隐藏预览" : "显示预览") {
                viewModel.showPreview.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
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
        if alert.runModal() == .alertFirstButtonReturn {
            action()
        }
    }

    private func confirmDiscardAsync(_ action: @escaping () async -> Void) async {
        await MainActor.run {
            confirmDiscard { Task { await action() } }
        }
    }
}
