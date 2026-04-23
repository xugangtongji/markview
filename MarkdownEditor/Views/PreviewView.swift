import AppKit
import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    @EnvironmentObject var viewModel: DocumentViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Use a weak wrapper to avoid the WKUserContentController→Coordinator retain cycle.
        config.userContentController.add(
            WeakScriptMessageHandler(context.coordinator),
            name: "scrollSync"
        )


        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        if let templateURL = Bundle.main.url(forResource: "preview-template", withExtension: "html") {
            webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        let theme = viewModel.isDarkMode ? "dark" : "light"

        if coordinator.pendingTheme != theme {
            coordinator.pendingTheme = theme
            if coordinator.isReady { coordinator.applyTheme(theme) }
        }

        let trigger = viewModel.renderTrigger
        if coordinator.lastRendered != trigger {
            coordinator.lastRendered = trigger
            if coordinator.isReady {
                coordinator.inject(markdown: trigger)
                // Restore scroll position after a tab switch (content just changed).
                // Delayed slightly so the new content has time to lay out before scrolling.
                let fraction = viewModel.scrollFraction
                if fraction > 0 {
                    let js = "window.__scrollTo && window.__scrollTo(\(fraction));"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak webView] in
                        webView?.evaluateJavaScript(js, completionHandler: nil)
                    }
                    viewModel.scrollFraction = 0
                }
            }
        }

        // TOC scroll: jump preview to heading anchor
        if let headingID = viewModel.scrollToHeadingID, coordinator.isReady {
            let safe = headingID.replacingOccurrences(of: "'", with: "\\'")
            let js = "document.getElementById('\(safe)')?.scrollIntoView({behavior:'smooth',block:'start'});"
            webView.evaluateJavaScript(js, completionHandler: nil)
            DispatchQueue.main.async { self.viewModel.scrollToHeadingID = nil }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var isReady = false
        var lastRendered: String = UUID().uuidString  // force first inject
        var pendingTheme: String = "light"

        override init() {
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(editorDidScrollHandler(_:)),
                name: .editorDidScroll,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - Scroll sync (Editor → Preview, line-number based)

        @objc func editorDidScrollHandler(_ notification: Notification) {
            guard isReady,
                  let line = notification.userInfo?["line"] as? Int else { return }
            let js = "window.__scrollToLine && window.__scrollToLine(\(line));"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // Preview → Editor sync intentionally disabled; editor is the sync source.
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            applyTheme(pendingTheme)
            inject(markdown: lastRendered)
        }

        func inject(markdown: String) {
            let data = Data(markdown.utf8)
            let b64 = data.base64EncodedString()
            let js = "window.__updateContent('\(b64)');"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        func applyTheme(_ theme: String) {
            let js = "window.__setTheme('\(theme)');"
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

// MARK: - WeakScriptMessageHandler

/// Breaks the strong reference cycle:
/// WKUserContentController → (strong) handler → (weak) Coordinator
/// Without this wrapper, the Coordinator would be retained by the WKWebView
/// configuration and could not be deallocated normally.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(_ delegate: WKScriptMessageHandler) { self.delegate = delegate }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
