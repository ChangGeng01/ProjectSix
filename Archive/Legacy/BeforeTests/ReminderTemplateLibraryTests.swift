import XCTest
@testable import Before

final class ReminderTemplateLibraryTests: XCTestCase {
    func testBuyTemplatesStayShortAndUseful() {
        let templates = ReminderTemplateLibrary.templates(for: .buy, outcome: .regrettedIt)
        XCTAssertEqual(templates.count, 3)
        XCTAssertTrue(templates.allSatisfy { !$0.isEmpty && $0.count < 100 })
    }
}
