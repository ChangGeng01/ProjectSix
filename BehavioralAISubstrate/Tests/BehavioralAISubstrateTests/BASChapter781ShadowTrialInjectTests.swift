// MARK: - BASChapter781ShadowTrialInjectTests
// chapter 七百八十一 / M2556-M2560
//
// Verifies the chapter 七百八十一 shadow-trial coordinator
// state-machine injection seam + production-default Rust
// factory。

import XCTest
@testable import BASMemory
@testable import BASOrchestration

final class BASChapter781ShadowTrialInjectTests: XCTestCase {

    // MARK: - Existing 6-param init still works (no breakage)

    func testExistingSixParamInitDefaultsToSwiftCore() async {
        let ledger = BASInMemoryShadowTrialLedger()
        let coord = BASShadowTrialCoordinator(ledger: ledger)
        let smDesc = await coord.stateMachine
        XCTAssertTrue(
            type(of: smDesc) == BASShadowTrialStateMachineCore.self,
            "6-param init defaults to Swift Core state machine")
    }

    // MARK: - 7-param explicit-stateMachine init

    func testExplicitStateMachineInitWorks() async {
        let ledger = BASInMemoryShadowTrialLedger()
        let rustSM = BASShadowTrialRustStateMachine()
        let coord = BASShadowTrialCoordinator(
            ledger: ledger, stateMachine: rustSM)
        let smDesc = await coord.stateMachine
        XCTAssertTrue(
            type(of: smDesc) == BASShadowTrialRustStateMachine.self,
            "7-param init lets caller pick state machine")
    }

    // MARK: - Production factory wires Rust on Apple

    func testProductionFactoryUsesRustOnApplePlatforms() async {
        let ledger = BASInMemoryShadowTrialLedger()
        let coord = BASShadowTrialCoordinator
            .makeWithDefaultStateMachine(ledger: ledger)
        let smDesc = await coord.stateMachine
        #if os(iOS) || os(macOS)
        XCTAssertTrue(
            type(of: smDesc) == BASShadowTrialRustStateMachine.self,
            "Production factory uses Rust adapter on Apple platforms")
        #else
        XCTAssertTrue(
            type(of: smDesc) == BASShadowTrialStateMachineCore.self,
            "Non-Apple platforms fall back to Swift Core")
        #endif
    }

    // MARK: - previewTransition routes to the injected state machine

    func testPreviewTransitionUsesInjectedStateMachine() async {
        let ledger = BASInMemoryShadowTrialLedger()
        let coord = BASShadowTrialCoordinator(ledger: ledger)
        let outcome = await coord.previewTransition(
            currentPhase: .nursery, verdictRaw: nil)
        if case .advanceTo(let next) = outcome {
            XCTAssertEqual(next, .trialInFlight,
                "nursery + nil → trialInFlight via injected SM")
        } else {
            XCTFail("expected .advanceTo")
        }
    }

    func testPreviewTransitionRustAdapterMatchesSwiftCore() async {
        // Build two coordinators — one with Rust adapter,one
        // with Swift Core — and verify previewTransition matches
        // for every (phase, verdict) case。
        let ledger1 = BASInMemoryShadowTrialLedger()
        let ledger2 = BASInMemoryShadowTrialLedger()
        let coordRust = BASShadowTrialCoordinator(
            ledger: ledger1,
            stateMachine: BASShadowTrialRustStateMachine())
        let coordSwift = BASShadowTrialCoordinator(
            ledger: ledger2,
            stateMachine: BASShadowTrialStateMachineCore())

        let phases: [BASShadowTrialPhase] = [
            .nursery, .trialInFlight, .sealed, .retracted]
        let verdicts: [String?] = [nil, "passed", "failed", "blocked"]

        for phase in phases {
            for v in verdicts {
                let rustOut = await coordRust.previewTransition(
                    currentPhase: phase, verdictRaw: v)
                let swiftOut = await coordSwift.previewTransition(
                    currentPhase: phase, verdictRaw: v)
                // Compare outcome shapes
                switch (rustOut, swiftOut) {
                case (.advanceTo(let r), .advanceTo(let s)):
                    XCTAssertEqual(r, s,
                        "Rust ≡ Swift advanceTo for (\(phase), \(v ?? "nil"))")
                case (.rejected, .rejected):
                    break // both rejected
                default:
                    XCTFail("Rust outcome ≠ Swift for (\(phase), \(v ?? "nil"))")
                }
            }
        }
    }

    // MARK: - Inject seam is purely additive (existing 65 L13 tests
    // still cover the inline submit/observe/finalize regression
    // surface — this chapter's inject ONLY adds the state machine
    // property + previewTransition method)。

    // gaps-reconciliation hostkit-spine F9 (2026-07-11): this was `XCTAssertTrue(true)` — a
    // tautology whose comment CLAIMED "both inits exist + previewTransition is non-mutating"
    // while asserting neither. Both-inits is already covered by the two real tests above; the
    // non-mutating claim now has real teeth: previews mid-trial change NOTHING observable —
    // the open trial keeps its phase, repeated previews are idempotent, and the real ledger
    // records no additional appends from previewing.
    func testPreviewTransitionIsNonMutating() async throws {
        let ledger = BASInMemoryShadowTrialLedger()
        let coord = BASShadowTrialCoordinator(ledger: ledger)
        let candidate = BASExperienceCandidate(
            candidateID: "cand-preview",
            sourceRefs: ["ref"],
            candidateType: .rule,
            summary: "preview must not mutate",
            stabilitySignal: 0.8,
            contaminationRisk: 0.1,
            hostScope: "test",
            sovereignScope: "test.preview")
        let record = try await coord.submit(
            candidate: candidate, sessionID: "s", turnID: "t", trialScope: "test.scope")
        let phaseBefore = record.completionState
        let appendsBefore = await ledger.count()

        // Preview every phase/verdict combination — including ones that WOULD advance if committed.
        for verdict in [nil, "passed", "failed", "garbage"] as [String?] {
            _ = await coord.previewTransition(currentPhase: .nursery, verdictRaw: verdict)
            _ = await coord.previewTransition(currentPhase: .trialInFlight, verdictRaw: verdict)
        }

        let appendsAfter = await ledger.count()
        XCTAssertEqual(appendsAfter, appendsBefore,
            "previewTransition must never touch the ledger (pure decision preview)")
        let trials = await coord.trials(for: "cand-preview")
        XCTAssertEqual(trials.first(where: { $0.trialID == record.trialID })?.completionState,
            phaseBefore,
            "the open trial's phase is untouched by any number of previews")
    }
}
