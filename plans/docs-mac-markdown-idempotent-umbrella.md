# MarkView macOS Markdown 编辑器 — 开发计划

## Context

`docs/` 目录下已有完整的 PRD（`markdown-editor-prd.md`）和架构设计文档（`markdown-editor-architecture.md`），CLAUDE.md 已就位。**Phase 1–3 核心功能已全部实现**（编辑器、预览、文件管理、深色模式、状态栏）。本计划 Phase 1–6 记录已完成工作，Phase 7 为当前进行中的功能扩展。

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

### 阶段 0 — Xcode 项目初始化 ✅ 已完成
- [x] 新建 macOS App 项目，bundle ID：`com.markview.MarkdownEditor`
- [x] 最低 Deployment Target：macOS 13.0
- [x] 添加 entitlement：`com.apple.security.files.user-selected.read-write`
- [x] 引入 XCTest target（MarkdownEditorTests）

### 阶段 1 — Infrastructure：资源文件 ✅ 已完成
- [x] 下载并捆绑 `marked.min.js`、`highlight.min.js`、`highlight-github.min.css`
- [x] 编写 `preview-template.html`：`__updateContent(b64)` JS 函数，CSS 变量深色/浅色切换
- [x] 编写 `preview.css`（GitHub 风格）

### 阶段 2 — Service 层 ✅ 已完成
- [x] `RenderService.swift`：`MarkdownRenderer` 协议 + `PassthroughRenderer`
- [x] `FileService.swift`：`open/save/saveAs`，无任何 UI 依赖
- [x] 单元测试：FileService 读写验证，RenderService 协议可替换性验证

### 阶段 3 — ViewModel ✅ 已完成
- [x] `DocumentViewModel.swift`：`@MainActor`，`@Published` 属性，Combine 防抖管道
- [x] 文件操作方法：`newDocument/open/save/saveAs`
- [x] 窗口标题、深色模式追踪、光标位置
- [x] 单元测试：7 个测试用例，状态转换与防抖验证

### 阶段 4 — Views ✅ 已完成
- [x] `EditorView.swift`：NSTextView 桥接，SF Mono 14pt，双向绑定，光标追踪
- [x] `PreviewView.swift`：WKWebView，isReady flag，Base64 注入，深色模式
- [x] `ContentView.swift`：HSplitView 50/50，StatusBarView
- [x] `StatusBarView.swift`：行列、字符数、保存状态

### 阶段 5 — App Shell ✅ 已完成
- [x] `MarkdownEditorApp.swift`：`@main WindowGroup`，environmentObject
- [x] `FileCommands.swift`：Cmd+N/O/S/Shift+S，关闭前 unsaved 确认 Alert

### 阶段 6 — 集成测试 & 打磨 ✅ 已完成
- [x] 大文件渲染性能验证
- [x] 特殊字符：emoji、中文输入法、UTF-8
- [x] Dark / Light Mode 切换
- [x] 文件完整流程验证

---

### 阶段 7 — 功能扩展（进行中）

#### 7a. 预览切换（ViewModel + View + AppShell）
- [ ] `DocumentViewModel`：添加 `@Published var showPreview: Bool = true`
- [ ] `ContentView`：`if vm.showPreview { PreviewView(...) }` 条件渲染
- [ ] `ContentView`：`ZStack` 右下角浮动按钮，图标 `sidebar.right` / `sidebar.right.fill`，`.ultraThinMaterial` 背景
- [ ] `FileCommands` 或新建 `ViewCommands`：Cmd+Shift+P 菜单命令
- [ ] **测试**：`testTogglePreview()` 验证 `showPreview` 翻转

#### 7b. 字数统计（ViewModel + StatusBarView）
- [ ] `DocumentViewModel`：添加 `wordCount` 和 `lineCount` 计算属性（复用 Combine 管道）
- [ ] `StatusBarView`：扩展为 `行 X，列 Y | N 字符 | N 词 | N 行`
- [ ] **测试**：`testWordCountEmpty/Basic()`、`testLineCount()`

#### 7c. 最近文件菜单（FileService + AppShell）
- [ ] `FileService.open()`：成功打开后调用 `NSDocumentController.shared.noteNewRecentDocumentURL(url)`
- [ ] `MarkdownEditorApp`：添加 `.onOpenURL { url in vm.openDocument(url:) }` 处理从系统菜单打开
- [ ] `FileCommands`：挂载系统 Open Recent 子菜单

#### 7d. 查找/替换浮动工具栏（ViewModel + View）
- [ ] `DocumentViewModel`：添加 `showFindBar`、`findText`、`replaceText`；实现 `findNext()`、`findPrevious()`、`replaceCurrentAndFindNext()`、`replaceAll()`
- [ ] 新建 `FindBarView.swift`：两行布局（查找行 + 替换行），`.ultraThinMaterial` 背景，圆角
- [ ] `EditorView`：暴露 `onSelectRange: ((NSRange) -> Void)?` 回调，Coordinator 调用 `NSTextView.setSelectedRange(_:)`
- [ ] `ContentView`：`ZStack(alignment: .top)` 包裹 EditorView，条件显示 FindBarView，`.transition(.move(edge: .top).combined(with: .opacity))`
- [ ] Cmd+F 打开，Cmd+H 切换替换行，Escape 关闭，Return/Shift+Return 查找下一个/上一个
- [ ] **测试**：`testFindTextInContent()`、`testFindNoMatch()`、`testReplaceAll()`

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
