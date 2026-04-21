# MarkView macOS Markdown 编辑器 — 开发计划

## Context

用户希望在 macOS 上开发一个原生 Markdown 编辑器。`docs/` 目录下已有完整的 PRD（`markdown-editor-prd.md`）和架构设计文档（`markdown-editor-architecture.md`），CLAUDE.md 已就位。目前仓库仅含文档，尚无任何 Swift 源代码。本计划依据两份文档，按"先基础后上层"顺序安排实现步骤。

---

## 目标产品

| 维度 | 要求 |
|------|------|
| 平台 | macOS 13 Ventura+，Apple Silicon 优化 |
| 语言 | Swift 5.9 + SwiftUI |
| 构建工具 | Xcode 15+ |
| 启动时间 | < 1.5 秒 |
| 渲染性能 | 10,000 行 Markdown < 300ms |
| 内存 | < 100 MB |

---

## 架构总览

```
App Shell  (MarkdownEditorApp, FileCommands)
    ↓
Views      (ContentView, EditorView, PreviewView, StatusBarView)
    ↓
ViewModel  (DocumentViewModel)          ← 唯一状态中心
    ↓
Services   (FileService, RenderService)
    ↓
Resources  (preview-template.html, marked.js, highlight.js, preview.css)
```

**依赖规则**：单向，高层永远不被低层感知。Views 只读 ViewModel，ViewModel 只调 Services，Services 不含任何 UI 代码。

---

## 目录结构（待创建）

```
MarkdownEditor.xcodeproj
MarkdownEditor/
├── App/
│   ├── MarkdownEditorApp.swift       @main 入口
│   └── FileCommands.swift            菜单命令
├── Views/
│   ├── ContentView.swift             HSplitView 50/50 布局
│   ├── EditorView.swift              NSTextView 包装
│   ├── PreviewView.swift             WKWebView 包装
│   └── StatusBarView.swift           行列/字符数/保存态
├── ViewModels/
│   └── DocumentViewModel.swift       @MainActor，Combine 防抖
├── Services/
│   ├── FileService.swift             NSOpenPanel / NSSavePanel
│   └── RenderService.swift           协议 + PassthroughRenderer
├── Resources/
│   ├── preview-template.html         渲染管道入口
│   ├── preview.css                   CSS 变量 Dark/Light
│   ├── marked.min.js
│   ├── highlight.min.js
│   └── highlight-github.min.css
└── MarkdownEditor.entitlements       文件读写沙盒权限
```

---

## 实现阶段（自底向上）

### 阶段 0 — Xcode 项目初始化（基础）
- 新建 macOS App 项目，bundle ID：`com.markview.MarkdownEditor`
- 最低 Deployment Target：macOS 13.0
- 添加 entitlement：`com.apple.security.files.user-selected.read-write`
- 引入 XCTest target（MarkdownEditorTests）

### 阶段 1 — Infrastructure：资源文件（1 天）
- 下载并捆绑 `marked.min.js`、`highlight.min.js`、`highlight-github.min.css`
- 编写 `preview-template.html`：
  - 加载上述 JS/CSS
  - 实现 `__updateContent(b64)` JS 函数（Base64 解码 → marked 解析 → highlight 渲染）
  - CSS 变量 `--bg`, `--text` 等，`data-theme` 驱动深色/浅色切换
- 编写 `preview.css`（GitHub 风格）

### 阶段 2 — Service 层（1-2 天）
**RenderService.swift**
- 定义 `RenderService` 协议（`render(markdown:) -> String`，MVP 空实现，真正渲染在 JS 层）
- 实现 `PassthroughRenderer`（直接返回原始 Markdown，实际渲染交给 WKWebView JS）

**FileService.swift**
- `openDocument() async -> (String, URL)?`：调用 NSOpenPanel，过滤 `.md/.markdown/.txt`，UTF-8 读取
- `saveDocument(content:to:) throws`：UTF-8 写入
- `saveDocumentAs(content:) async -> URL?`：调用 NSSavePanel
- **无任何 UI 依赖**

**单元测试**：FileService 用临时目录读写验证；RenderService 协议可替换性验证。

### 阶段 3 — ViewModel（1-2 天）
**DocumentViewModel.swift**（`@MainActor`，`ObservableObject`）

关键 `@Published` 属性：
```swift
var content: String       // 文档正文
var fileURL: URL?         // 当前路径（nil = 未命名）
var isModified: Bool      // 未保存标记
var cursorLine: Int
var cursorColumn: Int
var isDarkMode: Bool
```

Combine 防抖管道：
```swift
$content
    .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
    .sink { [weak self] _ in self?.triggerRender() }
    .store(in: &cancellables)
```

文件操作方法：`newDocument()`, `openDocument()`, `saveDocument()`, `saveDocumentAs()`
窗口标题：`fileURL?.lastPathComponent ?? "未命名"` + `isModified ? " ●" : ""`

**单元测试**：状态转换（isModified 标志）、防抖时序验证。

### 阶段 4 — Views（3-4 天）
**EditorView.swift**（NSViewRepresentable → NSTextView）
- 字体：`NSFont(name: "SF Mono", size: 14)`，行间距适当放大
- Coordinator 实现 `NSTextViewDelegate`，双向绑定 `ViewModel.content`
- 光标变化 → 更新 `ViewModel.cursorLine/Column`
- **状态同步防循环**：`updateNSView` 中先比较再赋值

**PreviewView.swift**（NSViewRepresentable → WKWebView）
- 加载 `preview-template.html`（bundle）
- 用 `navigationDelegate` + `isReady` flag 保证模板加载完再注入内容
- 内容注入：`evaluateJavaScript("window.__updateContent('\(base64)')")`
- 深色模式：`evaluateJavaScript("document.documentElement.setAttribute('data-theme','dark')")`

**ContentView.swift**
- `HSplitView { EditorView; PreviewView }` 默认 50/50
- 底部 `StatusBarView`

**StatusBarView.swift**
- 显示：`行 X，列 Y | N 个字符 | 已保存/未保存`

### 阶段 5 — App Shell（1 天）
**MarkdownEditorApp.swift**
- `@main WindowGroup { ContentView().environmentObject(viewModel) }`
- `.onReceive(NSWorkspace.willSleepNotification)` 等生命周期处理

**FileCommands.swift**
- `Commands { CommandGroup { ... } }` 接入 Cmd+N/O/S/Shift+S
- 关闭窗口前检查 `isModified`，弹确认 Alert

### 阶段 6 — 集成测试 & 打磨（2-3 天）
- 大文件（10,000 行）渲染性能验证 < 300ms
- 特殊字符：emoji、中文输入法、UTF-8 边缘字符
- Dark / Light Mode 切换实时生效
- 文件 Open → Edit → Save As 完整流程
- 快捷键全覆盖验证：Cmd+N/O/S/Shift+S/Z/Shift+Z/F/Shift+P

---

## 关键技术决策（来自架构文档）

| 问题 | 方案 |
|------|------|
| WKWebView 异步加载 | `navigationDelegate.didFinish` 设 `isReady=true`，之后才调 JS |
| 内容注入安全 | Base64 编码，避免任意 JS 注入 |
| 状态同步死循环 | `updateNSView` 先 `guard textView.string != value` 再赋值 |
| 大文件性能 | 200ms Combine debounce，只在停止输入后触发渲染 |
| 沙盒文件权限 | entitlement `files.user-selected.read-write` + Security-Scoped Bookmark |

---

## 已确认决策

| 问题 | 决策 |
|------|------|
| Xcode 项目创建方式 | Claude 生成全部 .swift 源文件和资源文件，用户在 Xcode 中新建项目后手动导入 |
| 渲染方案 | JS 层 marked.js（PassthroughRenderer，与架构文档一致） |
| JS 库版本 | 最新稳定版：marked.js v13+，highlight.js v11+ |

---

## 验证方式

1. `xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build` 零警告通过
2. `xcodebuild test` 单元测试全绿（FileService、ViewModel 状态测试）
3. 在 Xcode 中运行应用：输入 Markdown 后右侧实时预览更新
4. 打开一个 10,000 行 `.md` 文件，滚动/编辑时无明显卡顿
5. 切换系统深色模式，预览主题自动跟随
