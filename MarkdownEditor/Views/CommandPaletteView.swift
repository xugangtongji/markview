import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject var tabsVM: TabsViewModel
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @Binding var isPresented: Bool
    var onSelectFile: (URL, String) -> Void
    var onSelectTab: (UUID) -> Void

    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var searchFocused: Bool

    // MARK: - Palette Items

    struct PaletteItem: Identifiable {
        enum Kind { case tab(UUID), file(URL) }
        let id: String
        let label: String
        let detail: String
        let kind: Kind
    }

    private var items: [PaletteItem] {
        var results: [PaletteItem] = []

        // Open tabs first
        for tab in tabsVM.tabs {
            if query.isEmpty || tab.title.localizedCaseInsensitiveContains(query) {
                results.append(PaletteItem(
                    id: "tab-\(tab.id)",
                    label: tab.title,
                    detail: tab.url?.path ?? "新文件",
                    kind: .tab(tab.id)
                ))
            }
        }

        // Workspace files not already open as a tab
        let openURLs = Set(tabsVM.tabs.compactMap(\.url))
        func scan(_ files: [FileItem]) {
            for f in files {
                if f.isDirectory {
                    if sidebarVM.expandedDirs.contains(f.url) {
                        scan(sidebarVM.children(of: f.url))
                    }
                } else if !openURLs.contains(f.url),
                          query.isEmpty || f.name.localizedCaseInsensitiveContains(query) {
                    results.append(PaletteItem(
                        id: "file-\(f.url.path)",
                        label: f.name,
                        detail: f.url.path,
                        kind: .file(f.url)
                    ))
                }
            }
        }
        scan(sidebarVM.files)

        return results
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Dimmed backdrop — tap to dismiss
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Hidden keyboard handlers (macOS 13 compatible via keyboardShortcut)
                Group {
                    Button("") { dismiss() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .opacity(0).frame(width: 0, height: 0)
                    Button("") { moveSelection(-1) }
                        .keyboardShortcut(.upArrow, modifiers: [])
                        .opacity(0).frame(width: 0, height: 0)
                    Button("") { moveSelection(1) }
                        .keyboardShortcut(.downArrow, modifiers: [])
                        .opacity(0).frame(width: 0, height: 0)
                    Button("") { confirmSelection() }
                        .keyboardShortcut(.return, modifiers: [])
                        .opacity(0).frame(width: 0, height: 0)
                }

                // Search input
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索文件…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .focused($searchFocused)
                        .onChange(of: query) { _ in selectedIndex = 0 }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                Divider()

                // Results list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                PaletteRow(item: item, isSelected: index == selectedIndex)
                                    .id(index)
                                    .onTapGesture { selectItem(item) }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: selectedIndex) { idx in
                        withAnimation { proxy.scrollTo(idx, anchor: .center) }
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
            .frame(width: 540)
            .padding(.top, 80)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                DispatchQueue.main.async { searchFocused = true }
            }
        }
    }

    // MARK: - Actions

    private func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
    }

    private func confirmSelection() {
        guard selectedIndex < items.count else { return }
        selectItem(items[selectedIndex])
    }

    private func selectItem(_ item: PaletteItem) {
        switch item.kind {
        case .tab(let id):
            onSelectTab(id)
        case .file(let url):
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            onSelectFile(url, content)
        }
        dismiss()
    }

    private func dismiss() {
        query = ""
        isPresented = false
    }
}

// MARK: - PaletteRow

private struct PaletteRow: View {
    let item: CommandPaletteView.PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.primary)
                Text(item.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}
