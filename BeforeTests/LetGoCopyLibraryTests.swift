import XCTest
@testable import Before

final class LetGoCopyLibraryTests: XCTestCase {
    func testTomorrowBoxContextForQuickUsesHomeAndBoxTargets() {
        let item = TomorrowBoxItem(
            dueAt: .now.addingTimeInterval(3_600),
            mode: .quick,
            title: "Buy this now?",
            detail: "A quick urge that can wait.",
            prompt: "Should I buy it?",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.tomorrowBoxContext(for: item)

        XCTAssertEqual(context.mode, .quick)
        XCTAssertEqual(context.primaryTarget, .home)
        XCTAssertEqual(context.secondaryTarget, .box)
        XCTAssertEqual(context.eyebrow, "Tomorrow Box")
        XCTAssertFalse(context.title.isEmpty)
    }

    func testTomorrowBoxContextForMirrorUsesStageEndingLanguage() {
        let item = TomorrowBoxItem(
            dueAt: .now.addingTimeInterval(3_600),
            mode: .mirror,
            title: "Should I keep doing this?",
            detail: "A heavier question that needs distance.",
            prompt: "Should I stay?",
            entrySource: .app
        )

        let context = LetGoCopyLibrary.tomorrowBoxContext(for: item)

        XCTAssertEqual(context.mode, .mirror)
        XCTAssertTrue(context.title.contains("enough"))
        XCTAssertTrue(context.completionSubtitle.contains("evening"))
    }
}
