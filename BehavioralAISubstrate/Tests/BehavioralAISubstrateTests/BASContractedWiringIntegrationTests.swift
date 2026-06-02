// ch1045 / v1.0 — end-to-end "safe demo-install" of the consequential wiring.
//
// Composes the contract-enforcing wrapper with a REAL consumer chokepoint
// (BASRoutingOrganAdapter routing over two backends) and proves: (1) the wrapper is transparent on
// output — the drafted body is byte-identical to the unwrapped path (zero behavior change); (2)
// every routed call is contracted + emits a ProcessTrace; (3) a forbidden-context policy rejects
// before the routing/model runs; (4) the collected traces render through BASTranscriptView — the
// full Phase-0 squeeze flow (contract → gate → routing → ProcessTrace → TranscriptView).

import XCTest
import Foundation
@testable import BASOrgan

final class BASContractedWiringIntegrationTests: XCTestCase {

    private final class TraceBox: @unchecked Sendable {
        private let lock = NSLock()
        private var traces: [BASProcessTrace] = []
        func add(_ t: BASProcessTrace) { lock.lock(); traces.append(t); lock.unlock() }
        func all() -> [BASProcessTrace] { lock.lock(); defer { lock.unlock() }; return traces }
    }

    private func req(_ id: String, context: [String] = []) -> BASOrganRequest {
        BASOrganRequest(requestID: id, role: .scout, preset: .scout,
                        instruction: "plan the next step", context: context)
    }

    private func routing() -> BASRoutingOrganAdapter {
        BASRoutingOrganAdapter(
            primary: BASOrganDeterministicAdapter(providerID: "det.A"),
            secondary: BASOrganDeterministicAdapter(providerID: "det.B"),
            strategy: .primaryWithFallback)
    }

    /// (1) Zero behavior change: the enforced wrapper's output body equals the unwrapped routing
    /// adapter's body for the same request (the deterministic backend is a pure function of input).
    func testEnforcedOutputIsByteIdenticalToUnwrapped() async throws {
        let bare = routing()
        let enforced = BASContractEnforcingOrganAdapter(inner: routing(), purpose: .plan)
        let bareBody = try await bare.draft(req("r1")).body
        let enforcedBody = try await enforced.draft(req("r1")).body
        XCTAssertFalse(bareBody.isEmpty)
        XCTAssertEqual(enforcedBody, bareBody, "the wrapper must not alter the drafted output")
    }

    /// (2) + (4): every routed call is contracted + traced; the traces render via TranscriptView.
    func testEndToEndContractedCallsProduceTranscript() async throws {
        let box = TraceBox()
        let enforced = BASContractEnforcingOrganAdapter(
            inner: routing(), purpose: .plan, verifierRef: "v:plan",
            traceSink: { box.add($0) })
        for id in ["a", "b", "c"] { _ = try await enforced.draft(req(id)) }

        let traces = box.all()
        XCTAssertEqual(traces.count, 3)
        XCTAssertTrue(traces.allSatisfy { $0.purpose == .plan })
        XCTAssertTrue(traces.allSatisfy { $0.verdict == .accepted })

        // The L12 surface renders the squeeze result from the collected traces.
        let view = BASTranscriptView.render(traces: traces, mode: .summary)
        XCTAssertEqual(view.callCount, 3)
        XCTAssertEqual(view.acceptedCount, 3)
        XCTAssertTrue(view.lines.contains { $0.contains("plan=3") })

        let audit = BASTranscriptView.render(traces: traces, mode: .auditLite)
        XCTAssertEqual(audit.lines.count, 3)
        XCTAssertTrue(audit.lines[0].contains("contract="))
    }

    /// (3): a forbidden-context policy rejects BEFORE the routing adapter / backends run.
    func testForbiddenContextRejectedThroughRealChokepoint() async {
        let enforced = BASContractEnforcingOrganAdapter(
            inner: routing(), purpose: .render, forbiddenContext: ["sealed.memory"])
        do {
            _ = try await enforced.draft(req("r2", context: ["sealed.memory"]))
            XCTFail("forbidden context must be rejected at the gate, before routing")
        } catch BASLLMContractError.forbiddenContextPresent(let tag) {
            XCTAssertEqual(tag, "sealed.memory")
        } catch { XCTFail("wrong error: \(error)") }
    }
}
