import XCTest
import Combine
@testable import MarkdownEditor

@MainActor
final class DocumentViewModelTests: XCTestCase {
    var vm: DocumentViewModel!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        vm = DocumentViewModel()
        cancellables = []
    }

    func testInitialState() {
        XCTAssertEqual(vm.content, "")
        XCTAssertNil(vm.fileURL)
        XCTAssertFalse(vm.isModified)
        XCTAssertEqual(vm.cursorLine, 1)
        XCTAssertEqual(vm.cursorColumn, 1)
    }

    func testUpdateContentSetsModified() {
        vm.updateContent("Hello")
        XCTAssertTrue(vm.isModified)
        XCTAssertEqual(vm.content, "Hello")
    }

    func testNewDocumentResetsState() {
        vm.updateContent("some text")
        vm.newDocument()
        XCTAssertEqual(vm.content, "")
        XCTAssertFalse(vm.isModified)
        XCTAssertNil(vm.fileURL)
    }

    func testWindowTitleWithoutFile() {
        XCTAssertEqual(vm.windowTitle, "未命名")
    }

    func testWindowTitleModified() {
        vm.updateContent("x")
        XCTAssertTrue(vm.windowTitle.contains("●"))
    }

    func testCursorUpdate() {
        vm.updateCursor(line: 5, column: 12)
        XCTAssertEqual(vm.cursorLine, 5)
        XCTAssertEqual(vm.cursorColumn, 12)
    }

    func testShowPreviewDefaultsTrue() {
        XCTAssertTrue(vm.showPreview)
    }

    func testTogglePreview() {
        vm.showPreview = false
        XCTAssertFalse(vm.showPreview)
        vm.showPreview = true
        XCTAssertTrue(vm.showPreview)
    }

    func testRenderTriggerDebounce() {
        let expectation = expectation(description: "renderTrigger fires after debounce")
        var fired = false

        vm.$renderTrigger
            .dropFirst()
            .sink { _ in
                if !fired {
                    fired = true
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        vm.updateContent("# Debounce test")
        wait(for: [expectation], timeout: 1.0)
    }
}
