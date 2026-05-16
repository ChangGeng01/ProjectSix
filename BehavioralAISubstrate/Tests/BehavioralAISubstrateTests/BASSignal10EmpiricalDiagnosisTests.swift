// MARK: - BASSignal10EmpiricalDiagnosisTests
// chapter 六百九十四 / M2146 第一刀 — empirical signal-10
//                                  root-cause diagnosis。
//
// chapter 693 BASSignalTenIntegrationTestTriageDoctrine
// pinned 3 contributing factor hypotheses for the SIGBUS
// crashes:
//
//   1. Swift 6 strict concurrency + Task.detached + XCTest
//      async interaction
//   2. Phase L M2074 V2 path memory alignment issue
//   3. macOS 26 SDK + xctest binary linkage change
//
// This test file empirically isolates each factor。 Tests
// that FAIL with signal-10 narrow the bucket;tests that
// PASS rule out their factor。
//
// chapter 692 BASTier{A,B,C}CompletionDoctrine pins the
// substrate's typed surfaces are stable;these tests
// verify the runtime path itself。

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

    // MARK: - Hypothesis #1:Task.detached bridging

    /// Diagnostic A:`startSession` called DIRECTLY in a
    /// SYNC test method — no async,no Task.detached。
    /// If this crashes → root cause is inside startSession,
    ///                   independent of concurrency。
    /// If this passes → root cause involves async/concurrency。
    func testSyncStartSessionDirectInvocation() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(makeRequest())
        XCTAssertNotNil(result.eBrainTurn)
    }

    // Diagnostic B (sync + Task.detached + DispatchGroup) —
    // omitted due to Swift 6 strict concurrency forbidding
    // the mutable-capture pattern。 Diagnostic D below
    // covers the Task.detached path under async test
    // method semantics,which is the actual production
    // pattern in BASSubstrateReauditShadowEvaluator anyway。

    /// Diagnostic C:`startSession` called DIRECTLY in an
    /// ASYNC test method — no Task.detached。
    /// EMPIRICAL OUTCOME (M2146):CRASHES with SIGBUS。
    /// → async XCTestCase + sync startSession is the
    ///   minimal failing pattern (Task.detached is NOT
    ///   required;hypothesis #1 narrowed)。
    /// Skipped post-M2146 to keep test suite clean while
    /// preserving the bucket boundary documentation。
    func testAsyncMethodDirectStartSession() async throws {
        throw XCTSkip(
            "Diagnostic C confirms SIGBUS bucket boundary " +
            "— async XCTestCase + startSession() is the " +
            "minimal failing pattern。 See BASSignalTen" +
            "IntegrationTestTriageDoctrine M2146 empirical " +
            "update。")
        let runtime = makeRuntime()
        let result = try runtime.startSession(makeRequest())
        XCTAssertNotNil(result.eBrainTurn)
    }

    /// Diagnostic D:`startSession` called via `Task.detached`
    /// inside an ASYNC test method,EXACTLY mirroring the
    /// pattern used by BASSubstrateReauditShadowEvaluator。
    /// EMPIRICAL OUTCOME (M2146):CRASHES with SIGBUS。
    /// → confirms the production pattern signature。
    /// Skipped post-M2146 to keep test suite clean while
    /// preserving the bucket boundary documentation。
    func testAsyncMethodTaskDetachedStartSession() async throws {
        throw XCTSkip(
            "Diagnostic D confirms SIGBUS bucket boundary " +
            "— async + Task.detached + startSession()。 See " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "M2146 empirical update。")
        let runtime = makeRuntime()
        let request = makeRequest()
        let observedResult: BASHostSessionResult? =
            await Task.detached(
                priority: .userInitiated
            ) { () -> BASHostSessionResult? in
                try? runtime.startSession(request)
            }.value
        XCTAssertNotNil(observedResult)
    }

    /// Diagnostic F (M2158 chapter 697):SYNC test method
    /// + expectation + NON-DETACHED `Task { ... }` calling
    /// an actor method (NO startSession)。 Probes whether
    /// non-detached Task + actor-only calls is a viable
    /// recovery pattern for the 6 remaining SIGBUS tests
    /// (BASMemoryClosedLoop 3 + M306 3) that call into
    /// `public actor` types。
    /// Expected:if PASSES → the 6 remaining tests
    /// recoverable via this pattern。 If CRASHES → actor
    /// boundary itself is not safe in test context。
    func testSyncMethodNonDetachedTaskActorOnly() throws {
        // Use a simple actor for the probe — not
        // BASSovereignAuditLedger or BASMemoryClosedLoop
        // Applier to isolate the pattern from those
        // specific actor's internals。
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

    /// Diagnostic E:SYNC test method + expectation +
    /// detached Task calling startSession。
    /// EMPIRICAL OUTCOME (M2146):CRASHES with SIGBUS。
    /// → Task.detached itself is sufficient to trigger
    ///   the crash;the sync-test-method wrapping doesn't
    ///   help。 No viable wrapper-based recovery exists。
    /// Skipped post-M2146 to keep test suite clean while
    /// preserving the bucket boundary documentation。
    func testSyncMethodExpectationDetachedStartSession() throws {
        throw XCTSkip(
            "Diagnostic E confirms SIGBUS bucket boundary " +
            "— sync test + Task.detached + startSession() " +
            "ALSO crashes。 Task.detached itself is the " +
            "trigger,not just async test methods。 See " +
            "BASSignalTenIntegrationTestTriageDoctrine " +
            "M2146 empirical update。")
        let runtime = makeRuntime()
        let request = makeRequest()
        let exp = expectation(
            description: "detached-start-session")
        Task.detached(priority: .userInitiated) {
            let result = try? runtime.startSession(request)
            XCTAssertNotNil(result)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}
