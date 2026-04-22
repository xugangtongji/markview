# Sidebar + Copy Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a resizable left sidebar with file browser and Markdown TOC, fix the Cmd+C copy bug in the editor, and wire TOC clicks to sync both editor cursor and preview scroll.

**Architecture:** New `SidebarViewModel` owns sidebar state; it binds to `DocumentViewModel.$content` and `.$fileURL` via Combine (set up in App layer). Two new `@Published` properties on `DocumentViewModel` (`scrollToLine`, `scrollToHeadingID`) let `EditorView` and `PreviewView` respond to TOC clicks reactively. The sidebar is the leftmost pane in the existing `HSplitView`.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSTextView, NSOpenPanel), Combine, XCTest, marked.js (custom heading renderer)

---

## File Map

| Action | Path |
|--------|------|
| **Create** | `MarkdownEditor/ViewModels/SidebarViewModel.swift` |
| **Create** | `MarkdownEditor/Views/SidebarView.swift` |
| **Create** | `MarkdownEditor/Views/FileBrowserView.swift` |
| **Create** | `MarkdownEditor/Views/TOCView.swift` |
| **Create** | `MarkdownEditorTests/SidebarViewModelTests.swift` |
| Modify | `MarkdownEditor/ViewModels/DocumentViewModel.swift` |
| Modify | `MarkdownEditor/Views/ContentView.swift` |
| Modify | `MarkdownEditor/Views/EditorView.swift` |
| Modify | `MarkdownEditor/Views/PreviewView.swift` |
| Modify | `MarkdownEditor/Resources/preview-template.html` |
| Modify | `MarkdownEditor/App/FileCommands.swift` |
| Modify | `MarkdownEditor/App/MarkdownEditorApp.swift` |

---

## Task 1: Copy Bug Fix

**Files:**
- Modify: `MarkdownEditor/App/FileCommands.swift`

- [ ] **Step 1.1: Add `CommandGroup(replacing: .pasteboard)` to FileCommands**

In `MarkdownEditor/App/FileCommands.swift`, add this new `CommandGroup` at the end of `var body: some Commands { }`, after the `CommandGroup(after: .textEditing)` block:

```swift
CommandGroup(replacing: .pasteboard) {
    Button("剪切") {
        NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
    }
    .keyboardShortcut("x")
    Button("拷贝") {
        NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
    }
    .keyboardShortcut("c")
    Button("粘贴") {
        NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
    }
    .keyboardShortcut("v")
    Button("全选") {
        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
    }
    .keyboardShortcut("a")
}
```

- [ ] **Step 1.2: Build**

```bash
cd /Users/xugang/Desktop/MarkViewer/swift-code-markviewer
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 1.3: Commit**

```bash
git add MarkdownEditor/App/FileCommands.swift
git commit -m "fix: route Edit menu copy/paste to NSTextView first responder"
```

---

## Task 2: DocumentViewModel — scrollToLine + scrollToHeadingID

**Files:**
- Modify: `MarkdownEditor/ViewModels/DocumentViewModel.swift`
- Modify: `MarkdownEditorTests/DocumentViewModelTests.swift`

- [ ] **Step 2.1: Write failing tests**

In `MarkdownEditorTests/DocumentViewModelTests.swift`, add after `testReplaceAllNoMatch()`:

```swift
func testScrollToLineDefaultsNil() {
    XCTAssertNil(vm.scrollToLine)
}

func testScrollToHeadingIDDefaultsNil() {
    XCTAssertNil(vm.scrollToHeadingID)
}

func testScrollToLineCanBeSet() {
    vm.scrollToLine = 5
    XCTAssertEqual(vm.scrollToLine, 5)
    vm.scrollToLine = nil
    XCTAssertNil(vm.scrollToLine)
}
```

- [ ] **Step 2.2: Run to verify failure**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests/testScrollToLineDefaultsNil 2>&1 | tail -10
```

Expected: compile error — `value of type 'DocumentViewModel' has no member 'scrollToLine'`

- [ ] **Step 2.3: Add properties to DocumentViewModel**

In `MarkdownEditor/ViewModels/DocumentViewModel.swift`, after `@Published var findResult: NSRange? = nil`, add:

```swift
// MARK: - TOC Navigation
/// Set by TOCView; consumed and reset to nil by EditorView.updateNSView
@Published var scrollToLine: Int? = nil
/// Set by TOCView; consumed and reset to nil by PreviewView.updateNSView
@Published var scrollToHeadingID: String? = nil
```

- [ ] **Step 2.4: Run tests**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/DocumentViewModelTests 2>&1 | tail -15
```

Expected: `** TEST SUCCEEDED **` (28 tests)

- [ ] **Step 2.5: Commit**

```bash
git add MarkdownEditor/ViewModels/DocumentViewModel.swift \
        MarkdownEditorTests/DocumentViewModelTests.swift
git commit -m "feat: add scrollToLine + scrollToHeadingID to DocumentViewModel"
```

---

## Task 3: SidebarViewModel + Tests

**Files:**
- Create: `MarkdownEditor/ViewModels/SidebarViewModel.swift`
- Create: `MarkdownEditorTests/SidebarViewModelTests.swift`

- [ ] **Step 3.1: Write failing tests**

Create `MarkdownEditorTests/SidebarViewModelTests.swift` with this content, then add it to the Xcode project's test target (edit `project.pbxproj` the same way `FindBarView.swift` was added — use `uuidgen` for two new UUIDs):

```swift
import XCTest
import Combine
@testable import MarkdownEditor

@MainActor
final class SidebarViewModelTests: XCTestCase {
    var vm: SidebarViewModel!

    override func setUp() {
        vm = SidebarViewModel()
    }

    func testInitialState() {
        XCTAssertTrue(vm.isVisible)
        XCTAssertEqual(vm.activeTab, .files)
        XCTAssertNil(vm.workspaceURL)
        XCTAssertTrue(vm.files.isEmpty)
        XCTAssertTrue(vm.tocItems.isEmpty)
    }

    func testTOCParsingEmpty() {
        vm.refreshTOC(from: "")
        XCTAssertTrue(vm.tocItems.isEmpty)
    }

    func testTOCParsingH1() {
        vm.refreshTOC(from: "# Hello World")
        XCTAssertEqual(vm.tocItems.count, 1)
        XCTAssertEqual(vm.tocItems[0].title, "Hello World")
        XCTAssertEqual(vm.tocItems[0].level, 1)
        XCTAssertEqual(vm.tocItems[0].line, 0)
    }

    func testTOCParsingMixedLevels() {
        let content = "# H1\n## H2\n### H3\n#### H4\n##### H5"
        vm.refreshTOC(from: content)
        // H5 should be excluded
        XCTAssertEqual(vm.tocItems.count, 4)
        XCTAssertEqual(vm.tocItems[0].level, 1)
        XCTAssertEqual(vm.tocItems[1].level, 2)
        XCTAssertEqual(vm.tocItems[2].level, 3)
        XCTAssertEqual(vm.tocItems[3].level, 4)
    }

    func testTOCIgnoresH5andH6() {
        vm.refreshTOC(from: "##### H5\n###### H6")
        XCTAssertTrue(vm.tocItems.isEmpty)
    }

    func testTOCLineNumbers() {
        let content = "intro\n# First\nsome text\n## Second"
        vm.refreshTOC(from: content)
        XCTAssertEqual(vm.tocItems.count, 2)
        XCTAssertEqual(vm.tocItems[0].line, 1)
        XCTAssertEqual(vm.tocItems[1].line, 3)
    }

    func testTOCSlugBasic() {
        vm.refreshTOC(from: "# Hello World")
        XCTAssertEqual(vm.tocItems[0].id, "hello-world")
    }

    func testTOCSlugFiltersSpecialChars() {
        vm.refreshTOC(from: "# Hello, World!")
        // comma and exclamation filtered; space becomes dash
        XCTAssertEqual(vm.tocItems[0].id, "hello-world")
    }

    func testSyncWorkspaceFromFile() {
        let url = URL(fileURLWithPath: "/tmp/test/notes.md")
        vm.syncWorkspace(from: url)
        XCTAssertEqual(vm.workspaceURL, URL(fileURLWithPath: "/tmp/test"))
    }

    func testSyncWorkspaceNilFileDoesNothing() {
        vm.syncWorkspace(from: nil)
        XCTAssertNil(vm.workspaceURL)
    }

    func testManualWorkspaceNotOverriddenByFileSync() {
        // Simulate manual workspace set
        vm.setManualWorkspace(URL(fileURLWithPath: "/tmp/manual"))
        // Then a file opens in a different directory
        vm.syncWorkspace(from: URL(fileURLWithPath: "/tmp/other/file.md"))
        // Manual workspace should be preserved
        XCTAssertEqual(vm.workspaceURL, URL(fileURLWithPath: "/tmp/manual"))
    }

    func testToggleDirExpands() {
        let url = URL(fileURLWithPath: "/tmp/folder")
        vm.toggleDir(url)
        XCTAssertTrue(vm.expandedDirs.contains(url))
        vm.toggleDir(url)
        XCTAssertFalse(vm.expandedDirs.contains(url))
    }
}
```

- [ ] **Step 3.2: Run to verify failure**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' \
  -only-testing:MarkdownEditorTests/SidebarViewModelTests/testInitialState 2>&1 | tail -10
```

Expected: compile error — `SidebarViewModel` not found

- [ ] **Step 3.3: Create SidebarViewModel.swift**

Create `MarkdownEditor/ViewModels/SidebarViewModel.swift`:

```swift
import AppKit
import Combine
import SwiftUI

enum SidebarTab: Equatable { case files, toc }

struct FileItem: Identifiable {
    let id: URL
    let name: String
    let url: URL
    let isDirectory: Bool
}

struct TOCItem: Identifiable {
    let id: String      // slug for JS anchor
    let title: String
    let level: Int      // 1–4
    let line: Int       // 0-based line index in content
}

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var isVisible: Bool = true
    @Published var activeTab: SidebarTab = .files
    @Published var workspaceURL: URL? = nil
    @Published var files: [FileItem] = []
    @Published var tocItems: [TOCItem] = []
    @Published var expandedDirs: Set<URL> = []

    private var manualWorkspace: Bool = false
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Binding

    /// Call once in App.onAppear to wire Combine subscriptions.
    func bind(to documentVM: DocumentViewModel) {
        documentVM.$fileURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in self?.syncWorkspace(from: url) }
            .store(in: &cancellables)

        documentVM.$content
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] content in self?.refreshTOC(from: content) }
            .store(in: &cancellables)
    }

    // MARK: - Workspace

    func syncWorkspace(from fileURL: URL?) {
        guard !manualWorkspace, let url = fileURL else { return }
        workspaceURL = url.deletingLastPathComponent()
        refreshFiles()
    }

    /// Used by tests to simulate a manual workspace selection.
    func setManualWorkspace(_ url: URL) {
        workspaceURL = url
        manualWorkspace = true
        expandedDirs = []
        refreshFiles()
    }

    @MainActor
    func openWorkspaceFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "选择工作区文件夹"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        setManualWorkspace(url)
    }

    func refreshFiles() {
        guard let root = workspaceURL else { files = []; return }
        files = loadItems(at: root)
    }

    func toggleDir(_ url: URL) {
        if expandedDirs.contains(url) {
            expandedDirs.remove(url)
        } else {
            expandedDirs.insert(url)
        }
    }

    func children(of url: URL) -> [FileItem] {
        loadItems(at: url)
    }

    // MARK: - TOC

    func refreshTOC(from content: String) {
        var items: [TOCItem] = []
        let lines = content.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            guard line.hasPrefix("#") else { continue }
            let level = line.prefix(while: { $0 == "#" }).count
            guard level >= 1, level <= 4 else { continue }
            let title = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            let slug = title.lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
            let safeSlug = slug.isEmpty ? "heading-\(index)" : slug
            items.append(TOCItem(id: safeSlug, title: title, level: level, line: index))
        }
        tocItems = items
    }

    // MARK: - Private

    private func loadItems(at url: URL) -> [FileItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return contents
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .compactMap { item -> FileItem? in
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return FileItem(id: item, name: item.lastPathComponent, url: item, isDirectory: isDir)
            }
    }
}
```

After creating this file, add it to the Xcode project by editing `MarkdownEditor.xcodeproj/project.pbxproj`. Find how `DocumentViewModel.swift` is referenced and add matching entries for `SidebarViewModel.swift` using two new UUIDs from `uuidgen`.

- [ ] **Step 3.4: Run all tests**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — all prior 28 tests pass plus the 11 new SidebarViewModelTests.

- [ ] **Step 3.5: Commit**

```bash
git add MarkdownEditor/ViewModels/SidebarViewModel.swift \
        MarkdownEditorTests/SidebarViewModelTests.swift \
        MarkdownEditor.xcodeproj/project.pbxproj
git commit -m "feat: add SidebarViewModel with file browser and TOC logic"
```

---

## Task 4: preview-template.html — Heading IDs

**Files:**
- Modify: `MarkdownEditor/Resources/preview-template.html`

- [ ] **Step 4.1: Add custom heading renderer**

Replace the entire `<script>` block in `MarkdownEditor/Resources/preview-template.html` with:

```html
<script>
  // Custom renderer: add id attributes to headings for TOC scroll anchors
  const headingRenderer = {
    heading(text, level) {
      const slug = text.toLowerCase()
        .replace(/\s+/g, '-')
        .replace(/[^\w-]/g, '');
      return '<h' + level + ' id="' + slug + '">' + text + '</h' + level + '>\n';
    }
  };

  marked.use({ gfm: true, breaks: false, renderer: headingRenderer });

  window.__updateContent = function(b64) {
    try {
      var raw = atob(b64);
      var bytes = new Uint8Array(raw.length);
      for (var i = 0; i < raw.length; i++) { bytes[i] = raw.charCodeAt(i); }
      var text = new TextDecoder('utf-8').decode(bytes);
      document.getElementById('content').innerHTML = marked.parse(text);
      document.querySelectorAll('pre code').forEach(function(block) {
        hljs.highlightElement(block);
      });
    } catch(e) {
      console.error('__updateContent error:', e);
    }
  };

  window.__setTheme = function(theme) {
    document.documentElement.setAttribute('data-theme', theme);
  };
</script>
```

- [ ] **Step 4.2: Build**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4.3: Commit**

```bash
git add MarkdownEditor/Resources/preview-template.html
git commit -m "feat: add heading id attributes to preview renderer for TOC anchors"
```

---

## Task 5: EditorView + PreviewView — TOC Navigation Response

**Files:**
- Modify: `MarkdownEditor/Views/EditorView.swift`
- Modify: `MarkdownEditor/Views/PreviewView.swift`

- [ ] **Step 5.1: Update EditorView.updateNSView to handle scrollToLine**

In `MarkdownEditor/Views/EditorView.swift`, replace the entire `updateNSView` method with:

```swift
func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let textView = context.coordinator.textView

    // Sync content
    if textView.string != viewModel.content {
        let sel = textView.selectedRange()
        textView.string = viewModel.content
        let safeRange = NSRange(location: min(sel.location, viewModel.content.utf16.count), length: 0)
        textView.setSelectedRange(safeRange)
    }

    // Highlight find result
    if let range = viewModel.findResult,
       range != context.coordinator.lastHighlightedRange {
        context.coordinator.lastHighlightedRange = range
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    } else if viewModel.findResult == nil {
        context.coordinator.lastHighlightedRange = nil
        textView.setSelectedRange(NSRange(location: textView.selectedRange().location, length: 0))
    }

    // TOC jump: scroll editor to target line
    if let targetLine = viewModel.scrollToLine {
        let lines = viewModel.content.components(separatedBy: "\n")
        if targetLine < lines.count {
            let prefix = lines[0..<targetLine].joined(separator: "\n")
            let charOffset = prefix.utf16.count + (targetLine > 0 ? 1 : 0)
            let location = min(charOffset, viewModel.content.utf16.count)
            let range = NSRange(location: location, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
        }
        DispatchQueue.main.async { self.viewModel.scrollToLine = nil }
    }
}
```

- [ ] **Step 5.2: Update PreviewView.updateNSView to handle scrollToHeadingID**

In `MarkdownEditor/Views/PreviewView.swift`, replace `updateNSView` with:

```swift
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
```

- [ ] **Step 5.3: Build**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5.4: Commit**

```bash
git add MarkdownEditor/Views/EditorView.swift \
        MarkdownEditor/Views/PreviewView.swift
git commit -m "feat: EditorView + PreviewView respond to TOC navigation signals"
```

---

## Task 6: SidebarView + FileBrowserView + TOCView

**Files:**
- Create: `MarkdownEditor/Views/SidebarView.swift`
- Create: `MarkdownEditor/Views/FileBrowserView.swift`
- Create: `MarkdownEditor/Views/TOCView.swift`

All three files must be added to the Xcode project's `project.pbxproj` (same technique as Task 3).

- [ ] **Step 6.1: Create SidebarView.swift**

```swift
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Icon Tab bar
            HStack(spacing: 0) {
                tabButton(icon: "folder", tab: .files, help: "文件浏览器")
                tabButton(icon: "list.bullet.indent", tab: .toc, help: "标题目录")
                Spacer()
                Button {
                    Task { await sidebarVM.openWorkspaceFolder() }
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.borderless)
                .help("打开文件夹")
            }
            .frame(height: 32)
            .background(.bar)

            Divider()

            Group {
                switch sidebarVM.activeTab {
                case .files: FileBrowserView()
                case .toc:   TOCView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(icon: String, tab: SidebarTab, help: String) -> some View {
        Button { sidebarVM.activeTab = tab } label: {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(sidebarVM.activeTab == tab ? Color.accentColor : .secondary)
                    .frame(height: 28)
                Rectangle()
                    .frame(height: 2)
                    .foregroundStyle(sidebarVM.activeTab == tab ? Color.accentColor : Color.clear)
            }
            .frame(width: 36)
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
```

- [ ] **Step 6.2: Create FileBrowserView.swift**

```swift
import SwiftUI

struct FileBrowserView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        ScrollView {
            if sidebarVM.workspaceURL == nil {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("打开文件夹以浏览")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("打开文件夹…") {
                        Task { await sidebarVM.openWorkspaceFolder() }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sidebarVM.files) { item in
                        FileRowView(item: item, depth: 0)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct FileRowView: View {
    let item: FileItem
    let depth: Int
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    private var isCurrentFile: Bool {
        !item.isDirectory && item.url == documentVM.fileURL
    }

    private var isExpanded: Bool {
        sidebarVM.expandedDirs.contains(item.url)
    }

    private var icon: String {
        if item.isDirectory {
            return isExpanded ? "folder.open" : "folder"
        }
        let ext = item.url.pathExtension.lowercased()
        return ["md", "markdown", "txt"].contains(ext) ? "doc.text" : "doc"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if item.isDirectory {
                    sidebarVM.toggleDir(item.url)
                } else {
                    documentVM.openDocument(url: item.url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                        .foregroundStyle(isCurrentFile ? .white : .secondary)
                        .frame(width: 14)
                    Text(item.name)
                        .font(.system(size: 12))
                        .foregroundStyle(isCurrentFile ? .white : .primary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, 3)
                .padding(.leading, CGFloat(depth) * 12 + 8)
                .padding(.trailing, 8)
                .background(isCurrentFile ? Color.accentColor : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            if item.isDirectory && isExpanded {
                ForEach(sidebarVM.children(of: item.url)) { child in
                    FileRowView(item: child, depth: depth + 1)
                }
            }
        }
    }
}
```

- [ ] **Step 6.3: Create TOCView.swift**

```swift
import SwiftUI

struct TOCView: View {
    @EnvironmentObject var sidebarVM: SidebarViewModel
    @EnvironmentObject var documentVM: DocumentViewModel

    var body: some View {
        ScrollView {
            if sidebarVM.tocItems.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("文档中暂无标题")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sidebarVM.tocItems) { item in
                        Button {
                            documentVM.scrollToLine = item.line
                            documentVM.scrollToHeadingID = item.id
                        } label: {
                            Text(item.title)
                                .font(.system(size: 12,
                                              weight: item.level == 1 ? .medium : .regular))
                                .foregroundStyle(item.level == 1 ? Color.primary : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.leading, CGFloat(item.level - 1) * 12 + 8)
                                .padding(.trailing, 8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
```

- [ ] **Step 6.4: Add all three files to project.pbxproj**

For each new file, run `uuidgen` twice to get two UUIDs (one for `PBXFileReference`, one for `PBXBuildFile`). Add them following the exact same pattern used for `FindBarView.swift` in the project file. The three files go in the `Views` group.

- [ ] **Step 6.5: Build**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6.6: Commit**

```bash
git add MarkdownEditor/Views/SidebarView.swift \
        MarkdownEditor/Views/FileBrowserView.swift \
        MarkdownEditor/Views/TOCView.swift \
        MarkdownEditor.xcodeproj/project.pbxproj
git commit -m "feat: add SidebarView, FileBrowserView, and TOCView"
```

---

## Task 7: Wiring — ContentView + FileCommands + MarkdownEditorApp

**Files:**
- Modify: `MarkdownEditor/Views/ContentView.swift`
- Modify: `MarkdownEditor/App/FileCommands.swift`
- Modify: `MarkdownEditor/App/MarkdownEditorApp.swift`

- [ ] **Step 7.1: Update ContentView to three-column layout**

Replace entire `MarkdownEditor/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: DocumentViewModel
    @EnvironmentObject var sidebarVM: SidebarViewModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                HSplitView {
                    // Left: Sidebar
                    SidebarView()
                        .frame(
                            minWidth: sidebarVM.isVisible ? 160 : 0,
                            maxWidth: sidebarVM.isVisible ? 280 : 0
                        )
                        .opacity(sidebarVM.isVisible ? 1 : 0)

                    // Centre: Editor
                    EditorView()
                        .frame(minWidth: 200)

                    // Right: Preview
                    PreviewView()
                        .frame(
                            minWidth: viewModel.showPreview ? 200 : 0,
                            maxWidth: viewModel.showPreview ? .infinity : 0
                        )
                        .opacity(viewModel.showPreview ? 1 : 0)
                }

                // Floating preview toggle — bottom-right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            viewModel.showPreview.toggle()
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

                // Find bar slides in from top
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

- [ ] **Step 7.2: Update FileCommands to accept SidebarViewModel + add sidebar commands**

Replace entire `MarkdownEditor/App/FileCommands.swift`:

```swift
import SwiftUI

struct FileCommands: Commands {
    let viewModel: DocumentViewModel
    let sidebarVM: SidebarViewModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("新建") {
                if viewModel.isModified {
                    confirmDiscard { viewModel.newDocument() }
                } else {
                    viewModel.newDocument()
                }
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("打开…") {
                Task {
                    if viewModel.isModified {
                        await confirmDiscardAsync { await viewModel.openDocument() }
                    } else {
                        await viewModel.openDocument()
                    }
                }
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandGroup(replacing: .saveItem) {
            Button("存储") {
                Task { await viewModel.saveDocument() }
            }
            .keyboardShortcut("s", modifiers: .command)

            Button("存储为…") {
                Task { await viewModel.saveDocumentAs() }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
        }

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

        CommandGroup(after: .sidebar) {
            Button(sidebarVM.isVisible ? "隐藏侧边栏" : "显示侧边栏") {
                sidebarVM.isVisible.toggle()
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("打开文件夹…") {
                Task { await sidebarVM.openWorkspaceFolder() }
            }

            Divider()

            Button(viewModel.showPreview ? "隐藏预览" : "显示预览") {
                viewModel.showPreview.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(after: .textEditing) {
            Button("查找/替换") {
                viewModel.showFindBar.toggle()
                if !viewModel.showFindBar { viewModel.findResult = nil }
            }
            .keyboardShortcut("f", modifiers: .command)
        }
    }

    // MARK: - Helpers

    private func confirmDiscard(_ action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "是否放弃更改？"
        alert.informativeText = "你有未保存的更改，继续将丢失这些更改。"
        alert.addButton(withTitle: "放弃更改")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn { action() }
    }

    private func confirmDiscardAsync(_ action: @escaping () async -> Void) async {
        await MainActor.run {
            confirmDiscard { Task { await action() } }
        }
    }
}
```

- [ ] **Step 7.3: Update MarkdownEditorApp to inject SidebarViewModel**

Replace entire `MarkdownEditor/App/MarkdownEditorApp.swift`:

```swift
import SwiftUI

@main
struct MarkdownEditorApp: App {
    @StateObject private var viewModel = DocumentViewModel()
    @StateObject private var sidebarVM = SidebarViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(sidebarVM)
                .frame(minWidth: 800, minHeight: 500)
                .onOpenURL { url in
                    viewModel.openDocument(url: url)
                }
                .onAppear {
                    sidebarVM.bind(to: viewModel)
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            FileCommands(viewModel: viewModel, sidebarVM: sidebarVM)
        }
    }
}
```

- [ ] **Step 7.4: Build**

```bash
xcodebuild -project MarkdownEditor.xcodeproj -scheme MarkdownEditor build 2>&1 | tail -10
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7.5: Run all tests**

```bash
xcodebuild test -project MarkdownEditor.xcodeproj -scheme MarkdownEditor \
  -destination 'platform=macOS' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` — all 39 tests pass (28 existing + 11 sidebar).

- [ ] **Step 7.6: Commit**

```bash
git add MarkdownEditor/Views/ContentView.swift \
        MarkdownEditor/App/FileCommands.swift \
        MarkdownEditor/App/MarkdownEditorApp.swift
git commit -m "feat: wire sidebar into three-column layout with Cmd+\\ toggle"
```

---

## Self-Review

**Spec coverage:**
- [x] Copy bug fix — Task 1 (`CommandGroup(replacing: .pasteboard)`)
- [x] `DocumentViewModel.scrollToLine` — Task 2
- [x] `DocumentViewModel.scrollToHeadingID` — Task 2
- [x] `SidebarViewModel` with all state and methods — Task 3
- [x] `SidebarViewModelTests` (11 tests) — Task 3
- [x] Heading ID renderer in `preview-template.html` — Task 4
- [x] `EditorView` responds to `scrollToLine` — Task 5
- [x] `PreviewView` responds to `scrollToHeadingID` — Task 5
- [x] `SidebarView` with icon Tab bar — Task 6
- [x] `FileBrowserView` with expand/collapse and current-file highlight — Task 6
- [x] `TOCView` with indentation and click-to-navigate — Task 6
- [x] Three-column `ContentView` — Task 7
- [x] Cmd+\\ sidebar toggle in `FileCommands` — Task 7
- [x] "打开文件夹" menu item — Task 7
- [x] `SidebarViewModel.bind(to:)` called in `MarkdownEditorApp.onAppear` — Task 7
- [x] `sidebarVM` injected as `@EnvironmentObject` — Task 7

**Placeholder scan:** No TBD, TODO, or vague steps found.

**Type consistency:**
- `SidebarTab` enum defined in Task 3, used in Tasks 6 and 7 ✓
- `FileItem.id: URL` defined in Task 3, used in `FileRowView` Task 6 ✓
- `TOCItem.line: Int` defined in Task 3, consumed by `documentVM.scrollToLine` Task 6 ✓
- `TOCItem.id: String` (slug) defined in Task 3, consumed by `documentVM.scrollToHeadingID` Task 6 ✓
- `sidebarVM.setManualWorkspace(_:)` defined in Task 3, used in test `testManualWorkspaceNotOverriddenByFileSync` Task 3 ✓
- `FileCommands(viewModel:sidebarVM:)` takes two args — defined Task 7, call site Task 7 ✓
- `SidebarView` uses `@EnvironmentObject var sidebarVM: SidebarViewModel` — injected in Task 7 ✓
