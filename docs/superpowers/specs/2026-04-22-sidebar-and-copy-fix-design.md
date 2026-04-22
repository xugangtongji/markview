# 左侧导航栏 + Copy Bug 修复 — 设计文档

**版本**: v1.0
**日期**: 2026-04-22

---

## 1. 概述

为 macOS Markdown 编辑器新增左侧导航栏，支持两种模式：
1. **文件浏览器**：显示工作区目录文件树，可展开子目录、点击打开文件
2. **标题目录（TOC）**：解析当前文档的 Markdown 标题，点击跳转到编辑器对应行并同步滚动预览区

同时修复编辑器 Cmd+C / Copy 失效的问题。

---

## 2. 决策记录

| 问题 | 决策 |
|------|------|
| 侧边栏布局方式 | 方案 C：通过 `HSplitView` 实现可拖拽调宽侧边栏，与现有架构一致 |
| Tab 切换样式 | 方案 B：顶部图标 Tab 栏（`📁` 文件 / `☰` TOC），下划线指示当前 |
| 文件浏览器根目录 | 方案 C：有当前文件时自动用其父目录；也支持手动"打开文件夹" |
| TOC 点击行为 | 方案 C：同步跳转编辑器光标行 + 预览区滚动到对应标题 |
| 状态架构 | 方案 B：新建独立 `SidebarViewModel`，与 `DocumentViewModel` 解耦 |

---

## 3. 架构

### 3.1 文件划分

**新建：**
```
MarkdownEditor/ViewModels/SidebarViewModel.swift   — 侧边栏专属状态与逻辑
MarkdownEditor/Views/SidebarView.swift             — 主容器 + 图标 Tab 栏
MarkdownEditor/Views/FileBrowserView.swift         — 文件树视图
MarkdownEditor/Views/TOCView.swift                 — 标题目录视图
MarkdownEditorTests/SidebarViewModelTests.swift    — 单元测试
```

**修改：**
```
MarkdownEditor/ViewModels/DocumentViewModel.swift  — 新增 scrollToLine: Int?
MarkdownEditor/Views/ContentView.swift             — HSplitView 扩展为三栏
MarkdownEditor/Views/EditorView.swift              — 响应 scrollToLine，移动光标
MarkdownEditor/Views/PreviewView.swift             — 暴露 scrollToHeading(id:)
MarkdownEditor/App/MarkdownEditorApp.swift         — 注入 SidebarViewModel
MarkdownEditor/App/FileCommands.swift              — Cmd+\ 切换侧边栏；Copy Bug 修复；打开文件夹
```

### 3.2 依赖关系

```
SidebarViewModel  ←读取←  DocumentViewModel.content / fileURL
SidebarView       →写入→  SidebarViewModel
FileBrowserView   →写入→  DocumentViewModel.openDocument(url:)
TOCView           →写入→  DocumentViewModel.scrollToLine
                  →写入→  PreviewView.scrollToHeading(id:)
```

`SidebarViewModel` 不持有 `DocumentViewModel` 引用，通过 Combine 订阅 `DocumentViewModel.$content` 和 `.$fileURL`（在 `MarkdownEditorApp` 中建立订阅）。

---

## 4. 数据模型

### 4.1 SidebarViewModel

```swift
enum SidebarTab { case files, toc }

struct FileItem: Identifiable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
}

struct TOCItem: Identifiable {
    let id: String      // slug：标题文本转小写、空格替换为"-"，用于 JS 锚点
    let title: String
    let level: Int      // 1–4
    let line: Int       // content 中的行号（0-based），用于编辑器跳转
}

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var activeTab: SidebarTab = .files
    @Published var workspaceURL: URL? = nil         // nil = 尚未设置
    @Published var files: [FileItem] = []
    @Published var tocItems: [TOCItem] = []
    @Published var expandedDirs: Set<URL> = []      // 已展开的子目录

    private var manualWorkspace: Bool = false        // 用户是否手动指定过工作区
    private var cancellables = Set<AnyCancellable>()

    // 订阅 DocumentViewModel 的变化（在 App 层建立）
    func bind(to documentVM: DocumentViewModel)

    // 当前文件变化时自动同步工作区（仅 manualWorkspace == false 时生效）
    func syncWorkspace(from fileURL: URL?)

    // 用户手动"打开文件夹"
    @MainActor func openWorkspaceFolder() async

    // 重新读取目录（非递归；子目录按需展开后单独读取）
    func refreshFiles()

    // 解析 Markdown 标题，仅解析 H1–H4
    func refreshTOC(from content: String)
}
```

### 4.2 DocumentViewModel 新增属性

```swift
// 编辑器跳转目标行（nil = 无需跳转）
// EditorView.updateNSView 消费后重置为 nil
@Published var scrollToLine: Int? = nil

// 预览区跳转标题 ID（nil = 无需跳转）
// PreviewView.updateNSView 消费后重置为 nil
@Published var scrollToHeadingID: String? = nil
```

---

## 5. 各模块设计

### 5.1 SidebarView

```
┌──────────────────────────────┐
│ [📁]  [☰]          [folder+] │  ← 图标 Tab 栏（28px 高）
├──────────────────────────────┤
│                              │
│  FileBrowserView             │  ← activeTab == .files
│    或  TOCView               │  ← activeTab == .toc
│                              │
└──────────────────────────────┘
```

- 图标 Tab 使用 SF Symbols：`folder`（文件）、`list.bullet.indent`（TOC）
- 当前选中 Tab 下方有 2px 蓝色下划线
- `folder.badge.plus` 图标按钮触发 `openWorkspaceFolder()`
- 整体背景：`.sidebar`（macOS 原生侧边栏颜色）

### 5.2 FileBrowserView

- 展示 `sidebarVM.files`，每行：图标 + 文件名
  - 目录：`folder` / `folder.open` + 灰色
  - `.md/.markdown/.txt` 文件：`doc.text` + 主色
  - 其他文件：`doc` + 浅灰
- 当前打开文件（对比 `documentVM.fileURL`）高亮显示（`.accentColor` 背景）
- 点击文件 → `documentVM.openDocument(url:)`
- 点击目录 → 切换 `sidebarVM.expandedDirs`，展开后读取子目录内容（惰性加载）
- 工作区未设置时显示空状态提示："打开文件夹以浏览"

### 5.3 TOCView

- 监听 `sidebarVM.tocItems`（由 `SidebarViewModel` 维护，300ms debounce）
- 按 `level` 缩进：`(level - 1) * 12` px leading padding
- 点击条目：
  1. 设置 `documentVM.scrollToLine = item.line` → `EditorView.updateNSView` 响应
  2. 设置 `documentVM.scrollToHeadingID = item.id` → `PreviewView.updateNSView` 响应
- 无标题时显示空状态："文档中暂无标题"

### 5.4 TOC 解析算法

```swift
func refreshTOC(from content: String) {
    var items: [TOCItem] = []
    let lines = content.components(separatedBy: "\n")
    for (index, line) in lines.enumerated() {
        guard line.hasPrefix("#") else { continue }
        let level = line.prefix(while: { $0 == "#" }).count
        guard level >= 1, level <= 4 else { continue }
        let title = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { continue }
        let slug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        items.append(TOCItem(id: slug, title: title, level: level, line: index))
    }
    tocItems = items
}
```

### 5.5 EditorView — scrollToLine 响应

在 `updateNSView` 中添加：

```swift
if let line = viewModel.scrollToLine {
    let lines = viewModel.content.components(separatedBy: "\n")
    guard line < lines.count else { return }
    let charOffset = lines[0..<line].joined(separator: "\n").count + (line > 0 ? 1 : 0)
    let range = NSRange(location: min(charOffset, viewModel.content.utf16.count), length: 0)
    textView.setSelectedRange(range)
    textView.scrollRangeToVisible(range)
    DispatchQueue.main.async { viewModel.scrollToLine = nil }
}
```

### 5.6 PreviewView — scrollToHeadingID 响应

`PreviewView.updateNSView` 中检测 `viewModel.scrollToHeadingID`：

```swift
if let headingID = viewModel.scrollToHeadingID {
    let safe = headingID.replacingOccurrences(of: "'", with: "\\'")
    let js = "document.getElementById('\(safe)')?.scrollIntoView({behavior:'smooth',block:'start'})"
    webView.evaluateJavaScript(js)
    DispatchQueue.main.async { viewModel.scrollToHeadingID = nil }
}
```

**`preview-template.html` 修改**：为 marked.js 添加自定义 heading renderer，为每个标题生成 `id` 属性（与 `TOCItem.id` slug 算法一致）：

```javascript
const renderer = new marked.Renderer();
renderer.heading = function(text, level) {
  const slug = text.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, '');
  return `<h${level} id="${slug}">${text}</h${level}>`;
};
marked.setOptions({ renderer });
```

### 5.7 ContentView — 三栏布局

```swift
HSplitView {
    SidebarView()
        .frame(
            minWidth: sidebarVM.isVisible ? 160 : 0,
            maxWidth: sidebarVM.isVisible ? 280 : 0
        )
        .opacity(sidebarVM.isVisible ? 1 : 0)
    EditorView()
        .frame(minWidth: 200)
    PreviewView()
        .frame(
            minWidth: viewModel.showPreview ? 200 : 0,
            maxWidth: viewModel.showPreview ? .infinity : 0
        )
        .opacity(viewModel.showPreview ? 1 : 0)
}
```

---

## 6. Copy Bug 修复

**根本原因**：SwiftUI `WindowGroup` 不会自动将系统 Edit 菜单的 Cut/Copy/Paste 动作路由到 `NSTextView`。

**修复**：在 `FileCommands` 中用 `CommandGroup(replacing: .pasteboard)` 替换默认剪贴板菜单，通过 `NSApp.sendAction(_:to:from:)` 将动作显式转发到响应链第一响应者：

```swift
CommandGroup(replacing: .pasteboard) {
    Button("剪切")  { NSApp.sendAction(#selector(NSText.cut(_:)),       to: nil, from: nil) }
        .keyboardShortcut("x")
    Button("拷贝")  { NSApp.sendAction(#selector(NSText.copy(_:)),      to: nil, from: nil) }
        .keyboardShortcut("c")
    Button("粘贴")  { NSApp.sendAction(#selector(NSText.paste(_:)),     to: nil, from: nil) }
        .keyboardShortcut("v")
    Button("全选")  { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        .keyboardShortcut("a")
}
```

---

## 7. 菜单命令

在 `FileCommands` 中新增：

| 操作 | 快捷键 | 说明 |
|------|--------|------|
| 显示/隐藏侧边栏 | Cmd+\\ | 切换 `sidebarVM.isVisible` |
| 打开文件夹… | — | 触发 `sidebarVM.openWorkspaceFolder()` |

---

## 8. 测试计划

**SidebarViewModelTests**（单元测试）：
- `testTOCParsingEmpty` — 空内容返回空数组
- `testTOCParsingH1toH4` — H1–H4 正确解析 level 和 line
- `testTOCIgnoresH5andH6` — H5/H6 不出现在结果中
- `testTOCSlugGeneration` — 特殊字符、中文标题 slug 正确生成
- `testSyncWorkspaceFromFile` — 有 fileURL 时自动设置 workspaceURL
- `testManualWorkspaceNotOverridden` — 手动设置后不被文件路径覆盖
- `testFilesLoadedFromWorkspace` — 工作区设置后 files 正确加载

**手动验证**：
- Cmd+C 在编辑器选中文字后正常复制
- 侧边栏 Cmd+\\ 切换显示/隐藏
- 文件树正确展示工作区，当前文件高亮
- TOC 随文档内容实时更新
- 点击 TOC 条目：编辑器光标跳转 + 预览滚动同步

---

## 9. 非功能约束

- 侧边栏最小宽度 160px，最大 280px
- TOC 解析防抖 300ms（不影响打字体验）
- 文件树不做实时目录监听（YAGNI），刷新时机：打开文件夹、打开文件后
- `SidebarViewModel` 是 `@MainActor`，与 `DocumentViewModel` 保持一致
