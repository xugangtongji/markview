import AppKit
import SwiftUI

extension Notification.Name {
    /// Posted by EditorView when the user scrolls; userInfo["fraction"] is a Double in [0,1].
    static let editorDidScroll = Notification.Name("MarkdownEditor.editorDidScroll")
    /// Posted by PreviewView when the user scrolls; userInfo["fraction"] is a Double in [0,1].
    static let previewDidScroll = Notification.Name("MarkdownEditor.previewDidScroll")
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

        // Store weak ref so coordinator can programmatically scroll the view
        context.coordinator.scrollView = scroll

        // NSView.boundsDidChangeNotification on the clip view fires for ALL scroll
        // mechanisms (trackpad, mouse wheel, keyboard, programmatic) — unlike
        // NSScrollView.didLiveScrollNotification which only fires for trackpad gestures.
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scroll.contentView   // object IS the NSClipView, not the NSScrollView
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
        } else if viewModel.findResult == nil && context.coordinator.lastHighlightedRange != nil {
            // Find was dismissed — clear the tracked range but leave the user's selection intact
            context.coordinator.lastHighlightedRange = nil
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
        /// Weak reference to the scroll view so we can programmatically scroll it
        /// in response to preview scroll events.
        weak var scrollView: NSScrollView?
        private weak var viewModel: DocumentViewModel?
        /// Lock to prevent infinite scroll-sync loops (defense-in-depth beyond JS __suppressScrollMsg).
        private var isSyncing = false

        init(viewModel: DocumentViewModel) {
            self.viewModel = viewModel
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(previewDidScrollHandler(_:)),
                name: .previewDidScroll,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - Scroll sync (Preview → Editor direction)

        @objc func previewDidScrollHandler(_ notification: Notification) {
            guard !isSyncing else { return }
            isSyncing = true
            defer { isSyncing = false }
            guard let fraction = notification.userInfo?["fraction"] as? Double else { return }
            // Use scrollClipView.bounds.origin.y — reliable in NSTextView.
            // NSTextView is flipped: minY = distance from top.
            guard let scrollView = scrollView,
                  let docView = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let visible = clipView.bounds.height
            let docHeight = docView.frame.height
            let total = docHeight - visible
            guard total > 1 else { return }
            let targetY = fraction * total
            clipView.scroll(NSMakePoint(0, targetY))
        }

        // MARK: - Scroll sync (Editor → Preview direction)

        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let scrollView = clipView.enclosingScrollView,
                  let docView = scrollView.documentView else { return }
            // Use documentVisibleRect (in document coords) + frame.height (set by scroll view)
            // rather than clipView.bounds — more reliable when NSTextView layout is lazy.
            let visible = scrollView.documentVisibleRect
            let docHeight = docView.frame.height
            let total = docHeight - visible.height
            guard total > 1 else { return }
            // NSTextView is flipped: minY is distance from top → fraction 0→1 = top→bottom.
            let fraction = max(0, min(1, visible.minY / total))
            NotificationCenter.default.post(
                name: .editorDidScroll,
                object: nil,
                userInfo: ["fraction": fraction]
            )
            // Keep DocumentViewModel scroll fraction in sync for tab snapshot
            Task { @MainActor [weak self] in
                self?.viewModel?.updateScrollFraction(fraction)
            }
        }

        // MARK: - NSTextViewDelegate

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
