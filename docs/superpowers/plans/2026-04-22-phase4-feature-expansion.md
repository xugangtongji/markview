# Phase 4 Feature Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four features to the existing macOS Markdown editor: preview panel toggle (Cmd+Shift+P + floating button), word/line count in status bar, recent files menu, and find/replace floating toolbar.

**Architecture:** All new state lives in `DocumentViewModel`; Views are purely reactive. `FindBarView` is a new SwiftUI view overlaid with `ZStack` above `EditorView`. The find result is surfaced to `EditorView` via a `@Published var findResult: NSRange?` property that `updateNSView` responds to.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSTextView, NSDocumentController), Combine, XCTest

---

## File Map

| Action | File |
|--------|------|
| Modify | `MarkdownEditor/ViewModels/DocumentViewModel.swift` |
| Modify | `MarkdownEditor/Views/ContentView.swift` |
| Modify | `MarkdownEditor/Views/StatusBarView.swift` |
| Modify | `MarkdownEditor/Views/EditorView.swift` |
| **Create** | `MarkdownEditor/Views/FindBarView.swift` |
| Modify | `MarkdownEditor/Services/FileService.swift` |
| Modify | `MarkdownEditor/App/MarkdownEditorApp.swift` |
| Modify | `MarkdownEditor/App/FileCommands.swift` |
| Modify | `MarkdownEditorTests/DocumentViewModelTests.swift` |

---

## Task 1: Preview Toggle

**Files:**
- Modify: `MarkdownEditor/ViewModels/DocumentViewModel.swift`
- Modify: `MarkdownEditor/Views/ContentView.swift`
- Modify: `MarkdownEditor/App/FileCommands.swift`
- Modify: `MarkdownEditorTests/DocumentViewModelTests.swift`

---

- [ ] **Step 1.1: Write failing test for `showPreview`**

Open `MarkdownEditorTests/DocumentViewModelTests.swift` and add after `testCursorUpdate()`:

```swift
func testShowPreviewDefaultsTrue() {
    XCTAssertTrue(vm.showPreview)
}

func testTogglePreview() {
    vm.showPreview = false
    XCTAssertFalse(vm.showPreview)
    vm.showPreview = true
    XCTAssertTrue(vm.showPreview)
}
```

- [ ] **Step 1.2: Run test to verify it fails**

```bash
cd /Users/xugang/Desktop/MarkViewer/swift-code-markviewer
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests/testShowPreviewDefaultsTrue 2>&1 | tail -20
```

Expected: error — `value of type 'DocumentViewModel' has no member 'showPreview'`

- [ ] **Step 1.3: Add `showPreview` to `DocumentViewModel`**

In `MarkdownEditor/ViewModels/DocumentViewModel.swift`, add after `@Published var isDarkMode: Bool = false`:

```swift
@Published var showPreview: Bool = true
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 1.5: Update `ContentView` — conditional preview + floating button**

Replace the entire content of `MarkdownEditor/Views/ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HSplitView {
                    EditorView()
                        .frame(minWidth: 200)
                    if viewModel.showPreview {
                        PreviewView()
                            .frame(minWidth: 200)
                    }
                }
                // Floating preview toggle button — bottom-right corner
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.showPreview.toggle()
                            }
                        } label: {
                            Image(systemName: viewModel.showPreview ? "sidebar.right" : "sidebar.right.fill")
                                .font(.system(size: 14, weight: .medium))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 2, y: 1)
                        }
                        .buttonStyle(.borderless)
                        .help(viewModel.showPreview ? "隐藏预览" : "显示预览")
                        .padding(12)
                    }
                }
            }
            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
    }
}
```

- [ ] **Step 1.6: Add Cmd+Shift+P menu command to `FileCommands`**

In `MarkdownEditor/App/FileCommands.swift`, add a new `CommandGroup` at the end of `var body: some Commands`, after the `saveItem` group:

```swift
CommandGroup(after: .sidebar) {
    Button(viewModel.showPreview ? "隐藏预览" : "显示预览") {
        viewModel.showPreview.toggle()
    }
    .keyboardShortcut("p", modifiers: [.command, .shift])
}
```

- [ ] **Step 1.7: Build to verify no compile errors**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -20
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 1.8: Commit**

```bash
git add MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditor/Views/ContentView.swift \
        MarkdownEditor/App/FileCommands.swift \
        MarkdownEditorTests/DocumentViewModelTests.swift
git commit -m "feat: add preview panel toggle (Cmd+Shift+P + floating button)"
```

---

## Task 2: Word Count & Line Count in Status Bar

**Files:**
- Modify: `MarkdownEditor/ViewModels/DocumentViewModel.swift`
- Modify: `MarkdownEditor/Views/StatusBarView.swift`
- Modify: `MarkdownEditorTests/DocumentViewModelTests.swift`

---

- [ ] **Step 2.1: Write failing tests for `wordCount` and `lineCount`**

In `MarkdownEditorTests/DocumentViewModelTests.swift`, add after `testTogglePreview()`:

```swift
func testWordCountEmpty() {
    XCTAssertEqual(vm.wordCount, 0)
}

func testWordCountBasic() {
    vm.updateContent("Hello world\nFoo bar")
    XCTAssertEqual(vm.wordCount, 4)
}

func testWordCountChineseMixed() {
    vm.updateContent("你好 world")
    XCTAssertEqual(vm.wordCount, 2)
}

func testLineCountEmpty() {
    XCTAssertEqual(vm.lineCount, 1)
}

func testLineCountMultiline() {
    vm.updateContent("line1\nline2\nline3")
    XCTAssertEqual(vm.lineCount, 3)
}
```

- [ ] **Step 2.2: Run tests to verify they fail**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests/testWordCountEmpty 2>&1 | tail -10
```

Expected: error — `value of type 'DocumentViewModel' has no member 'wordCount'`

- [ ] **Step 2.3: Add `wordCount` and `lineCount` to `DocumentViewModel`**

In `MarkdownEditor/ViewModels/DocumentViewModel.swift`, replace:

```swift
    // Downstream subscribers (e.g. PreviewView) observe this to trigger render.
    @Published private(set) var renderTrigger: String = ""
```

with:

```swift
    // Downstream subscribers (e.g. PreviewView) observe this to trigger render.
    @Published private(set) var renderTrigger: String = ""

    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    var lineCount: Int {
        content.isEmpty ? 1 : content.components(separatedBy: "\n").count
    }
```

- [ ] **Step 2.4: Run tests to verify they pass**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 2.5: Update `StatusBarView` to show word and line counts**

Replace the entire content of `MarkdownEditor/Views/StatusBarView.swift` with:

```swift
import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        HStack(spacing: 16) {
            Text("行 \(viewModel.cursorLine)，列 \(viewModel.cursorColumn)")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.content.count) 个字符")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.wordCount) 词")
                .monospacedDigit()

            Divider().frame(height: 12)

            Text("\(viewModel.lineCount) 行")
                .monospacedDigit()

            Spacer()

            Text(viewModel.isModified ? "未保存" : "已保存")
                .foregroundStyle(viewModel.isModified ? Color.orange : Color.secondary)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
    }
}
```

- [ ] **Step 2.6: Build to verify no compile errors**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2.7: Commit**

```bash
git add MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditor/Views/StatusBarView.swift \
        MarkdownEditorTests/DocumentViewModelTests.swift
git commit -m "feat: add word count and line count to status bar"
```

---

## Task 3: Recent Files Menu

**Files:**
- Modify: `MarkdownEditor/Services/FileService.swift`
- Modify: `MarkdownEditor/ViewModels/DocumentViewModel.swift`
- Modify: `MarkdownEditor/App/MarkdownEditorApp.swift`

No unit tests — `NSDocumentController` and `NSOpenPanel` are system APIs without testable seams; the existing `FileServiceTests` round-trip tests are sufficient.

---

- [ ] **Step 3.1: Register opened URLs with `NSDocumentController` in `FileService`**

In `MarkdownEditor/Services/FileService.swift`, replace the `openDocument()` method:

```swift
@MainActor
func openDocument() async -> (content: String, url: URL)? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedFileTypes = FileService.allowedTypes
    panel.title = "打开 Markdown 文件"

    guard panel.runModal() == .OK, let url = panel.url else { return nil }
    guard let content = read(from: url) else { return nil }
    NSDocumentController.shared.noteNewRecentDocumentURL(url)
    return (content, url)
}
```

Also add a new method for opening by URL directly (used by `.onOpenURL`):

```swift
func openDocument(at url: URL) -> (content: String, url: URL)? {
    guard let content = read(from: url) else { return nil }
    NSDocumentController.shared.noteNewRecentDocumentURL(url)
    return (content, url)
}
```

- [ ] **Step 3.2: Add `openDocument(url:)` to `DocumentViewModel`**

In `MarkdownEditor/ViewModels/DocumentViewModel.swift`, add after `openDocument()`:

```swift
func openDocument(url: URL) {
    guard let result = fileService.openDocument(at: url) else { return }
    content = result.content
    fileURL = result.url
    isModified = false
    renderTrigger = renderer.render(markdown: result.content)
}
```

- [ ] **Step 3.3: Handle `.onOpenURL` in `MarkdownEditorApp`**

Replace the entire content of `MarkdownEditor/App/MarkdownEditorApp.swift` with:

```swift
import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var viewModel = DocumentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 500)
                .onOpenURL { url in
                    viewModel.openDocument(url: url)
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            FileCommands(viewModel: viewModel)
        }
    }
}
```

- [ ] **Step 3.4: Build to verify no compile errors**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3.5: Commit**

```bash
git add MarkdownEditor/Services/FileService.swift \
        MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditor/App/MarkdownEditorApp.swift
git commit -m "feat: add recent files via NSDocumentController + onOpenURL"
```

---

## Task 4: Find/Replace Floating Toolbar

**Files:**
- Modify: `MarkdownEditor/ViewModels/DocumentViewModel.swift`
- Modify: `MarkdownEditor/Views/EditorView.swift`
- Create: `MarkdownEditor/Views/FindBarView.swift`
- Modify: `MarkdownEditor/Views/ContentView.swift`
- Modify: `MarkdownEditor/App/FileCommands.swift`
- Modify: `MarkdownEditorTests/DocumentViewModelTests.swift`

---

### Task 4a: ViewModel — Find/Replace State and Logic

- [ ] **Step 4a.1: Write failing tests for find/replace**

In `MarkdownEditorTests/DocumentViewModelTests.swift`, add after `testLineCountMultiline()`:

```swift
func testFindNoMatch() {
    vm.updateContent("Hello world")
    vm.findText = "xyz"
    vm.findNext()
    XCTAssertNil(vm.findResult)
}

func testFindBasicMatch() {
    vm.updateContent("Hello world")
    vm.findText = "world"
    vm.findNext()
    XCTAssertNotNil(vm.findResult)
    XCTAssertEqual(vm.findResult?.location, 6)
    XCTAssertEqual(vm.findResult?.length, 5)
}

func testFindCaseInsensitive() {
    vm.updateContent("Hello World")
    vm.findText = "hello"
    vm.findNext()
    XCTAssertNotNil(vm.findResult)
    XCTAssertEqual(vm.findResult?.location, 0)
}

func testFindWrapsAround() {
    vm.updateContent("ab ab")
    vm.findText = "ab"
    vm.findNext()  // finds at 0
    vm.findNext()  // finds at 3
    vm.findNext()  // wraps to 0
    XCTAssertEqual(vm.findResult?.location, 0)
}

func testReplaceAll() {
    vm.updateContent("foo foo foo")
    vm.findText = "foo"
    vm.replaceText = "bar"
    vm.replaceAll()
    XCTAssertEqual(vm.content, "bar bar bar")
}

func testReplaceAllNoMatch() {
    vm.updateContent("foo")
    vm.findText = "xyz"
    vm.replaceText = "bar"
    vm.replaceAll()
    XCTAssertEqual(vm.content, "foo")
}
```

- [ ] **Step 4a.2: Run tests to verify they fail**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests/testFindNoMatch 2>&1 | tail -10
```

Expected: error — `value of type 'DocumentViewModel' has no member 'findText'`

- [ ] **Step 4a.3: Add find/replace state and methods to `DocumentViewModel`**

In `MarkdownEditor/ViewModels/DocumentViewModel.swift`, after `@Published var showPreview: Bool = true` add:

```swift
// MARK: - Find/Replace
@Published var showFindBar: Bool = false
@Published var findText: String = ""
@Published var replaceText: String = ""
@Published var findResult: NSRange? = nil
```

Then add the following methods after `updateCursor(line:column:)`:

```swift
// MARK: - Find/Replace

func findNext() {
    guard !findText.isEmpty else { findResult = nil; return }
    var searchStart = content.startIndex
    if let current = findResult, let range = Range(current, in: content) {
        searchStart = range.upperBound
    }
    if let range = content.range(of: findText, options: .caseInsensitive, range: searchStart..<content.endIndex) {
        findResult = NSRange(range, in: content)
    } else if let range = content.range(of: findText, options: .caseInsensitive) {
        findResult = NSRange(range, in: content)
    } else {
        findResult = nil
    }
}

func findPrevious() {
    guard !findText.isEmpty else { findResult = nil; return }
    var searchEnd = content.endIndex
    if let current = findResult, let range = Range(current, in: content) {
        searchEnd = range.lowerBound
    }
    if let range = content.range(of: findText, options: [.caseInsensitive, .backwards], range: content.startIndex..<searchEnd) {
        findResult = NSRange(range, in: content)
    } else if let range = content.range(of: findText, options: [.caseInsensitive, .backwards]) {
        findResult = NSRange(range, in: content)
    } else {
        findResult = nil
    }
}

func replaceCurrentAndFindNext() {
    guard !findText.isEmpty,
          let current = findResult,
          let range = Range(current, in: content) else { return }
    content = content.replacingCharacters(in: range, with: replaceText)
    isModified = true
    findNext()
}

func replaceAll() {
    guard !findText.isEmpty else { return }
    let replaced = content.replacingOccurrences(of: findText, with: replaceText, options: .caseInsensitive)
    guard replaced != content else { return }
    content = replaced
    isModified = true
    findResult = nil
}
```

- [ ] **Step 4a.4: Run find/replace tests**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 4a.5: Commit ViewModel changes**

```bash
git add MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditorTests/DocumentViewModelTests.swift
git commit -m "feat: add find/replace logic to DocumentViewModel"
```

---

### Task 4b: EditorView — Respond to `findResult`

- [ ] **Step 4b.1: Update `EditorView.updateNSView` to highlight find result**

In `MarkdownEditor/Views/EditorView.swift`, replace the `updateNSView` method:

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let textView = context.coordinator.textView
    if textView.string != viewModel.content {
        let sel = textView.selectedRange()
        textView.string = viewModel.content
        let safeRange = NSRange(location: min(sel.location, viewModel.content.utf16.count), length: 0)
        textView.setSelectedRange(safeRange)
    }
    if let range = viewModel.findResult,
       range != context.coordinator.lastHighlightedRange {
        context.coordinator.lastHighlightedRange = range
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    } else if viewModel.findResult == nil {
        context.coordinator.lastHighlightedRange = nil
    }
}
```

In the `Coordinator` class, add a property after `let textView = NSTextView()`:

```swift
var lastHighlightedRange: NSRange? = nil
```

- [ ] **Step 4b.2: Build to verify no compile errors**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

---

### Task 4c: Create `FindBarView`

- [ ] **Step 4c.1: Create `MarkdownEditor/Views/FindBarView.swift`**

```swift
import SwiftUI

struct FindBarView: View {
    @EnvironmentObject var vm: DocumentViewModel
    @FocusState private var findFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            // Find row
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField("查找", text: $vm.findText)
                    .textFieldStyle(.plain)
                    .focused($findFocused)
                    .onSubmit { vm.findNext() }
                    .onChange(of: vm.findText) { _ in vm.findResult = nil }
                Button(action: vm.findPrevious) {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(vm.findText.isEmpty)
                .keyboardShortcut(.upArrow, modifiers: [])
                Button(action: vm.findNext) {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(vm.findText.isEmpty)
                .keyboardShortcut(.downArrow, modifiers: [])
                Button {
                    vm.showFindBar = false
                    vm.findResult = nil
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape, modifiers: [])
            }
            // Replace row
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                TextField("替换", text: $vm.replaceText)
                    .textFieldStyle(.plain)
                Button("替换", action: vm.replaceCurrentAndFindNext)
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty || vm.findResult == nil)
                Button("全部替换", action: vm.replaceAll)
                    .buttonStyle(.borderless)
                    .disabled(vm.findText.isEmpty)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .onAppear { findFocused = true }
    }
}
```

- [ ] **Step 4c.2: Build to verify no compile errors**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

---

### Task 4d: Wire FindBarView into ContentView and add Cmd+F

- [ ] **Step 4d.1: Update `ContentView` to overlay `FindBarView`**

Replace the entire content of `MarkdownEditor/Views/ContentView.swift` with:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // Main editor/preview split
                ZStack {
                    HSplitView {
                        EditorView()
                            .frame(minWidth: 200)
                        if viewModel.showPreview {
                            PreviewView()
                                .frame(minWidth: 200)
                        }
                    }
                    // Floating preview toggle button — bottom-right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.showPreview.toggle()
                                }
                            } label: {
                                Image(systemName: viewModel.showPreview ? "sidebar.right" : "sidebar.right.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 2, y: 1)
                            }
                            .buttonStyle(.borderless)
                            .help(viewModel.showPreview ? "隐藏预览" : "显示预览")
                            .padding(12)
                        }
                    }
                }
                // Find/replace bar slides down from top
                if viewModel.showFindBar {
                    FindBarView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.showFindBar)
            Divider()
            StatusBarView()
        }
        .navigationTitle(viewModel.windowTitle)
    }
}
```

- [ ] **Step 4d.2: Add Cmd+F shortcut to `FileCommands`**

In `MarkdownEditor/App/FileCommands.swift`, add a new `CommandGroup` after the `sidebar` group you added in Task 1:

```swift
CommandGroup(after: .textEditing) {
    Button("查找/替换") {
        viewModel.showFindBar.toggle()
        if !viewModel.showFindBar {
            viewModel.findResult = nil
        }
    }
    .keyboardShortcut("f", modifiers: .command)
}
```

- [ ] **Step 4d.3: Run all tests**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' 2>&1 | tail -30
```

Expected: `** TEST SUCCEEDED **` with all tests passing.

- [ ] **Step 4d.4: Commit**

```bash
git add MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditor/Views/EditorView.swift \
        MarkdownEditor/Views/FindBarView.swift \
        MarkdownEditor/Views/ContentView.swift \
        MarkdownEditor/App/FileCommands.swift \
        MarkdownEditorTests/DocumentViewModelTests.swift
git commit -m "feat: add find/replace floating toolbar with Cmd+F"
```

---

## Self-Review

**Spec coverage:**
- [x] Preview toggle — Cmd+Shift+P menu + floating bottom-right button (Task 1)
- [x] Word count in status bar (Task 2)
- [x] Line count in status bar (Task 2)
- [x] Recent files via `NSDocumentController` (Task 3)
- [x] `.onOpenURL` for opening from recent files menu (Task 3)
- [x] Find/replace floating toolbar with Xcode-style layout (Task 4)
- [x] Cmd+F to open, Escape to close (Task 4d)
- [x] Find next/previous with wrap-around (Task 4a)
- [x] Replace current + replace all (Task 4a)
- [x] `EditorView` highlights find result using `showFindIndicator` (Task 4b)
- [x] Tests: preview toggle, word/line count, find/replace logic (Tasks 1, 2, 4a)

**Placeholder scan:** No TBD, TODO, or "similar to Task N" entries found.

**Type consistency check:**
- `vm.findNext()` — defined in Task 4a.3, used in `FindBarView` (Task 4c) ✓
- `vm.findPrevious()` — defined in Task 4a.3, used in `FindBarView` (Task 4c) ✓
- `vm.replaceCurrentAndFindNext()` — defined in Task 4a.3, used in `FindBarView` (Task 4c) ✓
- `vm.replaceAll()` — defined in Task 4a.3, used in `FindBarView` (Task 4c) ✓
- `vm.findResult: NSRange?` — defined in Task 4a.3, read in `EditorView` (Task 4b) and `FindBarView` (Task 4c) ✓
- `vm.showFindBar: Bool` — defined in Task 4a.3, used in `ContentView` (Task 4d) and `FileCommands` (Task 4d) ✓
- `vm.showPreview: Bool` — defined in Task 1.3, used in `ContentView` (Task 1.5) and `FileCommands` (Task 1.6) ✓
- `coordinator.lastHighlightedRange: NSRange?` — defined in Task 4b, read in Task 4b ✓
- `viewModel.openDocument(url:)` — defined in Task 3.2, used in `MarkdownEditorApp` (Task 3.3) ✓
- `fileService.openDocument(at:)` — defined in Task 3.1, called in `DocumentViewModel.openDocument(url:)` (Task 3.2) ✓
