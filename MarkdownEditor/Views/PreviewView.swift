import AppKit
import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    @EnvironmentObject var viewModel: DocumentViewModel

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
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
            if coordinator.isReady { coordinator.inject(markdown: trigger) }
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

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var isReady = false
        var lastRendered: String = UUID().uuidString  // force first inject
        var pendingTheme: String = "light"

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
