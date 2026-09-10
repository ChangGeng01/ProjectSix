// MARK: - BASSignal10EmpiricalDiagnosisTests
// chapter 六百九十四 / M2146 第一刀 (origin) — empirical
//                                  signal-10 root-cause
//                                  diagnosis。
// chapter 六百九十八 / M2162 第一刀 (cleanup) — removed
//                                  3 placeholder
//                                  XCTSkip diagnostics
//                                  C/D/E (their
//                                  findings live in
//                                  BASSignalTenIntegration
//                                  TestTriageDoctrine
//                                  empirical pins)。
//
// ## Empirical findings (pinned in triage doctrine)
//
// chapter 694 / M2146 ran 4 isolation diagnostics
// (A/C/D/E) + chapter 697 / M2158 added Diagnostic F:
//
//   A (sync test + direct startSession)         → PASS
//   C (async test + direct startSession)        → CRASH
//   D (async + Task.detached + startSession)    → CRASH
//   E (sync + Task.detached + startSession)     → CRASH
//   F (sync + non-detached Task + actor calls)  → PASS
//
// chapter 698 / M2162 keeps ONLY the 2 PASSING
// diagnostics (A + F) as active anti-drift tests。 The
// 3 CRASHING diagnostics (C/D/E) lived as XCTSkip
// placeholders documenting bucket boundaries — but the
// findings are already FIRST-CLASS pins in
// BASSignalTenIntegrationTestTriageDoctrine, so the
// skipped placeholders are redundant sprawl。
//
// Removing them reduces the skipped-test count by 3 and
// the maintenance surface。 The doctrine pins remain the
// source-of-truth for the SIGBUS bucket boundary。

import XCTest
@testable import BASHostKit

final class BASSignal10EmpiricalDiagnosisTests: XCTestCase {

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(configuration: .fixtureGeneric)
    }

    private func makeRequest() -> BASHostSessionRequest {
        BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .primary,
            surface: .application,
            prompt: "diagnostic prompt",
            riskLevel: .medium)
    }

    // MARK: - Diagnostic A — sync test + direct sync
    //         startSession → PASS

    /// Sync test method calling sync startSession directly。
    /// This is the WORKING baseline pattern。 6 evaluator
    /// tests recovered at chapter 696 / M2154 follow this
    /// pattern after the evaluateSync sync surface was
    /// added (so the test can stay sync end-to-end)。
    func testSyncStartSessionDirectInvocation() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(makeRequest())
        XCTAssertNotNil(result.eBrainTurn)
    }

    // MARK: - Diagnostic F — sync test + non-detached
    //         `Task { ... }` + actor calls → PASS

    /// Sync test method + non-detached `Task { ... }` +
    /// actor call (NO startSession inside the Task)。
    /// This is the SECOND WORKING pattern (chapter 697 /
    /// M2158)。 6 actor-blocked tests (3 M306 + 3
    /// BASMemoryClosedLoop) recovered using this pattern。
    func testSyncMethodNonDetachedTaskActorOnly() throws {
        actor ProbeActor {
            private var counter: Int = 0
            func increment() async -> Int {
                counter += 1
                return counter
            }
        }
        let probe = ProbeActor()
        let exp = expectation(
            description: "actor-call-non-detached-task")
        Task {
            let value = await probe.increment()
            XCTAssertEqual(value, 1)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}
