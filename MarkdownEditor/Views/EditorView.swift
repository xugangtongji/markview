import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by EditorView when the user scrolls; userInfo["fraction"] is a Double in [0,1].
    static let editorDidScroll = Notification.Name("MarkdownEditor.editorDidScroll")
}

struct EditorView: NSViewRepresentable {
    @EnvironmentObject var viewModel: DocumentViewModel

    func makeNSView(context: Context) -> NSScrollView {
        let textView = context.coordinator.textView
        textView.delegate = context.coordinator

        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.usesFindPanel = true

        let font = NSFont(name: "SF Mono", size: 14) ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.font = font
        textView.textContainerInset = NSSize(width: 16, height: 16)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        textView.defaultParagraphStyle = paragraph

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.documentView = textView
        scroll.autohidesScrollers = true

        // Observe live scroll events to drive preview sync
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSScrollView.didLiveScrollNotification,
            object: scroll
        )

        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = context.coordinator.textView

        // Sync content — skip during IME composition to avoid breaking candidate window
        if textView.string != viewModel.content && !textView.hasMarkedText() {
            let sel = textView.selectedRange()
            textView.string = viewModel.content
            let safeRange = NSRange(location: min(sel.location, viewModel.content.utf16.count), length: 0)
            textView.setSelectedRange(safeRange)
        }

        // Highlight find result
        if let range = viewModel.findResult,
           range != context.coordinator.lastHighlightedRange {
            context.coordinator.lastHighlightedRange = range
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.showFindIndicator(for: range)
        } else if viewModel.findResult == nil {
            context.coordinator.lastHighlightedRange = nil
            textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0))
        }

        // TOC jump: scroll editor to target line
        if let targetLine = viewModel.scrollToLine {
            let lines = viewModel.content.components(separatedBy: "\n")
            if targetLine < lines.count {
                let prefix = lines[0..<targetLine].joined(separator: "\n")
                let charOffset = prefix.utf16.count + (targetLine > 0 ? 1 : 0)
                let location = min(charOffset, viewModel.content.utf16.count)
                let range = NSRange(location: location, length: 0)
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
            }
            DispatchQueue.main.async { self.viewModel.scrollToLine = nil }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let textView = NSTextView()
        var lastHighlightedRange: NSRange? = nil
        private weak var viewModel: DocumentViewModel?

        init(viewModel: DocumentViewModel) {
            self.viewModel = viewModel
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = notification.object as? NSScrollView,
                  let docView = scrollView.documentView else { return }
            let visible = scrollView.documentVisibleRect
            let total = docView.bounds.height - visible.height
            guard total > 1 else { return }
            let fraction = max(0, min(1, visible.minY / total))
            NotificationCenter.default.post(
                name: .editorDidScroll,
                object: nil,
                userInfo: ["fraction": fraction]
            )
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let content = tv.string
            let (line, column) = cursorPosition(in: tv)
            let vm = viewModel
            Task { @MainActor in
                vm?.updateContent(content)
                vm?.updateCursor(line: line, column: column)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let (line, column) = cursorPosition(in: tv)
            let vm = viewModel
            Task { @MainActor in
                vm?.updateCursor(line: line, column: column)
            }
        }

        private func cursorPosition(in textView: NSTextView) -> (line: Int, column: Int) {
            let location = textView.selectedRange().location
            let text = textView.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: 0, length: location))
            let line = text.substring(with: NSRange(location: 0, length: location))
                .components(separatedBy: "\n").count
            let column = location - lineRange.location + 1
            return (line, column)
        }
    }
}
