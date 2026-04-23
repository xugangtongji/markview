import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        ScrollView {
            if sidebarVM.workspaceURL == nil {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("打开文件夹以浏览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("打开文件夹…") {
                        Task { await sidebarVM.openWorkspaceFolder() }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sidebarVM.files) { item in
                        FileRowView(item: item, depth: 0)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct FileRowView: View {
    let item: FileItem
    let depth: Int
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var tabsVM: TabsViewModel

    private var isCurrentFile: Bool {
        !item.isDirectory && item.url == documentVM.fileURL
    }

    private var isExpanded: Bool {
        sidebarVM.expandedDirs.contains(item.url)
    }

    private var icon: String {
        if item.isDirectory {
            return isExpanded ? "folder.open" : "folder"
        }
        let ext = item.url.pathExtension.lowercased()
        return ["md", "markdown", "txt"].contains(ext) ? "doc.text" : "doc"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if item.isDirectory {
                    sidebarVM.toggleDir(item.url)
                } else {
                    let content = (try? String(contentsOf: item.url, encoding: .utf8)) ?? ""
                    tabsVM.snapshotActiveTab(from: documentVM)
                    let id = tabsVM.openTab(url: item.url, content: content)
                    tabsVM.loadTab(id: id, into: documentVM)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(isCurrentFile ? .white : .secondary)
                        .frame(width: 14)
                    Text(item.name)
                        .font(.system(size: 12))
                        .foregroundStyle(isCurrentFile ? .white : .primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.leading, CGFloat(depth) * 12 + 8)
                .padding(.trailing, 8)
                .background(isCurrentFile ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            if item.isDirectory && isExpanded {
                ForEach(sidebarVM.children(of: item.url)) { child in
                    FileRowView(item: child, depth: depth + 1)
                }
            }
        }
    }
}
