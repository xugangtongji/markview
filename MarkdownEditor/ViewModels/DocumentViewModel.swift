import Combine
import AppKit
import SwiftUI

@MainActor
final class DocumentViewModel: ObservableObject {
    // MARK: - Published State

    @Published var content: String = ""
    @Published var fileURL: URL?
    @Published var isModified: Bool = false
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var isDarkMode: Bool = false

    // Downstream subscribers (e.g. PreviewView) observe this to trigger render.
    @Published private(set) var renderTrigger: String = ""

    // MARK: - Private

    private let fileService = FileService()
    private let renderer: RenderService = PassthroughRenderer()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init() {
        $content
            .dropFirst()
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self else { return }
                self.renderTrigger = self.renderer.render(markdown: text)
            }
            .store(in: &cancellables)

        // Sync dark mode with system appearance
        isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        DistributedNotificationCenter.default().publisher(
            for: Notification.Name("AppleInterfaceThemeChangedNotification")
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            guard let self else { return }
            self.isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        .store(in: &cancellables)
    }

    // MARK: - Window Title

    var windowTitle: String {
        let name = fileURL?.lastPathComponent ?? "未命名"
        return isModified ? "\(name) ●" : name
    }

    // MARK: - Content Updates

    /// Called by EditorView coordinator on every text change.
    func updateContent(_ newContent: String) {
        guard content != newContent else { return }
        content = newContent
        isModified = true
    }

    // MARK: - File Operations

    func newDocument() {
        content = ""
        fileURL = nil
        isModified = false
        renderTrigger = ""
    }

    func openDocument() async {
        guard let result = await fileService.openDocument() else { return }
        content = result.content
        fileURL = result.url
        isModified = false
        renderTrigger = renderer.render(markdown: result.content)
    }

    func saveDocument() async {
        if let url = fileURL {
            try? fileService.saveDocument(content: content, to: url)
            isModified = false
        } else {
            await saveDocumentAs()
        }
    }

    func saveDocumentAs() async {
        guard let url = await fileService.saveDocumentAs(content: content) else { return }
        fileURL = url
        isModified = false
    }

    // MARK: - Cursor

    func updateCursor(line: Int, column: Int) {
        cursorLine = line
        cursorColumn = column
    }
}
