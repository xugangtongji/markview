# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MarkView is a native macOS Markdown editor built with SwiftUI. It renders Markdown in real-time using `marked.js` inside a `WKWebView` pane alongside an `NSTextView`-based editor pane.

**Platform**: macOS 13 Ventura+ (Apple Silicon optimized)  
**Language**: Swift with SwiftUI  
**Build Tool**: Xcode 15+

## Build & Development

This is a native Xcode project. Open `MarkdownEditor.xcodeproj` in Xcode to build and run.

- **Build**: `Cmd+B` in Xcode, or `xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build`
- **Run**: `Cmd+R` in Xcode
- **Test (all)**: `Cmd+U` in Xcode, or `xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor`
- **Test (single)**: Select test method in Xcode and press `Ctrl+Option+Cmd+U`

Required entitlement: `com.apple.security.files.user-selected.read-write` (file access via NSOpenPanel/NSSavePanel).

## Architecture

The app uses a strictly layered architecture with **unidirectional dependencies** — each layer only depends on the layer below it, never upward.

```
App Shell  (MarkdownEditorApp, FileCommands)
    ↓
Views      (ContentView, EditorView, PreviewView, StatusBarView)
    ↓
ViewModel  (DocumentViewModel)
    ↓
Services   (FileService, RenderService)
    ↓
Resources  (preview-template.html, marked.js, highlight.js, preview.css)
```

### Key Modules

**DocumentViewModel** — the single state center. Holds document content, file path, and modification state. Drives a Combine pipeline with a 200ms debounce that triggers preview re-rendering. Views observe this object; they never call services directly.

**EditorView** — wraps `NSTextView` via `NSViewRepresentable`. Binds text content bidirectionally to the ViewModel. Undo/redo is handled by `NSTextView`'s built-in `UndoManager`.

**PreviewView** — wraps `WKWebView` via `NSViewRepresentable`. On content change, calls `window.__updateContent(b64)` (a JS function in the bundled template) with Base64-encoded Markdown. The JS side runs `marked.js` to parse and `highlight.js` to highlight code blocks. Dark/Light mode is driven by CSS variables toggled from Swift.

**FileService** — wraps `NSOpenPanel`/`NSSavePanel`. All file I/O uses UTF-8 encoding. No UI dependencies.

**RenderService** — protocol-based abstraction for Markdown rendering. MVP implementation (`PassthroughRenderer`) delegates rendering entirely to the JS layer in `WKWebView`.

**preview-template.html** — bundled HTML containing the full rendering pipeline (marked.js, highlight.js, CSS). Swift injects content by calling `__updateContent(b64)` via `WKWebView.evaluateJavaScript`.

### Data Flow

User types → EditorView → ViewModel.content (Combine publisher) → 200ms debounce → RenderService → PreviewView (`evaluateJavaScript`) → WKWebView renders HTML

File open → FileService.open() → ViewModel receives (content, path) → views update reactively

### Implementation Order (bottom-up)

Build in this order to maintain clean dependencies: Resources → Services → ViewModel → Views → App Shell.

## Lessons Learned

**JS 资源必须是浏览器 standalone 包，不能用 npm 包的 Node.js 入口文件**：从 CDN/npm 手动复制 JS 文件时（如 highlight.js），要确认是 `build/highlight.min.js`（UMD standalone）而非 `lib/highlight.js`（Node.js 入口，含 `require()`），后者在 WKWebView 中无法运行，会导致全局变量为 `undefined`，进而使所有依赖该库的逻辑静默失败。
