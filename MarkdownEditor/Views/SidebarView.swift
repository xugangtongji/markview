import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(icon: "folder", tab: .files, help: "文件浏览器")
                tabButton(icon: "list.bullet.indent", tab: .toc, help: "标题目录")
                Spacer()
                Button {
                    Task { await sidebarVM.openWorkspaceFolder() }
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.borderless)
                .help("打开文件夹")
            }
            .frame(height: 32)
            .background(.bar)

            Divider()

            Group {
                switch sidebarVM.activeTab {
                case .files: FileBrowserView()
                case .toc:   TOCView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: SidebarTab, help: String) -> some View {
        Button { sidebarVM.activeTab = tab } label: {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(sidebarVM.activeTab == tab ? Color.accentColor : .secondary)
                    .frame(height: 28)
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(sidebarVM.activeTab == tab ? Color.accentColor : Color.clear)
            }
            .frame(width: 36)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
