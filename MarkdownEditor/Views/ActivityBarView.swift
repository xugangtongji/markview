import SwiftUI

// MARK: - ActivityBarPanel

enum ActivityBarPanel: Equatable {
    case explorer
    case outline
    case search
}

// MARK: - ActivityBarView

struct ActivityBarView: View {
    /// Which panel is currently selected. nil = side panel collapsed.
    @Binding var activePanel: ActivityBarPanel?
    var onOpenFolder: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top: navigation icons
            VStack(spacing: 2) {
                panelButton(icon: "folder",            panel: .explorer, help: "资源管理器")
                panelButton(icon: "list.bullet.indent", panel: .outline,  help: "大纲")
                panelButton(icon: "magnifyingglass",   panel: .search,   help: "搜索")
            }
            .padding(.top, 4)

            Spacer()

            // Bottom: utility icons
            VStack(spacing: 2) {
                Button {
                    onOpenFolder()
                } label: {
                    activityIcon("folder.badge.plus", active: false)
                }
                .buttonStyle(.borderless)
                .help("打开文件夹")

                Button { } label: {
                    activityIcon("gear", active: false)
                }
                .buttonStyle(.borderless)
                .help("设置（即将推出）")
            }
            .padding(.bottom, 8)
        }
        .frame(width: 48)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
    }

    // MARK: - Panel Button

    @ViewBuilder
    private func panelButton(icon: String, panel: ActivityBarPanel, help: String) -> some View {
        let isActive = activePanel == panel
        Button {
            // Second click on the active icon collapses the panel
            activePanel = (activePanel == panel) ? nil : panel
        } label: {
            ZStack(alignment: .leading) {
                // Accent left border when active
                if isActive {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                activityIcon(icon, active: isActive)
                    .padding(.leading, 2)
            }
        }
        .buttonStyle(.borderless)
        .help(help)
    }

    // MARK: - Icon Helper

    private func activityIcon(_ name: String, active: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .light))
            .foregroundStyle(active ? Color.primary : Color.secondary)
            .frame(width: 48, height: 44)
            .contentShape(Rectangle())
    }
}
