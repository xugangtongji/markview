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
    @Published var showPreview: Bool = true

    // MARK: - Find/Replace
    @Published var showFindBar: Bool = false
    @Published var findText: String = ""
    @Published var replaceText: String = ""
    @Published var findResult: NSRange? = nil

    // Downstream subscribers (e.g. PreviewView) observe this to trigger render.
    @Published private(set) var renderTrigger: String = ""

    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    var lineCount: Int {
        content.isEmpty ? 1 : content.components(separatedBy: "\n").count
    }

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

    func openDocument(url: URL) {
        guard let result = fileService.openDocument(at: url) else { return }
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

    // MARK: - Find/Replace

    func findNext() {
        guard !findText.isEmpty else { findResult = nil; return }
        var searchStart = content.startIndex
        if let current = findResult, let range = Range(current, in: content) {
            searchStart = range.upperBound
        }
        if let range = content.range(of: findText, options: .caseInsensitive, range: searchStart..<content.endIndex) {
            findResult = NSRange(range, in: content)
        } else if let range = content.range(of: findText, options: .caseInsensitive) {
            findResult = NSRange(range, in: content)
        } else {
            findResult = nil
        }
    }

    func findPrevious() {
        guard !findText.isEmpty else { findResult = nil; return }
        var searchEnd = content.endIndex
        if let current = findResult, let range = Range(current, in: content) {
            searchEnd = range.lowerBound
        }
        if let range = content.range(of: findText, options: [.caseInsensitive, .backwards], range: content.startIndex..<searchEnd) {
            findResult = NSRange(range, in: content)
        } else if let range = content.range(of: findText, options: [.caseInsensitive, .backwards]) {
            findResult = NSRange(range, in: content)
        } else {
            findResult = nil
        }
    }

    func replaceCurrentAndFindNext() {
        guard !findText.isEmpty,
              let current = findResult,
              let range = Range(current, in: content) else { return }
        content = content.replacingCharacters(in: range, with: replaceText)
        isModified = true
        findResult = nil
        findNext()
    }

    func replaceAll() {
        guard !findText.isEmpty else { return }
        let replaced = content.replacingOccurrences(of: findText, with: replaceText, options: .caseInsensitive)
        guard replaced != content else { return }
        content = replaced
        isModified = true
        findResult = nil
    }
}
