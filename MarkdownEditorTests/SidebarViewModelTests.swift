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
        XCTAssertEqual(vm.tocItems[0].id, "hello-world")
    }

    func testSyncWorkspaceFromFile() {
        let url = URL(fileURLWithPath: "/tmp/test/notes.md")
        vm.syncWorkspace(from: url)
        XCTAssertEqual(vm.workspaceURL?.path, "/tmp/test")
    }

    func testSyncWorkspaceNilFileDoesNothing() {
        vm.syncWorkspace(from: nil)
        XCTAssertNil(vm.workspaceURL)
    }

    func testManualWorkspaceNotOverriddenByFileSync() {
        vm.setManualWorkspace(URL(fileURLWithPath: "/tmp/manual"))
        vm.syncWorkspace(from: URL(fileURLWithPath: "/tmp/other/file.md"))
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
