import AppKit
import SwiftUI

struct SidePanelView: View {
    @Binding var activePanel: ActivityBarPanel?
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header bar
            HStack(spacing: 8) {
                Text(headerTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                // Context action: new .md file button in Explorer panel
                if activePanel == .explorer {
                    Button {
                        showNewFileDialog()
                    } label: {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(sidebarVM.workspaceURL == nil)
                    .help("在工作区新建 Markdown 文件")
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Panel content switched by activity bar selection
            Group {
                switch activePanel {
                case .explorer:
                    FileBrowserView()
                case .outline:
                    TOCView()
                case .search:
                    SearchPanelView()
                case .none:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - New File Dialog

    /// Shows a native NSAlert with a text field for the filename.
    /// The .md extension is displayed but not editable.
    private func showNewFileDialog() {
        let alert = NSAlert()
        alert.messageText = "新建 Markdown 文件"
        alert.informativeText = "输入文件名，后缀 .md 将自动添加"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .informational

        // ── Accessory view: [text field 240pt] [".md" label] ──────────────
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 24))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 252, height: 24))
        textField.placeholderString = "文件名"
        textField.bezelStyle = .roundedBezel
        container.addSubview(textField)

        let suffix = NSTextField(labelWithString: ".md")
        suffix.frame = NSRect(x: 258, y: 4, width: 42, height: 16)
        suffix.textColor = .secondaryLabelColor
        suffix.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        container.addSubview(suffix)

        alert.accessoryView = container
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        guard let newURL = sidebarVM.createNewFile(named: name) else {
            let err = NSAlert()
            err.messageText = "创建失败"
            err.informativeText = "\u{201C}\(name).md\u{201D} 已存在或无写入权限。"
            err.addButton(withTitle: "好")
            err.runModal()
            return
        }

        // Open the freshly created file in a new tab
        NotificationCenter.default.post(
            name: .openNewTab,
            object: nil,
            userInfo: ["url": newURL, "content": ""]
        )
    }

    private var headerTitle: String {
        switch activePanel {
        case .explorer: return "资源管理器"
        case .outline:  return "大纲"
        case .search:   return "搜索"
        case .none:     return ""
        }
    }
}
