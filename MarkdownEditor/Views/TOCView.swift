import SwiftUI

struct TOCView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        ScrollView {
            if sidebarVM.tocItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("文档中暂无标题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sidebarVM.tocItems) { item in
                        Button {
                            documentVM.scrollToLine = item.line
                            documentVM.scrollToHeadingID = item.id
                        } label: {
                            Text(item.title)
                                .font(.system(size: 12, weight: item.level == 1 ? .medium : .regular))
                                .foregroundStyle(item.level == 1 ? Color.primary : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.leading, CGFloat(item.level - 1) * 12 + 8)
                                .padding(.trailing, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
