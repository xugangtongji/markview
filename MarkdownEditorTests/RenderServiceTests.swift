import XCTest
@testable import MarkdownEditor

final class RenderServiceTests: XCTestCase {
    func testPassthroughRendererReturnsInput() {
        let renderer: RenderService = PassthroughRenderer()
        let markdown = "# Title\n\nParagraph with **bold**."
        XCTAssertEqual(renderer.render(markdown: markdown), markdown)
    }

    func testRendererIsReplaceable() {
        // Verify the protocol can be satisfied by an alternative implementation
        struct EchoRenderer: RenderService {
            func render(markdown: String) -> String { markdown + "\n<!-- rendered -->" }
        }
        let renderer: RenderService = EchoRenderer()
        XCTAssertTrue(renderer.render(markdown: "test").contains("<!-- rendered -->"))
    }
}
