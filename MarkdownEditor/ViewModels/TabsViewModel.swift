import Combine
import Foundation
import SwiftUI

// MARK: - TabItem

struct TabItem: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var title: String
    var content: String
    var isModified: Bool
    var cursorLine: Int
    var cursorColumn: Int
    var scrollFraction: Double

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "未命名",
        content: String = "",
        isModified: Bool = false,
        cursorLine: Int = 1,
        cursorColumn: Int = 1,
        scrollFraction: Double = 0
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.content = content
        self.isModified = isModified
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.scrollFraction = scrollFraction
    }
}

// MARK: - TabsViewModel

@MainActor
final class TabsViewModel: ObservableObject {
    @Published private(set) var tabs: [TabItem] = []
    @Published private(set) var activeTabID: UUID?

    var activeTab: TabItem? { tabs.first { $0.id == activeTabID } }
    var activeIndex: Int? { tabs.firstIndex { $0.id == activeTabID } }

    // MARK: - Init

    init() {
        let initial = TabItem()
        tabs = [initial]
        activeTabID = initial.id
    }

    // MARK: - Tab Management

    /// Add a new empty tab and activate it. Returns the new tab's ID.
    @discardableResult
    func addTab() -> UUID {
        let tab = TabItem()
        tabs.append(tab)
        activeTabID = tab.id
        return tab.id
    }

    /// Open a file URL in a new tab (or activate existing tab for that URL). Returns the tab ID.
    @discardableResult
    func openTab(url: URL, content: String) -> UUID {
        if let existing = tabs.first(where: { $0.url == url }) {
            activeTabID = existing.id
            return existing.id
        }
        let tab = TabItem(url: url, title: url.lastPathComponent, content: content)
        tabs.append(tab)
        activeTabID = tab.id
        return tab.id
    }

    /// Close tab by ID. Activates adjacent tab. Always keeps at least one tab open.
    @discardableResult
    func closeTab(id: UUID) -> Bool {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return !tabs.isEmpty }
        tabs.remove(at: index)
        if tabs.isEmpty {
            let fresh = TabItem()
            tabs.append(fresh)
            activeTabID = fresh.id
        } else if activeTabID == id {
            activeTabID = tabs[max(0, index - 1)].id
        }
        return true
    }

    /// Activate an existing tab by ID.
    func activateTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
    }

    /// Snapshot DocumentViewModel state into the currently active tab.
    func snapshotActiveTab(from docVM: DocumentViewModel) {
        guard let id = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].content = docVM.content
        tabs[index].url = docVM.fileURL
        tabs[index].title = docVM.fileURL?.lastPathComponent ?? "未命名"
        tabs[index].isModified = docVM.isModified
        tabs[index].cursorLine = docVM.cursorLine
        tabs[index].cursorColumn = docVM.cursorColumn
        tabs[index].scrollFraction = docVM.scrollFraction
    }

    /// Load a tab's state into DocumentViewModel.
    func loadTab(id: UUID, into docVM: DocumentViewModel) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        docVM.loadFromTab(tab)
    }

    /// Update isModified + title for the active tab (called on content changes).
    func updateActiveTabModified(_ isModified: Bool, url: URL?) {
        guard let id = activeTabID,
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isModified = isModified
        if let url {
            tabs[index].url = url
            tabs[index].title = url.lastPathComponent
        }
    }

    /// Update tab state after a successful save.
    func markTabSaved(id: UUID, url: URL) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[index].isModified = false
        tabs[index].url = url
        tabs[index].title = url.lastPathComponent
    }

    // MARK: - Navigation

    func selectPreviousTab() {
        guard let index = activeIndex, tabs.count > 1 else { return }
        activeTabID = tabs[(index - 1 + tabs.count) % tabs.count].id
    }

    func selectNextTab() {
        guard let index = activeIndex, tabs.count > 1 else { return }
        activeTabID = tabs[(index + 1) % tabs.count].id
    }
}
