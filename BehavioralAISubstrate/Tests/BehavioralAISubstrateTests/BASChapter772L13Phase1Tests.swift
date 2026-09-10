// MARK: - BASChapter772L13Phase1Tests
// chapter 七百七十二 / M2511-M2515
//
// L13 Phase 1 Swift refactor verification + Phase 2 readiness pin。

import XCTest
@testable import BASMemory

final class BASChapter772L13Phase1Tests: XCTestCase {

    // MARK: - Scorecard pins

    func testScorecardChapterId() {
        XCTAssertEqual(
            BASChapter772L13Phase1Scorecard.chapterId,
            "chapter 七百七十二")
    }

    func testScorecardMRange() {
        XCTAssertEqual(
            BASChapter772L13Phase1Scorecard.mRange, "M2511-M2515")
    }

    func testScorecardKnifeCount() {
        XCTAssertEqual(
            BASChapter772L13Phase1Scorecard.knifeCount, 5)
    }

    func testScorecardSwiftOnly() {
        XCTAssertFalse(
            BASChapter772L13Phase1Scorecard.rustCrateAdded,
            "L13 Phase 1 is Swift-only refactor")
        XCTAssertFalse(
            BASChapter772L13Phase1Scorecard.sqlSchemaAdded,
            "L13 Phase 1 ships no new SQL schemas")
    }

    func testScorecardPhase2Ready() {
        XCTAssertTrue(
            BASChapter772L13Phase1Scorecard.phase2Ready,
            "Protocol seam ready for Phase 2 Rust port")
    }

    func testScorecardPhaseCount() {
        XCTAssertEqual(
            BASChapter772L13Phase1Scorecard.phaseCount, 4)
        XCTAssertEqual(BASShadowTrialPhase.allCases.count, 4,
            "Swift enum cardinality must match scorecard pin")
    }

    // MARK: - BASShadowTrialPhase discriminants pinned

    func testPhaseDiscriminantsPinned() {
        XCTAssertEqual(BASShadowTrialPhase.nursery.rawValue, 0)
        XCTAssertEqual(BASShadowTrialPhase.trialInFlight.rawValue, 1)
        XCTAssertEqual(BASShadowTrialPhase.sealed.rawValue, 2)
        XCTAssertEqual(BASShadowTrialPhase.retracted.rawValue, 3)
    }

    // MARK: - State machine transitions

    func testNurseryAlwaysAdvancesToTrialInFlight() {
        let sm = BASShadowTrialStateMachineCore()
        // nursery + nil verdict
        let r1 = sm.transition(.init(
            currentPhase: .nursery, verdictRaw: nil))
        XCTAssertEqual(r1, .advanceTo(.trialInFlight))
        // nursery + any verdict (verdict ignored on nursery)
        let r2 = sm.transition(.init(
            currentPhase: .nursery, verdictRaw: "passed"))
        XCTAssertEqual(r2, .advanceTo(.trialInFlight))
    }

    func testTrialInFlightPassedYieldsSealed() {
        let sm = BASShadowTrialStateMachineCore()
        let r = sm.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: "passed"))
        XCTAssertEqual(r, .advanceTo(.sealed))
    }

    func testTrialInFlightFailedYieldsRetracted() {
        let sm = BASShadowTrialStateMachineCore()
        let r = sm.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: "failed"))
        XCTAssertEqual(r, .advanceTo(.retracted))
    }

    func testTrialInFlightBlockedYieldsRetracted() {
        let sm = BASShadowTrialStateMachineCore()
        let r = sm.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: "blocked"))
        XCTAssertEqual(r, .advanceTo(.retracted))
    }

    func testTrialInFlightNilVerdictStaysInFlight() {
        let sm = BASShadowTrialStateMachineCore()
        let r = sm.transition(.init(
            currentPhase: .trialInFlight, verdictRaw: nil))
        XCTAssertEqual(r, .advanceTo(.trialInFlight))
    }

    func testSealedRejectsAllFurtherTransitions() {
        let sm = BASShadowTrialStateMachineCore()
        let cases: [String?] = [nil, "passed", "failed", "blocked"]
        for v in cases {
            let r = sm.transition(.init(
                currentPhase: .sealed, verdictRaw: v))
            if case .rejected = r {
                // expected
            } else {
                XCTFail("sealed must reject verdict \(String(describing: v))")
            }
        }
    }

    func testRetractedRejectsAllFurtherTransitions() {
        let sm = BASShadowTrialStateMachineCore()
        let cases: [String?] = [nil, "passed", "failed", "blocked"]
        for v in cases {
            let r = sm.transition(.init(
                currentPhase: .retracted, verdictRaw: v))
            if case .rejected = r {
                // expected
            } else {
                XCTFail("retracted must reject verdict \(String(describing: v))")
            }
        }
    }

    func testTrialInFlightUnknownVerdictRejected() {
        let sm = BASShadowTrialStateMachineCore()
        let r = sm.transition(.init(
            currentPhase: .trialInFlight,
            verdictRaw: "mysterious"))
        if case .rejected = r {
            // expected
        } else {
            XCTFail("trialInFlight with unknown verdict must reject")
        }
    }

    // MARK: - Phase 2 contract:protocol is swappable

    /// Test fake implementation proving the protocol seam works。
    /// A future Rust port would conform similarly。
    private struct AlwaysSealStateMachine: BASShadowTrialStateMachine {
        func transition(
            _: BASShadowTrialTransitionRequest
        ) -> BASShadowTrialTransitionOutcome {
            return .advanceTo(.sealed)
        }
    }

    func testProtocolSeamAcceptsCustomImpl() {
        let custom: any BASShadowTrialStateMachine =
            AlwaysSealStateMachine()
        let r = custom.transition(.init(
            currentPhase: .nursery, verdictRaw: nil))
        XCTAssertEqual(r, .advanceTo(.sealed),
            "Custom impl must be invokable via protocol type")
    }

    // MARK: - Codable round-trip for wire stability

    func testPhaseCodableRoundTrip() throws {
        for p in BASShadowTrialPhase.allCases {
            let data = try JSONEncoder().encode(p)
            let decoded = try JSONDecoder().decode(
                BASShadowTrialPhase.self, from: data)
            XCTAssertEqual(p, decoded)
        }
    }

    func testTransitionRequestCodableRoundTrip() throws {
        let req = BASShadowTrialTransitionRequest(
            currentPhase: .trialInFlight, verdictRaw: "passed")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(
            BASShadowTrialTransitionRequest.self, from: data)
        XCTAssertEqual(req, decoded)
    }
}
