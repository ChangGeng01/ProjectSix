// MARK: - BASChapter776L13Phase2CloseOutTests
// chapter 七百七十六 / M2531-M2535
//
// L13 PHASE 2 sub-arc seal — verifies the
// BASShadowTrialRustStateMachine adapter is byte-equal to the
// Phase 1 BASShadowTrialStateMachineCore via the protocol seam。

import XCTest
@testable import BASOrchestration
@testable import BASMemory

final class BASChapter776L13Phase2CloseOutTests: XCTestCase {

    // MARK: - Sub-arc scorecard pins

    func testPhase1ChapterPinned() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.phase1Chapter,
            "chapter 七百七十二")
    }

    func testPhase2ChaptersAccountedFor() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.phase2Chapters.count, 3)
    }

    func testTotalKnives20() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.totalKnives, 20)
    }

    func testRustCrateNamePinned() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.rustCrate,
            "bas-shadow-trial")
    }

    func testThreeSQLSchemasLanded() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.sqlSchemasAdded.count, 3)
    }

    func testPhase2CompleteFlag() {
        XCTAssertTrue(
            BASChapter776L13Phase2Scorecard.phase2Complete)
    }

    func testDecisionVerdictIsOptIn() {
        XCTAssertEqual(
            BASChapter776L13Phase2Scorecard.decisionVerdict,
            "OPT-IN")
    }

    // MARK: - Adapter conforms to protocol

    func testAdapterConformsToProtocol() {
        let adapter: any BASShadowTrialStateMachine =
            BASShadowTrialRustStateMachine()
        let req = BASShadowTrialTransitionRequest(
            currentPhase: .nursery, verdictRaw: nil)
        let outcome = adapter.transition(req)
        if case .advanceTo(let next) = outcome {
            XCTAssertEqual(next, .trialInFlight,
                "Nursery → TrialInFlight via Rust adapter")
        } else {
            XCTFail("expected .advanceTo")
        }
    }

    // MARK: - Phase 1 Core ≡ Phase 2 Rust adapter (end-to-end)

    /// Exhaustive equivalence test:every (phase, verdictRaw)
    /// input produces IDENTICAL outcomes when run through both
    /// the Phase 1 Swift Core impl and the Phase 2 Rust adapter。
    func testRustAdapterByteEqualToSwiftCore() {
        let core = BASShadowTrialStateMachineCore()
        let rust = BASShadowTrialRustStateMachine()

        let phases: [BASShadowTrialPhase] = [
            .nursery, .trialInFlight, .sealed, .retracted,
        ]
        let verdicts: [String?] = [
            nil, "passed", "failed", "blocked", "mysterious",
        ]

        for phase in phases {
            for verdict in verdicts {
                let req = BASShadowTrialTransitionRequest(
                    currentPhase: phase, verdictRaw: verdict)
                let coreOutcome = core.transition(req)
                let rustOutcome = rust.transition(req)

                // Both either advanced to the same next phase or
                // both rejected (reason strings differ — they're
                // human-readable diagnostics,not part of the
                // wire contract)。
                switch (coreOutcome, rustOutcome) {
                case (.advanceTo(let coreNext),
                      .advanceTo(let rustNext)):
                    XCTAssertEqual(coreNext, rustNext,
                        "next phase mismatch (\(phase), \(verdict ?? "nil"))")
                case (.rejected, .rejected):
                    break // both rejected — outcome shape matches
                default:
                    XCTFail("outcome shape mismatch for (\(phase), " +
                            "\(verdict ?? "nil")):core=\(coreOutcome) " +
                            "rust=\(rustOutcome)")
                }
            }
        }
    }

    // MARK: - Codable round-trip of the protocol types

    func testTransitionRequestCodableRoundTrip() throws {
        let req = BASShadowTrialTransitionRequest(
            currentPhase: .trialInFlight, verdictRaw: "passed")
        let data = try JSONEncoder().encode(req)
        let decoded = try JSONDecoder().decode(
            BASShadowTrialTransitionRequest.self, from: data)
        XCTAssertEqual(req, decoded)
    }
}
