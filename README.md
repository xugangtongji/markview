# MarkView

A native macOS Markdown editor built with SwiftUI. Real-time Markdown preview in a `WKWebView` pane alongside an `NSTextView`-based editor pane.

**Platform**: macOS 13 Ventura+ (Apple Silicon optimized)  
**Language**: Swift 5.9+ with SwiftUI

## Features

- **Live Preview**: Markdown rendered in real-time via `marked.js` inside `WKWebView`, 200ms debounce on content changes
- **Syntax Highlighting**: Code blocks highlighted with `highlight.js` (GitHub theme)
- **Multi-Tab Editing**: Horizontal scrollable tab bar with unsaved-change indicators, full state persistence per tab
- **Sidebar**: Three-column layout with icon activity bar, collapsible side panel (Explorer / Table of Contents / Search), and main editing area
- **Find & Replace**: Floating toolbar (Xcode-style) with case-insensitive matching, replace current/all
- **Command Palette** (Cmd+P): Search across open tabs and workspace files
- **Status Bar**: Line/column position, character/word/line count, save status indicator
- **Scroll Sync**: Editor scroll position (fraction-based) synced to preview; line-number-based sync between editor and preview
- **Dark/Light Mode**: Follows system appearance via `AppleInterfaceThemeChangedNotification`

## Architecture

```
App Shell  (MarkdownEditorApp, FileCommands)
    ↓
Views      (ContentView, EditorView, PreviewView, StatusBarView, etc.)
    ↓
ViewModel  (DocumentViewModel, TabsViewModel, SidebarViewModel)
    ↓
Services   (FileService, RenderService)
    ↓
Resources  (preview-template.html, marked.js, highlight.js, preview.css)
```

Strictly layered, unidirectional dependencies — each layer only depends on the layer below it.

### Key Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Editor | `NSViewRepresentable` + `NSTextView` | SF Mono 14pt, undo/redo, cursor tracking, scroll sync |
| Preview | `NSViewRepresentable` + `WKWebView` | GFM rendering, code highlighting, theme switching |
| State | `DocumentViewModel` (@MainActor) | Single state center via Combine publishers (`@Published`, `debounce`) |
| File I/O | `NSOpenPanel` / `NSSavePanel` | UTF-8 encoding, .md/.markdown/.txt support |

## Getting Started

### Prerequisites

- Xcode 15+
- macOS 13 Ventura+

### Building

1. Open `MarkdownEditor.xcodeproj` in Xcode
2. Build: `Cmd+B`
3. Run: `Cmd+R`

Or from the command line:

```bash
# Build
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build

# Run tests
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor
```

### Entitlements

`com.apple.security.files.user-selected.read-write` (file access via NSOpenPanel/NSSavePanel).

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+N | New document |
| Cmd+O | Open file |
| Cmd+S | Save |
| Cmd+Shift+S | Save As |
| Cmd+W | Close tab (with unsaved confirmation) |
| Cmd+F | Find & Replace |
| Cmd+P | Command Palette |
| Cmd+Shift+P | Toggle preview panel |
| Cmd+[ / Cmd+] | Previous / Next tab |

## Project Structure

```
MarkdownEditor/
  App/
    MarkdownEditorApp.swift       # @main entry, window config, shortcuts
    FileCommands.swift            # Menu bar commands (file/edit/view)
  Views/
    ContentView.swift              # Main layout (ActivityBar | SidePanel | Editor | Preview)
    EditorView.swift               # NSTextView wrapper
    PreviewView.swift              # WKWebView wrapper
    StatusBarView.swift            # Line/column, counts, save status
    FindBarView.swift              # Floating find/replace toolbar
    SearchPanelView.swift          # Workspace file search panel
    SidebarView.swift              # Icon tab bar + content area
    TOCView.swift                  # Table of contents from headings
    ActivityBarView.swift          # 48px vertical icon strip
    TabBarView.swift               # Horizontal scrollable tab bar
    CommandPaletteView.swift       # Cmd+P command palette
    FileBrowserView.swift          # Recursive file tree
    SidePanelView.swift            # Side panel container (router)
  ViewModels/
    DocumentViewModel.swift        # Central state, Combine pipeline
    TabsViewModel.swift            # Multi-tab lifecycle
    SidebarViewModel.swift         # Sidebar state management
  Services/
    FileService.swift              # Open/Save panel wrapping
    RenderService.swift            # Rendering protocol + PassthroughRenderer
  Resources/
    preview-template.html          # Bundled HTML template
    marked.min.js                  # Markdown parser (GFM)
    highlight.min.js               # Code syntax highlighter
    preview.css                    # GitHub-style CSS (Dark/Light)
    highlight-github.min.css       # highlight.js GitHub theme
MarkdownEditorTests/             # XCTest suite (~60 tests)
```

## Testing

Run all tests in Xcode: `Cmd+U`  
Run from command line:

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor
```

## Tech Stack

- **UI**: SwiftUI + AppKit bridges (`NSViewRepresentable`)
- **State Management**: Combine (`@Published`, `debounce`, `sink`)
- **Markdown Parsing**: `marked.js` (GFM: tables, task lists, fenced code blocks)
- **Syntax Highlighting**: `highlight.js` (GitHub theme)
- **Security**: Base64-encoded content injection to prevent JS injection from user content
