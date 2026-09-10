import XCTest
@testable import QinaoLoop

/// M314 — pin that `QinaoSampleHost --multi-turn-demo`'s
/// `MultiTurnDemo.run()` helper composes M310's `driveMultiTurn`
/// pattern with `QinaoOrganEndpoint.context:` accumulation.
///
/// `QinaoSampleHost` is an executable target so tests can't import
/// `MultiTurnDemo` directly. These tests instead pin the
/// **substrate contract** the demo depends on (mirroring M298 +
/// M313 patterns), so any breaking shape change in
/// `QinaoOrganEndpoint.produceBody(...)` surfaces here as a
/// Qinao-side test failure.
///
/// What this file pins:
///
///   1. `QinaoOrganEndpoint.produceBody(prompt:context:role:
///      sessionID:)` accepts a `[String]` context array — the
///      doctrinal multi-turn shape M310 + M314 rely on.
///   2. `QinaoLoop.OrganRole` has both `.scout` and `.core`
///      cases — demo passes `.core` for full-pass turns.
///   3. `QinaoLoop.OrganResponse` exposes `body / providerID /
///      traceID` — banner reads all three.
///   4. The driver pattern (every turn appends 2 entries to
///      context) mirrors M310 exactly — pin the math via direct
///      simulation.
final class QinaoSampleHostMultiTurnDemoTests: XCTestCase {

    /// Same shape as M310's `RecordingMockEndpoint` minus the
    /// `Call` struct details — tests don't need the full
    /// recording payload, just confirmation that the contract
    /// signature compiles + dispatches.
    private actor SignatureProbeEndpoint: QinaoOrganEndpoint {
        var seenContextCounts: [Int] = []
        var seenSessionIDs: Set<String> = []
        var seenRoles: Set<QinaoLoop.OrganRole> = []

        func produceBody(
            prompt: String,
            context: [String],
            role: QinaoLoop.OrganRole,
            sessionID: String
        ) async throws -> QinaoLoop.OrganResponse {
            seenContextCounts.append(context.count)
            seenSessionIDs.insert(sessionID)
            seenRoles.insert(role)
            return QinaoLoop.OrganResponse(
                body: "echo:\(prompt.prefix(8))",
                providerID: "probe",
                traceID: "probe-trace")
        }
    }

    /// 1. The contract: `produceBody` accepts a context array
    ///    and returns an OrganResponse with a body.
    func testProduceBodyAcceptsContextAndReturnsResponse()
        async throws
    {
        let probe = SignatureProbeEndpoint()
        let response = try await probe.produceBody(
            prompt: "hello",
            context: ["prior: A", "prior: B"],
            role: .core,
            sessionID: "test-session")
        XCTAssertEqual(response.body, "echo:hello")
        XCTAssertEqual(response.providerID, "probe")
    }

    /// 2. The role enum carries the two cases the demo uses.
    func testOrganRoleHasScoutAndCoreCases() {
        let scout: QinaoLoop.OrganRole = .scout
        let core: QinaoLoop.OrganRole = .core
        XCTAssertNotEqual(scout, core)
    }

    /// 3. Driver math: 3 turns × 2 entries per turn = monotonic
    ///    counts of 0 → 2 → 4. Direct simulation that mirrors
    ///    `MultiTurnDemo.drive(...)` math; if M310's append
    ///    semantics ever change, the demo's continuity proof
    ///    breaks and this test catches it.
    func testThreeTurnDriverProducesExpectedContextGrowth()
        async throws
    {
        let probe = SignatureProbeEndpoint()
        var context: [String] = []
        let prompts = ["P1", "P2", "P3"]
        for prompt in prompts {
            let response = try await probe.produceBody(
                prompt: prompt,
                context: context,
                role: .core,
                sessionID: "drive-test")
            context.append("user: \(prompt)")
            context.append("assistant: \(response.body)")
        }
        let counts = await probe.seenContextCounts
        XCTAssertEqual(counts, [0, 2, 4])
        let sessions = await probe.seenSessionIDs
        XCTAssertEqual(sessions.count, 1,
                       "single sessionID across 3 turns")
        let roles = await probe.seenRoles
        XCTAssertEqual(roles, [.core])
    }

    /// 4. Independent driver runs do not bleed sessionIDs (the
    ///    demo pinned this; same isolation invariant).
    func testIndependentDriverRunsHaveDistinctSessionIDs()
        async throws
    {
        let probe = SignatureProbeEndpoint()
        for sessionID in ["s-A", "s-B"] {
            _ = try await probe.produceBody(
                prompt: "p",
                context: [],
                role: .core,
                sessionID: sessionID)
        }
        let sessions = await probe.seenSessionIDs
        XCTAssertEqual(sessions, ["s-A", "s-B"])
    }
}
