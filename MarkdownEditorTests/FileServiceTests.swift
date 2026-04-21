import XCTest
@testable import MarkdownEditor

final class FileServiceTests: XCTestCase {
    private let service = FileService()
    private var tempURL: URL!

    override func setUpWithError() throws {
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testSaveAndReadRoundtrip() throws {
        let original = "# Hello\n\nThis is a **test**."
        try service.saveDocument(content: original, to: tempURL)
        let read = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(read, original)
    }

    func testSaveUnicodeContent() throws {
        let emoji = "# 你好 👋\n\n日本語テスト"
        try service.saveDocument(content: emoji, to: tempURL)
        let read = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(read, emoji)
    }

    func testSaveOverwritesExistingFile() throws {
        try service.saveDocument(content: "first", to: tempURL)
        try service.saveDocument(content: "second", to: tempURL)
        let read = try String(contentsOf: tempURL, encoding: .utf8)
        XCTAssertEqual(read, "second")
    }
}
