import Combine
import Foundation
import SwiftUI

struct FileItem: Identifiable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
}

struct TOCItem: Identifiable {
    let id: String
    let title: String
    let level: Int
    let line: Int
}

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var workspaceURL: URL? = nil
    @Published var files: [FileItem] = []
    @Published var tocItems: [TOCItem] = []
    @Published var expandedDirs: Set<URL> = []

    private var manualWorkspace: Bool = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Binding

    func bind(to documentVM: DocumentViewModel) {
        documentVM.$fileURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in self?.syncWorkspace(from: url) }
            .store(in: &cancellables)

        documentVM.$content
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] content in self?.refreshTOC(from: content) }
            .store(in: &cancellables)
    }

    // MARK: - Workspace

    func syncWorkspace(from fileURL: URL?) {
        guard !manualWorkspace, let url = fileURL else { return }
        workspaceURL = url.deletingLastPathComponent()
        refreshFiles()
    }

    func setManualWorkspace(_ url: URL) {
        workspaceURL = url
        manualWorkspace = true
        expandedDirs = []
        refreshFiles()
    }

    @MainActor
    func openWorkspaceFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择工作区文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setManualWorkspace(url)
    }

    func refreshFiles() {
        guard let root = workspaceURL else { files = []; return }
        files = loadItems(at: root)
    }

    func toggleDir(_ url: URL) {
        if expandedDirs.contains(url) {
            expandedDirs.remove(url)
        } else {
            expandedDirs.insert(url)
        }
    }

    func children(of url: URL) -> [FileItem] {
        loadItems(at: url)
    }

    // MARK: - TOC

    func refreshTOC(from content: String) {
        var items: [TOCItem] = []
        let lines = content.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            guard line.hasPrefix("#") else { continue }
            let level = line.prefix(while: { $0 == "#" }).count
            guard level >= 1, level <= 4 else { continue }
            let title = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            let slug = title.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            let safeSlug = slug.isEmpty ? "heading-\(index)" : slug
            items.append(TOCItem(id: safeSlug, title: title, level: level, line: index))
        }
        tocItems = items
    }

    // MARK: - Private

    private func loadItems(at url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .compactMap { item -> FileItem? in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FileItem(id: item, name: item.lastPathComponent, url: item, isDirectory: isDir)
            }
    }
}
