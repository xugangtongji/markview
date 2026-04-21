import Foundation

protocol RenderService {
    func render(markdown: String) -> String
}

// MVP: 直接透传原始 Markdown，真正的渲染由 WKWebView 中的 marked.js 完成。
// 未来可替换为 swift-markdown 实现，调用方无需改动。
struct PassthroughRenderer: RenderService {
    func render(markdown: String) -> String {
        return markdown
    }
}
