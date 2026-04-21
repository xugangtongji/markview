# macOS Markdown 编辑器 开发需求文档

**版本**: v1.0  
**更新日期**: 2026-04-21  
**技术栈**: Swift / SwiftUI（原生 macOS）

---

## 1. 项目概述

开发一款原生 macOS Markdown 编辑器，左侧编辑、右侧实时预览，轻量够用。

**目标**：只做核心功能，不过度设计。

---

## 2. 界面布局

```
┌─────────────────────────────────────────────────────────┐
│  菜单栏（系统标准：File / Edit / View）                  │
├──────────────────────────┬──────────────────────────────┤
│                          │                              │
│    编辑区（左）          │    实时预览区（右）           │
│    NSTextView            │    WKWebView                 │
│    等宽字体              │    渲染 HTML                 │
│                          │                              │
├──────────────────────────┴──────────────────────────────┤
│  状态栏：行 12，列 34  |  字符 1,024  |  已保存         │
└─────────────────────────────────────────────────────────┘
```

分栏比例默认 50/50，支持拖拽调整（`HSplitView`）。

---

## 3. 功能需求

### 3.1 编辑区

**使用 `NSViewRepresentable` 包装 `NSTextView`**（SwiftUI 原生 TextEditor 能力不足）

- 基础编辑：输入、删除、换行、Tab 缩进
- 撤销/重做：Cmd+Z / Cmd+Shift+Z（NSTextView 自带）
- 查找：Cmd+F（调用系统查找栏）
- 等宽字体，默认 `SF Mono` 14pt
- MVP 阶段不做语法高亮（后续可用 `NSTextStorage` 着色）

### 3.2 实时预览区

**使用 `WKWebView`**

编辑内容变化后，延迟 200ms 触发重渲染（防抖）。

**Markdown 解析方案（推荐方案 A）**

- 方案 A：WKWebView 加载本地 HTML 模板，模板内引入 **marked.js**，JS 端完成渲染 ← 推荐，开发快
- 方案 B：用 Apple 官方 **swift-markdown** 包解析生成 HTML，再注入 WKWebView ← 更原生，但工作量大

**渲染支持范围**
- CommonMark 标准语法（标题、粗体、斜体、代码块、链接、图片、引用、列表）
- GFM 表格、任务列表（marked.js 默认支持）
- 代码块语法高亮：模板中引入 **highlight.js**

**预览样式**：内置简洁 CSS（类 GitHub 风格），Light/Dark 跟随系统 `NSApp.effectiveAppearance`。

### 3.3 文件管理

- 新建：Cmd+N，打开空白文档
- 打开：Cmd+O，`NSOpenPanel`，过滤 `.md` / `.markdown` / `.txt`
- 保存：Cmd+S，`NSSavePanel`（首次）/ 直接写入（已有路径）
- 另存为：Cmd+Shift+S
- 关闭前检测未保存状态，弹出系统确认 Alert

MVP 阶段单窗口单文档，不做多标签页。

### 3.4 快捷键

| 操作 | 快捷键 | 实现 |
|------|--------|------|
| 新建 | Cmd+N | 菜单命令 |
| 打开 | Cmd+O | 菜单命令 |
| 保存 | Cmd+S | 菜单命令 |
| 另存为 | Cmd+Shift+S | 菜单命令 |
| 撤销/重做 | Cmd+Z / Cmd+Shift+Z | NSTextView 自带 |
| 查找 | Cmd+F | 系统查找栏 |
| 切换预览 | Cmd+Shift+P | 隐藏/显示右侧面板 |

---

## 4. 技术实现要点

### 项目结构

```
MarkdownEditor/
├── App/
│   └── MarkdownEditorApp.swift       # @main 入口
├── Views/
│   ├── ContentView.swift             # HSplitView 主布局
│   ├── EditorView.swift              # NSTextView 桥接
│   └── PreviewView.swift             # WKWebView 桥接
├── ViewModels/
│   └── DocumentViewModel.swift       # 文档状态、防抖逻辑
├── Resources/
│   └── preview-template.html         # 预览模板（含 marked.js + highlight.js）
└── Utilities/
    └── Debouncer.swift
```

### 关键代码片段

**NSTextView 桥接**
```swift
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.delegate = context.coordinator
        let scroll = NSScrollView()
        scroll.documentView = textView
        return scroll
    }
}
```

**防抖渲染**
```swift
class Debouncer {
    private var workItem: DispatchWorkItem?
    func debounce(delay: TimeInterval, action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
}
// 使用：debouncer.debounce(delay: 0.2) { self.renderPreview() }
```

**WKWebView 注入内容**
```swift
// 加载本地模板
let templateURL = Bundle.main.url(forResource: "preview-template", withExtension: "html")!
webView.loadFileURL(templateURL, allowingReadAccessTo: templateURL.deletingLastPathComponent())

// 模板加载完成后更新内容
webView.evaluateJavaScript("updateContent(`\(escapedMarkdown)`)")
// preview-template.html 中：
// function updateContent(md) {
//   document.getElementById('preview').innerHTML = marked.parse(md)
// }
```

**文档状态**

用 `@StateObject DocumentViewModel` 持有：
- `content: String` — 编辑器文本
- `fileURL: URL?` — 当前文件路径
- `isModified: Bool` — 未保存标记（驱动标题栏显示 `•`）

---

## 5. 非功能要求

- 支持 macOS 13 Ventura+，Apple Silicon 原生（arm64）
- 启动时间 < 1.5 秒
- 1 万行文档预览刷新 < 300ms
- 内存占用 < 100MB

---

## 6. 开发阶段

### Phase 1 — 核心链路（1~2 周）
- [ ] 创建项目，配置 entitlements（`com.apple.security.files.user-selected.read-write`）
- [ ] `EditorView`：NSTextView 桥接，文本双向绑定
- [ ] `PreviewView`：WKWebView 加载本地模板，注入 marked.js
- [ ] 防抖触发渲染，验证实时联动
- [ ] `DocumentViewModel`：content / fileURL / isModified

### Phase 2 — 文件管理（3~5 天）
- [ ] 新建 / 打开 / 保存 / 另存为
- [ ] 窗口标题显示文件名，未保存显示 `•`
- [ ] 关闭前 unsaved 确认弹窗

### Phase 3 — 收尾（3~5 天）
- [ ] Light/Dark 预览 CSS 跟随系统外观
- [ ] 状态栏：字符数、光标位置
- [ ] 切换预览面板（Cmd+Shift+P）
- [ ] 大文件 / 特殊字符 / 中文输入测试

---

## 7. 待决策

- [ ] marked.js / highlight.js 打包进 Bundle 还是用 CDN —— **建议打包，离线可用**
- [ ] 是否换用 swift-markdown 替代 marked.js —— 放后期评估
- [ ] 后期加 Markdown 语法高亮 —— 可用 `NSTextStorage` + 正则，Phase 4 再做

---

*只做够用的，不镀金。*
