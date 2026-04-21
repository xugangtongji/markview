# macOS Markdown 编辑器 — 开发架构方案

**版本**: v1.0  
**日期**: 2026-04-21  
**策略**: 自上而下设计，自底向上实现

---

## 1. 架构设计原则

### 1.1 设计策略说明

**自上而下设计（Top-Down Design）**：从系统全局视角出发，先划定边界，再逐层细化。
1. 确定系统边界：单窗口 macOS 原生 App
2. 划分职责层：Presentation / ViewModel / Service / Infrastructure
3. 明确各层接口契约，再考虑具体实现细节

**自底向上实现（Bottom-Up Implementation）**：
从无依赖的基础层开始构建，逐层向上组装，每一层都可独立验证。
1. Infrastructure（无依赖）→ Service 层 → ViewModel → Presentation → App Shell

### 1.2 核心原则

**单向数据流**：用户输入 → DocumentViewModel（状态） → Service（计算） → 渲染结果 → View 刷新。状态的变化来源唯一，易于追踪。

**关注点分离**：View 只负责展示和事件转发，不含业务逻辑；Service 只做计算，不依赖 UI；ViewModel 是唯一的状态持有者。

**依赖规则（单向）**：
```
View → ViewModel → Service → Infrastructure
```
高层可以依赖低层，但低层绝不导入高层模块。Service 层不导入 SwiftUI。

---

## 2. 分层架构总览

```
┌───────────────────────────────────────────────────────────┐
│                       App Shell                            │
│         MarkdownEditorApp · WindowGroup · menu            │
└──────────────────────┬────────────────────────────────────┘
                       │ 创建
┌──────────────────────▼────────────────────────────────────┐
│                  Presentation Layer                         │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│   │ EditorView  │  │ PreviewView │  │  StatusBarView  │  │
│   │ NSTextView  │  │ WKWebView   │  │  行列 · 字符数  │  │
│   └──────┬──────┘  └──────▲──────┘  └────────▲────────┘  │
└──────────┼────────────────┼───────────────────┼───────────┘
           │ 写入                读取             读取
           ▼  ◀── @Published reactive ──────────┘
┌───────────────────────────────────────────────────────────┐
│                  DocumentViewModel                         │
│    content · renderedHTML · fileURL · isModified          │
│              Combine debounce pipeline                     │
└──────────┬────────────────────────────────────────────────┘
           │ 调用
┌──────────▼────────────────────────────────────────────────┐
│                    Service Layer                            │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│   │ FileService │  │RenderService│  │   Debouncer     │  │
│   │ 文件读写    │  │ 内容→HTML   │  │   200ms 延迟    │  │
│   └─────────────┘  └──────┬──────┘  └─────────────────┘  │
└───────────────────────────┼───────────────────────────────┘
                            │ 读取
┌───────────────────────────▼───────────────────────────────┐
│                    Infrastructure                           │
│   ┌────────────────────────┐  ┌────────────────────────┐  │
│   │    Bundle Resources    │  │      System APIs       │  │
│   │ marked.js · CSS · HTML │  │ NSOpenPanel · Appear.  │  │
│   └────────────────────────┘  └────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

---

## 3. 各模块详细说明

### 3.1 App Shell

**文件**：`App/MarkdownEditorApp.swift`、`App/FileCommands.swift`

**职责**：App 入口、窗口创建、菜单命令注册。

```swift
@main
struct MarkdownEditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .commands {
            FileCommands()   // 注册 Cmd+N/O/S/Shift+S/Shift+P
        }
    }
}
```

**FileCommands**（菜单命令）通过 `@FocusedStateObject` 或 `@EnvironmentObject` 获取 DocumentViewModel，将菜单动作转发给 ViewModel 的方法（open/save/saveAs）。

---

### 3.2 ContentView（主布局容器）

**文件**：`Views/ContentView.swift`

**职责**：持有 `@StateObject DocumentViewModel`，组装 HSplitView 布局，分发 ViewModel 给子视图。

```swift
struct ContentView: View {
    @StateObject var vm = DocumentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                EditorView(text: $vm.content,
                           onCursorMove: { vm.cursorLine = $0; vm.cursorCol = $1 })
                    .frame(minWidth: 300)
                if vm.showPreview {
                    PreviewView(markdown: vm.content, isDark: vm.isDark)
                        .frame(minWidth: 300)
                }
            }
            Divider()
            StatusBarView(vm: vm)
        }
        .onAppear { vm.loadAppearance() }
    }
}
```

**关键设计决策**：ContentView 是唯一 `@StateObject` 的所有者，子视图通过 `@ObservedObject` 或 `Binding` 接收数据，避免状态分散。

---

### 3.3 EditorView

**文件**：`Views/EditorView.swift`

**职责**：将 NSTextView 包装为 SwiftUI 视图，实现文本双向绑定，追踪光标位置。

**接口**：
```swift
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var onCursorMove: ((Int, Int) -> Void)?   // (line, column)
}
```

**NSTextView 关键配置**：
```swift
func makeNSView(context: Context) -> NSScrollView {
    let tv = NSTextView()
    tv.isRichText = false                                    // 纯文本模式
    tv.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
    tv.isAutomaticQuoteSubstitutionEnabled = false           // 关闭智能引号（会破坏 Markdown）
    tv.isAutomaticSpellingCorrectionEnabled = false          // 关闭自动纠错
    tv.usesFindPanel = true                                  // 启用 Cmd+F 系统查找栏
    tv.delegate = context.coordinator
    tv.textContainerInset = NSSize(width: 16, height: 12)   // 编辑区内边距
    let scroll = NSScrollView()
    scroll.documentView = tv
    scroll.hasVerticalScroller = true
    return scroll
}
```

**Coordinator**（NSTextViewDelegate）：
```swift
class Coordinator: NSObject, NSTextViewDelegate {
    var parent: EditorView

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        parent.text = tv.string          // 同步到 Binding
        updateCursor(tv)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let tv = notification.object as? NSTextView else { return }
        updateCursor(tv)
    }

    private func updateCursor(_ tv: NSTextView) {
        let range = tv.selectedRange()
        let line = tv.string.prefix(range.location).components(separatedBy: "\n").count
        let col  = tv.string.prefix(range.location).components(separatedBy: "\n").last?.count ?? 0
        parent.onCursorMove?(line, col + 1)
    }
}
```

---

### 3.4 PreviewView

**文件**：`Views/PreviewView.swift`

**职责**：加载本地 HTML 模板，监听 markdown 内容变化，通过 JS postMessage 更新预览 DOM，跟随系统 Dark Mode 切换 CSS。

**接口**：
```swift
struct PreviewView: NSViewRepresentable {
    var markdown: String    // 原始 Markdown 文本
    var isDark: Bool        // 控制预览 CSS 主题
}
```

**实现要点**：

```swift
func makeNSView(context: Context) -> WKWebView {
    let config = WKWebViewConfiguration()
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.navigationDelegate = context.coordinator

    // 加载本地模板（必须用 loadFileURL，inline JS 才能读 Bundle 内资源）
    let url = Bundle.main.url(forResource: "preview-template", withExtension: "html")!
    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    return webView
}

func updateNSView(_ webView: WKWebView, context: Context) {
    // 等模板加载完成后才注入内容（由 Coordinator.didFinish 控制 isReady flag）
    guard context.coordinator.isReady else { return }
    inject(markdown: markdown, into: webView)
    updateTheme(isDark: isDark, webView: webView)
}

// 安全传参：Base64 编码避免 JS 注入风险
private func inject(markdown: String, into webView: WKWebView) {
    let b64 = Data(markdown.utf8).base64EncodedString()
    webView.evaluateJavaScript("window.__updateContent('\(b64)')")
}
```

**preview-template.html 中的 JS 接收端**：
```javascript
window.__updateContent = function(b64) {
  const md = decodeURIComponent(escape(atob(b64)));
  document.getElementById('content').innerHTML = marked.parse(md);
  document.querySelectorAll('pre code').forEach(hljs.highlightElement);
};
```

**Dark Mode 处理**：通过在 `<html>` 上切换 `data-theme="dark"` attribute，CSS 变量自动响应。

---

### 3.5 StatusBarView

**文件**：`Views/StatusBarView.swift`

**职责**：只读展示 ViewModel 中的状态数据，无业务逻辑。

```swift
struct StatusBarView: View {
    @ObservedObject var vm: DocumentViewModel

    var body: some View {
        HStack(spacing: 0) {
            Text("行 \(vm.cursorLine)，列 \(vm.cursorCol)")
                .frame(width: 120, alignment: .leading)
            Divider().frame(height: 14)
            Text("字符 \(vm.charCount)")
                .frame(width: 80, alignment: .leading)
                .padding(.leading, 12)
            Spacer()
            Text(vm.isModified ? "● 未保存" : "已保存")
                .foregroundColor(vm.isModified ? .secondary : .secondary)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.horizontal, 16)
        .frame(height: 24)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
```

---

### 3.6 DocumentViewModel

**文件**：`ViewModels/DocumentViewModel.swift`

**职责**：整个 App 的唯一状态中心。持有文档内容、文件路径、渲染结果；通过 Combine 驱动防抖渲染；调用 FileService 执行文件操作。

```swift
@MainActor
class DocumentViewModel: ObservableObject {

    // MARK: - 文档状态
    @Published var content: String = ""
    @Published var renderedHTML: String = ""   // 暂未使用，markdown 直接传 PreviewView
    @Published var fileURL: URL? = nil
    @Published var isModified: Bool = false

    // MARK: - UI 状态
    @Published var showPreview: Bool = true
    @Published var isDark: Bool = false

    // MARK: - 状态栏
    @Published var cursorLine: Int = 1
    @Published var cursorCol: Int = 1
    var charCount: Int { content.count }

    // MARK: - 窗口标题（文件名 + 未保存标记）
    var windowTitle: String {
        let name = fileURL?.lastPathComponent ?? "Untitled.md"
        return isModified ? "● \(name)" : name
    }

    // MARK: - 依赖
    private let fileService = FileService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupContentObserver()
        setupAppearanceObserver()
    }

    // MARK: - Combine Pipeline（防抖 + 标记未保存）
    private func setupContentObserver() {
        $content
            .dropFirst()                                          // 忽略初始空值
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isModified = true                          // 内容变化即标记未保存
            })
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // PreviewView 直接观察 content，这里可做额外处理（如字数统计）
            }
            .store(in: &cancellables)
    }

    private func setupAppearanceObserver() {
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeOcclusionStateNotification)
            .merge(with: NotificationCenter.default
                .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification")))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshAppearance() }
            .store(in: &cancellables)
        refreshAppearance()
    }

    func refreshAppearance() {
        isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    // MARK: - 文件操作
    func open() async {
        guard await confirmUnsaved() else { return }
        guard let (url, text) = await fileService.open() else { return }
        content = text
        fileURL = url
        isModified = false
    }

    func save() async {
        if let url = fileURL {
            try? fileService.save(content, to: url)
            isModified = false
        } else {
            await saveAs()
        }
    }

    func saveAs() async {
        guard let url = await fileService.saveAs(content) else { return }
        fileURL = url
        isModified = false
    }

    func newDocument() async {
        guard await confirmUnsaved() else { return }
        content = ""
        fileURL = nil
        isModified = false
    }

    // MARK: - 关闭前确认（弹出系统 Alert）
    func confirmUnsaved() async -> Bool {
        guard isModified else { return true }
        let alert = NSAlert()
        alert.messageText = "文档有未保存的更改"
        alert.informativeText = "是否保存更改？"
        alert.addButton(withTitle: "保存").keyEquivalent = "\r"
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消").keyEquivalent = "\u{1b}"
        let response = await alert.beginSheetModal(for: NSApp.mainWindow!)
        switch response {
        case .alertFirstButtonReturn:  await save(); return true
        case .alertSecondButtonReturn: return true
        default:                       return false
        }
    }
}
```

---

### 3.7 FileService

**文件**：`Services/FileService.swift`

**职责**：封装所有文件 I/O，隔离 AppKit Panel API，返回结果供 ViewModel 使用。Service 层不持有任何 UI 状态。

```swift
class FileService {

    func open() async -> (URL, String)? {
        let panel = NSOpenPanel()
        panel.title = "打开 Markdown 文件"
        panel.allowedContentTypes = [
            .plainText,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!
        ]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard let window = NSApp.mainWindow,
              await panel.beginSheetModal(for: window) == .OK,
              let url = panel.url else { return nil }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            return (url, text)
        } catch {
            return nil
        }
    }

    func save(_ text: String, to url: URL) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func saveAs(_ text: String) async -> URL? {
        let panel = NSSavePanel()
        panel.title = "保存 Markdown 文件"
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        panel.nameFieldStringValue = "Untitled.md"
        panel.canCreateDirectories = true

        guard let window = NSApp.mainWindow,
              await panel.beginSheetModal(for: window) == .OK,
              let url = panel.url else { return nil }

        try? save(text, to: url)
        return url
    }
}
```

---

### 3.8 RenderService

**文件**：`Services/RenderService.swift`

**职责**：Markdown → HTML 转换的抽象边界。MVP 阶段是透传层（真正的渲染在 JS 侧），后期可在此替换为 swift-markdown 实现纯 Swift 渲染，调用方不感知变化。

```swift
protocol MarkdownRenderer {
    func render(_ markdown: String) -> String
}

// MVP 实现：透传，让 WKWebView 内的 marked.js 处理
class PassthroughRenderer: MarkdownRenderer {
    func render(_ markdown: String) -> String { markdown }
}

// 后期可替换：
// class SwiftMarkdownRenderer: MarkdownRenderer { ... }

class RenderService {
    private let renderer: MarkdownRenderer

    init(renderer: MarkdownRenderer = PassthroughRenderer()) {
        self.renderer = renderer
    }

    func render(_ markdown: String) -> String {
        renderer.render(markdown)
    }
}
```

**设计说明**：用 Protocol 定义渲染接口，使 MVP 的 JS 渲染与未来 Swift 渲染可无缝替换，不影响 ViewModel 调用方。

---

### 3.9 Bundle Resources（基础设施）

**文件**：`Resources/preview-template.html`

**职责**：承载 WKWebView 的完整 HTML 环境。所有 JS 库（marked.js, highlight.js）打包进 Bundle，离线可用。

**preview-template.html 结构**：
```html
<!DOCTYPE html>
<html data-theme="light">
<head>
  <meta charset="UTF-8">
  <script src="marked.min.js"></script>
  <script src="highlight.min.js"></script>
  <link rel="stylesheet" href="highlight-github.min.css">
  <link rel="stylesheet" href="preview.css">
</head>
<body>
  <article id="content"></article>

  <script>
    marked.setOptions({
      highlight: (code, lang) => {
        return lang && hljs.getLanguage(lang)
          ? hljs.highlight(code, { language: lang }).value
          : hljs.highlightAuto(code).value;
      },
      breaks: true,
      gfm: true
    });

    // Swift 侧调用此函数注入内容（Base64 编码避免注入风险）
    window.__updateContent = function(b64) {
      try {
        const md = decodeURIComponent(escape(atob(b64)));
        document.getElementById('content').innerHTML = marked.parse(md);
        document.querySelectorAll('pre code').forEach(hljs.highlightElement);
      } catch(e) { console.error(e); }
    };
  </script>
</body>
</html>
```

**preview.css 关键变量**（支持 Dark Mode）：
```css
:root { --bg: #ffffff; --text: #24292e; --code-bg: #f6f8fa; }
[data-theme="dark"] { --bg: #0d1117; --text: #c9d1d9; --code-bg: #161b22; }
body { background: var(--bg); color: var(--text); font-family: -apple-system; ... }
```

---

## 4. 核心数据流

### 4.1 编辑 → 预览渲染

```
用户在 EditorView 输入字符
    │
    ▼ NSTextView.delegate.textDidChange
EditorView.Coordinator
    │ parent.text = tv.string
    ▼ Binding<String> setter
DocumentViewModel.content 变化 (@Published)
    │
    ├─→ isModified = true                     （立即）
    │
    ▼ Combine .debounce(200ms)
（等待用户停止输入 200ms）
    │
    ▼ 触发 sink
（可扩展：字数统计、语法检查等）
    │
    ▼ SwiftUI diff：content 变化
PreviewView.updateNSView 被调用
    │ inject(markdown:) → Base64 → evaluateJavaScript
    ▼ WKWebView 中 window.__updateContent(b64)
marked.parse(md) → innerHTML 更新
hljs.highlightElement() → 代码高亮
```

### 4.2 打开文件（Cmd+O）

```
用户按 Cmd+O
    │ 菜单命令触发
    ▼
DocumentViewModel.open()
    │ confirmUnsaved() → 如有未保存，弹出 Alert
    ▼
FileService.open()
    │ 弹出 NSOpenPanel → 用户选择 .md 文件
    ▼ 返回 (url: URL, text: String)
DocumentViewModel:
    content  = text    → 触发 Combine 链 → 预览自动更新
    fileURL  = url     → 窗口标题更新
    isModified = false → 状态栏"已保存"
```

### 4.3 保存文件（Cmd+S）

```
用户按 Cmd+S
    │ 菜单命令触发
    ▼
DocumentViewModel.save()
    │
    ├─ fileURL != nil ─→ FileService.save(content, to: url)
    │                       写入磁盘 → isModified = false
    │
    └─ fileURL == nil ─→ DocumentViewModel.saveAs()
                            FileService.saveAs() → NSSavePanel
                            用户选择路径 → 写入 → fileURL = url → isModified = false
```

---

## 5. 模块接口一览

| 模块 | 对外暴露 | 依赖 |
|------|---------|------|
| EditorView | `@Binding var text`，`onCursorMove` 回调 | NSTextView, AppKit |
| PreviewView | `var markdown: String`，`var isDark: Bool` | WKWebView, WebKit |
| StatusBarView | `@ObservedObject var vm` | DocumentViewModel |
| DocumentViewModel | `@Published` 属性，`open/save/saveAs/newDocument` | FileService, Combine |
| FileService | `open() async`，`save(_:to:)`，`saveAs(_:) async` | AppKit, Foundation |
| RenderService | `render(_ markdown: String) -> String` | MarkdownRenderer protocol |

---

## 6. 完整项目目录结构

```
MarkdownEditor/
├── MarkdownEditor.xcodeproj/
│
└── MarkdownEditor/
    │
    ├── App/
    │   ├── MarkdownEditorApp.swift        # @main，WindowGroup，.commands 注册
    │   └── FileCommands.swift             # CommandsBuilder：Cmd+N/O/S/Shift+S/Shift+P
    │
    ├── Views/
    │   ├── ContentView.swift              # HSplitView 主布局，@StateObject 持有者
    │   ├── EditorView.swift               # NSViewRepresentable → NSTextView
    │   ├── PreviewView.swift              # NSViewRepresentable → WKWebView
    │   └── StatusBarView.swift            # 底部状态栏（纯展示）
    │
    ├── ViewModels/
    │   └── DocumentViewModel.swift        # 唯一状态中心，@MainActor
    │
    ├── Services/
    │   ├── FileService.swift              # NSOpenPanel / NSSavePanel 封装
    │   └── RenderService.swift            # MarkdownRenderer protocol + PassthroughRenderer
    │
    ├── Resources/
    │   ├── preview-template.html          # WKWebView 模板（含 JS 入口函数）
    │   ├── preview.css                    # 预览样式（CSS 变量，支持 Dark Mode）
    │   ├── marked.min.js                  # Markdown 解析（GFM 支持）
    │   ├── highlight.min.js               # 代码高亮（核心包）
    │   └── highlight-github.min.css       # highlight.js GitHub 主题
    │
    └── MarkdownEditor.entitlements        # com.apple.security.files.user-selected.read-write
```

---

## 7. 模块依赖矩阵

|  | AppShell | ContentView | EditorView | PreviewView | StatusBar | DocVM | FileService | RenderService | Resources |
|--|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **AppShell** | — | ✓ | | | | ✓ | | | |
| **ContentView** | | — | ✓ | ✓ | ✓ | ✓ | | | |
| **EditorView** | | | — | | | | | | |
| **PreviewView** | | | | — | | | | | ✓ |
| **StatusBar** | | | | | — | ✓ | | | |
| **DocViewModel** | | | | | | — | ✓ | ✓ | |
| **FileService** | | | | | | | — | | |
| **RenderService** | | | | | | | | — | |

✓ = 直接依赖；空 = 无依赖

**依赖规则验证**：
- Service 层（FileService、RenderService）无任何 UI 依赖 ✓
- ViewModel 不依赖 View 层 ✓
- Infrastructure（Resources）无 Swift 依赖 ✓

---

## 8. 自底向上实现顺序

### Step 1：Infrastructure — 准备静态资源（无 Swift 代码）

- [ ] 创建 `preview-template.html`，引入 marked.js + highlight.js（CDN 或本地）
- [ ] 编写 `preview.css`，实现 CSS 变量 Dark/Light 切换
- [ ] 验证：直接用浏览器打开 HTML，手动调用 `__updateContent()` 确认 JS 渲染正常
- [ ] 将 JS 库下载为本地文件放入 Resources 文件夹

**验证标准**：在浏览器中打开模板，JS 控制台执行 `__updateContent(btoa("# Hello\n**World**"))` 后 DOM 正确渲染。

### Step 2：Service 层 — 纯 Swift，无 UI

- [ ] 实现 `RenderService`（MVP: PassthroughRenderer，字符串原样返回）
- [ ] 实现 `FileService`，测试 NSOpenPanel / NSSavePanel 弹出和文件读写
- [ ] 编写 Unit Test：FileService 写入临时文件再读回，内容一致
- [ ] 验证 MarkdownRenderer protocol 可替换性

**验证标准**：XCTest 中 FileService 的读写测试全部通过，不需要 UI。

### Step 3：ViewModel — Combine Pipeline

- [ ] 实现 `DocumentViewModel` 骨架（属性 + init）
- [ ] 接入 Combine `$content.debounce` pipeline
- [ ] 实现 `open() / save() / saveAs()` 方法（调用 FileService）
- [ ] 实现 `confirmUnsaved()` Alert 逻辑
- [ ] 编写 Unit Test：修改 content 后 isModified=true，save 后 isModified=false

**验证标准**：在 Unit Test 中验证状态流转正确，不需要 UI。

### Step 4：Presentation — 逐个 View

**4a. EditorView**
- [ ] 先用 SwiftUI 原生 `TextEditor` 验证 Binding 双向绑定流程
- [ ] 替换为 `NSViewRepresentable + NSTextView`
- [ ] 实现 Coordinator（textDidChange 更新 Binding）
- [ ] 实现光标位置追踪（onCursorMove 回调）
- [ ] 验证：Simulator 中输入文字，content Binding 正确更新

**4b. PreviewView**
- [ ] 先用 `webView.loadHTMLString` 验证 marked.js 渲染流程
- [ ] 替换为 `webView.loadFileURL` 加载本地模板
- [ ] 实现 Base64 安全注入（`__updateContent`）
- [ ] 实现 isReady flag（等待 navigationDelegate.didFinish 后才注入）
- [ ] 验证：内容注入后 WKWebView 中 Markdown 正确渲染

**4c. StatusBarView**
- [ ] 实现纯展示 View，绑定 ViewModel 属性
- [ ] 验证：光标移动时行列数字实时更新

**4d. ContentView**
- [ ] 组装 HSplitView，传入 EditorView 和 PreviewView
- [ ] 添加 StatusBarView
- [ ] 验证：分栏可拖拽调整，Cmd+Shift+P 切换预览面板

### Step 5：App Shell — 最终组装

- [ ] 实现 `FileCommands`（CommandsBuilder），注册所有菜单命令
- [ ] 通过 `@FocusedStateObject` 连接菜单命令与 DocumentViewModel
- [ ] 窗口标题绑定 `vm.windowTitle`（含未保存 `●` 标记）
- [ ] 验证所有快捷键（Cmd+N/O/S/Shift+S/Shift+P）端到端可用

### Step 6：集成测试 & 收尾

- [ ] **大文件测试**：打开 10,000 行 Markdown，验证渲染延迟 < 300ms
- [ ] **特殊字符**：中文、emoji、反引号、`$` 符号在 Base64 路径下正确传递
- [ ] **Dark Mode**：切换系统外观，预览 CSS 自动响应
- [ ] **崩溃恢复**：强制杀进程后，下次启动提示未保存（可选，Phase 3 实现）
- [ ] **Entitlements 验证**：确保 `com.apple.security.files.user-selected.read-write` 配置正确，沙盒模式下文件读写正常

---

## 9. 关键风险与对策

| 风险 | 说明 | 对策 |
|------|------|------|
| WKWebView 首次加载延迟 | loadFileURL 是异步的，过早调用 evaluateJavaScript 会失败 | Coordinator 实现 navigationDelegate，设置 isReady flag，updateNSView 中 guard isReady |
| Base64 注入边界 | 直接拼接 Markdown 到 JS 字符串存在注入风险 | 统一使用 Base64 编码通道，禁止直接字符串拼接 |
| NSTextView 与 SwiftUI 状态同步 | Coordinator 更新 Binding 可能触发二次 updateNSView 造成循环 | updateNSView 中比对 tv.string == text 再决定是否 setString |
| 大文件渲染性能 | marked.js 在浏览器 JS 引擎中处理万行文本较慢 | 200ms debounce 已缓解；超过阈值可考虑分块渲染或切换 swift-markdown |
| Entitlements 沙盒限制 | 未配置权限导致 NSOpenPanel 无法访问文件 | 早期在真机上验证，而非仅在 Simulator |

---

*自底向上实现，每一步都有明确的验证标准，不积累技术债。*
