import AppKit
import Foundation

struct FileService {
    private static let allowedTypes: [String] = ["md", "markdown", "txt"]

    // MARK: - Open

    @MainActor
    func openDocument() async -> (content: String, url: URL)? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = FileService.allowedTypes
        panel.title = "打开 Markdown 文件"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let content = read(from: url) else { return nil }
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        return (content, url)
    }

    @MainActor
    func openDocument(at url: URL) -> (content: String, url: URL)? {
        guard let content = read(from: url) else { return nil }
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        return (content, url)
    }

    // MARK: - Save

    func saveDocument(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @MainActor
    func saveDocumentAs(content: String) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedFileTypes = FileService.allowedTypes
        panel.nameFieldStringValue = "未命名.md"
        panel.title = "存储为"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try saveDocument(content: content, to: url)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func read(from url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}
