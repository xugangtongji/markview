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
                // Context action: open folder button in Explorer panel
                if activePanel == .explorer {
                    Button {
                        Task { await sidebarVM.openWorkspaceFolder() }
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("打开文件夹")
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

    private var headerTitle: String {
        switch activePanel {
        case .explorer: return "资源管理器"
        case .outline:  return "大纲"
        case .search:   return "搜索"
        case .none:     return ""
        }
    }
}
