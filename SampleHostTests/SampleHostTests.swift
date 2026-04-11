import XCTest
@testable import SampleHost

@MainActor
final class SampleHostTests: XCTestCase {
    func testBootstrapCreatesCurrentBrain() {
        let model = SampleHostModel()

        XCTAssertFalse(model.result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(model.result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(model.result.activeSessionTitle, "SampleHost Bootstrap")
        XCTAssertTrue(model.result.notices.contains("Refresh memory projection"))
    }

    func testReflectiveSessionUpdatesMode() {
        let model = SampleHostModel()

        model.start(.reflective)

        XCTAssertEqual(model.result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(model.result.currentBrain.workflowTitle, "Reflective Lens")
        XCTAssertEqual(model.result.requestKind.rawValue, "interactive")
        XCTAssertEqual(model.result.workflowProfile.rawValue, "reflective")
        XCTAssertEqual(model.result.activeSessionTitle, "Reflective from SampleHost")
        XCTAssertTrue(model.result.notices.contains("Application entered the reflective lens lane in SampleHost."))
        XCTAssertEqual(model.result.projection.activeTemplateIDs, ["samplehost.template.reflective-lens"])
        XCTAssertTrue(model.result.currentBrain.verificationSummary.hasPrefix("samplehost/"))
    }

    func testReopenProducesSuggestion() {
        let model = SampleHostModel()

        model.reopen()

        XCTAssertEqual(model.result.requestKind.rawValue, "reopen")
        XCTAssertNotNil(model.result.interventionSuggestion)
        XCTAssertEqual(model.result.interventionSuggestion?.title, "Reopen with more structure")
        XCTAssertTrue(model.result.notices.contains("Use a cooling template before acting."))
    }
}
