import XCTest
import Combine
@testable import MarkdownEditor

@MainActor
final class TabsViewModelTests: XCTestCase {
    var vm: TabsViewModel!

    override func setUp() {
        vm = TabsViewModel()
    }

    func testInitialStateHasOneTab() {
        XCTAssertEqual(vm.tabs.count, 1)
        XCTAssertNotNil(vm.activeTabID)
        XCTAssertEqual(vm.tabs[0].id, vm.activeTabID)
    }

    func testInitialTabIsUntitled() {
        XCTAssertEqual(vm.tabs[0].title, "未命名")
        XCTAssertNil(vm.tabs[0].url)
        XCTAssertFalse(vm.tabs[0].isModified)
    }

    func testAddTabIncreasesCount() {
        vm.addTab()
        XCTAssertEqual(vm.tabs.count, 2)
    }

    func testAddTabActivatesNewTab() {
        let id = vm.addTab()
        XCTAssertEqual(vm.activeTabID, id)
    }

    func testCloseLastTabKeepsOne() {
        let id = vm.tabs[0].id
        vm.closeTab(id: id)
        XCTAssertEqual(vm.tabs.count, 1)
        XCTAssertNotNil(vm.activeTabID)
    }

    func testCloseActiveTabActivatesAdjacent() {
        let id1 = vm.tabs[0].id
        let id2 = vm.addTab()
        vm.activateTab(id: id2)
        vm.closeTab(id: id2)
        XCTAssertEqual(vm.activeTabID, id1)
    }

    func testCloseNonActiveTabPreservesActive() {
        let id1 = vm.tabs[0].id
        let id2 = vm.addTab()
        vm.activateTab(id: id1)
        vm.closeTab(id: id2)
        XCTAssertEqual(vm.activeTabID, id1)
        XCTAssertEqual(vm.tabs.count, 1)
    }

    func testOpenTabDeduplicatesURL() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let id1 = vm.openTab(url: url, content: "hello")
        let id2 = vm.openTab(url: url, content: "hello")
        XCTAssertEqual(id1, id2)
        XCTAssertEqual(vm.tabs.count, 2) // initial untitled + 1 deduped
    }

    func testOpenTabAddsNewForDifferentURL() {
        let url1 = URL(fileURLWithPath: "/tmp/a.md")
        let url2 = URL(fileURLWithPath: "/tmp/b.md")
        vm.openTab(url: url1, content: "")
        vm.openTab(url: url2, content: "")
        XCTAssertEqual(vm.tabs.count, 3)
    }

    func testSnapshotActiveTab() {
        let docVM = DocumentViewModel()
        docVM.updateContent("test content")
        vm.snapshotActiveTab(from: docVM)
        XCTAssertEqual(vm.activeTab?.content, "test content")
    }

    func testLoadTabIntoDocVM() {
        let url = URL(fileURLWithPath: "/tmp/sample.md")
        let id = vm.openTab(url: url, content: "loaded text")
        vm.activateTab(id: id)
        let docVM = DocumentViewModel()
        vm.loadTab(id: id, into: docVM)
        XCTAssertEqual(docVM.content, "loaded text")
        XCTAssertEqual(docVM.fileURL, url)
    }

    func testSelectNextTab() {
        vm.addTab()
        vm.activateTab(id: vm.tabs[0].id)
        vm.selectNextTab()
        XCTAssertEqual(vm.activeTabID, vm.tabs[1].id)
    }

    func testSelectPreviousTabWrapsAround() {
        vm.addTab()
        vm.activateTab(id: vm.tabs[0].id)
        vm.selectPreviousTab()
        XCTAssertEqual(vm.activeTabID, vm.tabs[1].id) // wraps to last
    }

    func testUpdateActiveTabModified() {
        vm.updateActiveTabModified(true, url: nil)
        XCTAssertTrue(vm.activeTab?.isModified == true)
    }

    func testMarkTabSaved() {
        let url = URL(fileURLWithPath: "/tmp/saved.md")
        guard let id = vm.activeTabID else { return XCTFail() }
        vm.markTabSaved(id: id, url: url)
        XCTAssertFalse(vm.activeTab?.isModified ?? true)
        XCTAssertEqual(vm.activeTab?.url, url)
        XCTAssertEqual(vm.activeTab?.title, "saved.md")
    }
}
