import XCTest
@testable import Before

final class SupportRequestKindTests: XCTestCase {
    func testKindsExposeDistinctTitlesAndDefaults() {
        XCTAssertEqual(SupportRequestKind.holdMe10Minutes.title, "Hold me for 10 minutes")
        XCTAssertEqual(SupportRequestKind.helpMeJudgeThis.title, "Help me judge this")
        XCTAssertEqual(SupportRequestKind.iAmGettingBlurry.title, "I am getting blurry")

        XCTAssertFalse(SupportRequestKind.holdMe10Minutes.defaultMessage.isEmpty)
        XCTAssertFalse(SupportRequestKind.helpMeJudgeThis.quickReplies.isEmpty)
        XCTAssertFalse(SupportRequestKind.iAmGettingBlurry.subtitle.isEmpty)
    }
}
