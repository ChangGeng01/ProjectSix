import XCTest
@testable import SampleHost

@MainActor
final class SampleHostTests: XCTestCase {
    func testBootstrapCreatesCurrentBrain() {
        let model = SampleHostModel()

        XCTAssertFalse(model.result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(model.result.consoleSnapshot.reports.isEmpty)
    }

    func testMirrorSessionUpdatesMode() {
        let model = SampleHostModel()

        model.start(.mirror)

        XCTAssertEqual(model.result.currentBrain.mode, "mirror")
        XCTAssertEqual(model.result.requestKind.rawValue, "mirror")
    }

    func testReopenProducesSuggestion() {
        let model = SampleHostModel()

        model.reopen()

        XCTAssertEqual(model.result.requestKind.rawValue, "reopen")
        XCTAssertNotNil(model.result.interventionSuggestion)
    }
}
