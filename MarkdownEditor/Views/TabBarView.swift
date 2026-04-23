import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var tabsVM: TabsViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(tabsVM.tabs) { tab in
                    TabCell(
                        tab: tab,
                        isActive: tab.id == tabsVM.activeTabID,
                        onSelect: { switchTo(tab.id) },
                        onClose:  { closeTab(tab.id) }
                    )
                    Divider().frame(height: 34)
                }
            }
        }
        .frame(height: 34)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
        // Keep active tab's unsaved dot in sync with live edits
        .onChange(of: documentVM.isModified) { _ in
            tabsVM.updateActiveTabModified(documentVM.isModified, url: documentVM.fileURL)
        }
        .onChange(of: documentVM.fileURL) { _ in
            tabsVM.updateActiveTabModified(documentVM.isModified, url: documentVM.fileURL)
        }
    }

    // MARK: - Helpers

    private func switchTo(_ id: UUID) {
        guard id != tabsVM.activeTabID else { return }
        tabsVM.snapshotActiveTab(from: documentVM)
        tabsVM.activateTab(id: id)
        tabsVM.loadTab(id: id, into: documentVM)
    }

    private func closeTab(_ id: UUID) {
        let wasActive = id == tabsVM.activeTabID
        tabsVM.closeTab(id: id)
        if wasActive, let newID = tabsVM.activeTabID {
            tabsVM.loadTab(id: newID, into: documentVM)
        }
    }
}

// MARK: - TabCell

private struct TabCell: View {
    let tab: TabItem
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color.primary : .secondary)

            Text(tab.title)
                .font(.system(size: 12))
                .foregroundStyle(isActive ? Color.primary : .secondary)
                .lineLimit(1)
                .fixedSize()

            // Unsaved dot ↔ close button swap on hover
            ZStack {
                if tab.isModified && !isHovering {
                    Circle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 6, height: 6)
                } else {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .opacity((isHovering || isActive) ? 1 : 0)
                }
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(isActive ? Color(NSColor.textBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            if isActive {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovering = $0 }
    }
}
