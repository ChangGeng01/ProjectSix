import XCTest
@testable import BASOrchestration

final class BASTribunalCoverageCheckTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func vote(
        voice: BASTribunalVoice,
        subjectID: String,
        disposition: BASTribunalDisposition = .affirm
    ) -> BASTribunalObservation {
        BASTribunalObservation(
            kind: .vote,
            voice: voice,
            disposition: disposition,
            subjectID: subjectID,
            salience: 0.5,
            confidence: 1.0,
            content: "test",
            observedAt: now)
    }

    private func tribunalSignal(
        _ kind: BASTribunalSignalKind,
        subjectID: String = "subject-default"
    ) -> BASTribunalObservation {
        BASTribunalObservation(
            kind: kind,
            voice: nil,
            disposition: nil,
            subjectID: subjectID,
            salience: 0.5,
            confidence: 1.0,
            content: "tribunal-wide",
            observedAt: now)
    }

    private func bundle(
        _ obs: [BASTribunalObservation]
    ) -> BASTribunalObservationBundle {
        BASTribunalObservationBundle(
            turnID: "t-1",
            sessionID: "s-1",
            observations: obs,
            emittedAt: now)
    }

    func testEmptyBundleStatusEmpty() {
        let report = BASTribunalCoverageCheck.report(
            for: bundle([]))
        XCTAssertEqual(report.statusCode, "empty")
        XCTAssertTrue(report.voicesPresent.isEmpty)
        XCTAssertFalse(report.isFullBody)
    }

    func testFullBodyConvergedStatus() {
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf, subjectID: "c1"),
                vote(voice: .ruleSelf, subjectID: "c1"),
                vote(voice: .aspireSelf, subjectID: "c1"),
                tribunalSignal(.convergence,
                               subjectID: "c1"),
            ]))
        XCTAssertTrue(report.isFullBody)
        XCTAssertTrue(report.hasConvergence)
        XCTAssertFalse(report.hasDissent)
        XCTAssertEqual(
            report.statusCode, "full-body-converged")
        XCTAssertEqual(report.subjectIDs, ["c1"])
    }

    func testFullBodyDissentStatus() {
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf,
                     subjectID: "c1",
                     disposition: .affirm),
                vote(voice: .ruleSelf,
                     subjectID: "c1",
                     disposition: .oppose),
                vote(voice: .aspireSelf,
                     subjectID: "c1",
                     disposition: .abstain),
                tribunalSignal(.dissent,
                               subjectID: "c1"),
            ]))
        XCTAssertTrue(report.isFullBody)
        XCTAssertTrue(report.hasDissent)
        XCTAssertEqual(
            report.statusCode, "full-body-dissent")
    }

    func testFullBodyIncompleteWhenNeitherSignal() {
        // All 3 voices spoke but tribunal didn't emit
        // convergence or dissent → incomplete.
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf, subjectID: "c1"),
                vote(voice: .ruleSelf, subjectID: "c1"),
                vote(voice: .aspireSelf, subjectID: "c1"),
            ]))
        XCTAssertTrue(report.isFullBody)
        XCTAssertEqual(
            report.statusCode, "full-body-incomplete")
    }

    func testPartialVoicesStatus() {
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf, subjectID: "c1"),
            ]))
        XCTAssertFalse(report.isFullBody)
        XCTAssertEqual(
            report.statusCode, "partial-1-voices")
        XCTAssertEqual(
            report.silentVoices,
            [.ruleSelf, .aspireSelf])
    }

    func testSubjectIDsAreVoteSubjectsOnly() {
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf, subjectID: "c1"),
                vote(voice: .ruleSelf, subjectID: "c2"),
                tribunalSignal(.convergence,
                               subjectID: "c-tribunal"),
            ]))
        // Tribunal-wide signals don't add to subjectIDs;
        // only votes do.
        XCTAssertEqual(report.subjectIDs.sorted(),
                       ["c1", "c2"])
    }

    func testSubjectIDsAreDistinctAndOrdered() {
        // Same subject voted by all 3 voices → still one entry,
        // in first-vote order.
        let report = BASTribunalCoverageCheck.report(
            for: bundle([
                vote(voice: .baseSelf, subjectID: "c-first"),
                vote(voice: .ruleSelf, subjectID: "c-first"),
                vote(voice: .aspireSelf, subjectID: "c-second"),
            ]))
        XCTAssertEqual(
            report.subjectIDs,
            ["c-first", "c-second"])
    }
}
