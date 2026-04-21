import AppKit
import SwiftUI

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
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = context.coordinator.textView
        guard textView.string != viewModel.content else { return }
        // Preserve cursor position when content is replaced (e.g. after file open)
        let sel = textView.selectedRange()
        textView.string = viewModel.content
        let safeRange = NSRange(location: min(sel.location, viewModel.content.utf16.count), length: 0)
        textView.setSelectedRange(safeRange)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let textView = NSTextView()
        private weak var viewModel: DocumentViewModel?

        init(viewModel: DocumentViewModel) {
            self.viewModel = viewModel
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
