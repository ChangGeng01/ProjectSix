import XCTest
@testable import Before

final class DecisionEvolutionSurfaceContractTests: XCTestCase {
    func testSurfaceContractMatrixMatchesOperatorIntent() {
        let home = DecisionEvolutionSurfaceContract.contract(for: .home)
        let history = DecisionEvolutionSurfaceContract.contract(for: .history)
        let portrait = DecisionEvolutionSurfaceContract.contract(for: .portrait)
        let settings = DecisionEvolutionSurfaceContract.contract(for: .settings)
        let controlCenter = DecisionEvolutionSurfaceContract.contract(for: .controlCenter)

        XCTAssertEqual(home.interactionMode, .observeAndRoute)
        XCTAssertEqual(home.releaseSummaryMode, .surface)
        XCTAssertTrue(home.routesMutationsToControlCenter)
        XCTAssertTrue(home.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(home.showsCheckpointActionBarInSummary)

        XCTAssertEqual(history.interactionMode, .observeAndRoute)
        XCTAssertEqual(history.releaseSummaryMode, .compact)
        XCTAssertTrue(history.routesMutationsToControlCenter)
        XCTAssertTrue(history.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(history.showsCheckpointActionBarInSummary)

        XCTAssertEqual(portrait.interactionMode, .observeAndRoute)
        XCTAssertEqual(portrait.releaseSummaryMode, .surface)
        XCTAssertTrue(portrait.routesMutationsToControlCenter)
        XCTAssertTrue(portrait.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(portrait.showsCheckpointActionBarInSummary)

        XCTAssertEqual(settings.interactionMode, .observeAndRoute)
        XCTAssertEqual(settings.releaseSummaryMode, .compact)
        XCTAssertTrue(settings.routesMutationsToControlCenter)
        XCTAssertFalse(settings.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertFalse(settings.showsCheckpointActionBarInSummary)

        XCTAssertEqual(controlCenter.interactionMode, .mutationHub)
        XCTAssertEqual(controlCenter.releaseSummaryMode, .mutationHub)
        XCTAssertFalse(controlCenter.routesMutationsToControlCenter)
        XCTAssertFalse(controlCenter.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertFalse(controlCenter.showsCheckpointActionBarInSummary)
    }

    func testReleaseSummaryPresentationModesExposeExpectedRenderingContract() {
        XCTAssertTrue(DecisionEvolutionReleaseSummaryPresentationMode.surface.showsCheckpointHeadlines)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.surface.operatorHeadline)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.surface.operatorDetail)

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.compact.showsCheckpointHeadlines)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.compact.operatorHeadline)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.compact.operatorDetail)

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.showsCheckpointHeadlines)
        XCTAssertEqual(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.operatorHeadline, "Mutation hub")
        XCTAssertNotNil(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.operatorDetail)
    }
}
