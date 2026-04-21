import XCTest
import BASHostKit
@testable import SampleHost

@MainActor
final class SampleHostTests: XCTestCase {
    func testBootstrapCreatesCurrentBrain() {
        let model = SampleHostModel()

        XCTAssertFalse(model.result.currentBrain.dominantGoals.isEmpty)
        XCTAssertFalse(model.result.consoleSnapshot.reports.isEmpty)
        XCTAssertEqual(model.result.activeSessionTitle, "SampleHost Bootstrap")
        XCTAssertTrue(model.result.notices.contains("Refresh substrate projection"))
    }

    func testReflectiveSessionUpdatesMode() {
        let model = SampleHostModel()

        model.start(.reflective)

        XCTAssertEqual(model.result.currentBrain.workflowProfile, .reflective)
        XCTAssertEqual(model.result.currentBrain.workflowTitle, "Signal Lens")
        XCTAssertEqual(model.result.requestKind.rawValue, "interactive")
        XCTAssertEqual(model.result.workflowProfile.rawValue, "reflective")
        XCTAssertEqual(model.result.activeSessionTitle, "Signal Lens from SampleHost")
        XCTAssertTrue(model.result.notices.contains("Application entered the signal lens lane in SampleHost."))
        XCTAssertEqual(model.result.interventionSuggestion?.title, "Run this through Contrast Lens first.")
        XCTAssertEqual(model.result.interventionSuggestion?.preferredWorkflowProfile, .comparative)
        XCTAssertEqual(model.result.projection.activeTemplateIDs, ["samplehost.template.signal-lens"])
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

    func testWindGatePresentationSupportHumanizesInternalIdentifiers() {
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.modeLabel(.draftOnly),
            "draft only"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.modeLabels([.draftOnly, .localOnly, .mirror]),
            "draft only • local only • mirror"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.domainList([
                "bounded_reply",
                "tool_commit",
                "memory_commit"
            ]),
            "bounded reply • tool commit • memory commit"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.humanizedToken("cool_down"),
            "cool down"
        )
        XCTAssertEqual(
            SampleHostWindGatePresentationSupport.humanizedToken("local_only_action"),
            "local only action"
        )
    }
}
