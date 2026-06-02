// ch1055 / v1.0 §6 step 19 — proofs for the distillation ingest hook (BASDistillationBank.ingestingTraces).

import XCTest
import Foundation
@testable import BASMemory
@testable import BASOrchestration
import BASOrgan

final class BASDistillationTurnIngestTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 5000)

    private func trace(_ id: String, accepted: Bool = true) -> BASProcessTrace {
        BASProcessTrace(callID: id, purpose: .plan, agentRef: "planner", verifierRef: nil,
                        inputRefs: [], contractDigestHex: "d", providerID: "det",
                        inputTokens: 1, outputTokens: 2, producedAt: t0, traceID: id,
                        verdict: accepted ? .accepted : .rejected(reason: "x"))
    }

    private func hq(_ t: BASProcessTrace) -> BASDistillationQuality {
        BASDistillationQuality(utility: 0.9, tokenToSignal: 0.8, verifierPassed: true, criticReviewed: true)
    }

    // Ingests accepted high-quality traces, skips rejected ones, returns a new bank.
    func testIngestsAcceptedSkipsRejected() {
        let traces = [trace("a"), trace("b", accepted: false), trace("c")]
        let (bank, admissions) = BASDistillationBank().ingestingTraces(
            traces, quality: hq, scrubbed: true, privacySafe: true, sovereignSafe: true)
        XCTAssertEqual(bank.count, 2, "two accepted traces ingested; the rejected one skipped")
        XCTAssertEqual(admissions, [.admitted, .admitted])
        XCTAssertEqual(Set(bank.entries.map { $0.sourceRef }), ["a", "c"])
    }

    // Unsafe flags → fail-closed: nothing enters the pool.
    func testUnsafeTracesRejected() {
        let (bank, admissions) = BASDistillationBank().ingestingTraces(
            [trace("a")], quality: hq, scrubbed: false, privacySafe: true, sovereignSafe: true)
        XCTAssertEqual(bank.count, 0)
        XCTAssertEqual(admissions, [.rejected(.notScrubbed)])
    }

    // Immutable: the original bank is unchanged.
    func testImmutable() {
        let empty = BASDistillationBank()
        _ = empty.ingestingTraces([trace("a")], quality: hq,
                                  scrubbed: true, privacySafe: true, sovereignSafe: true)
        XCTAssertEqual(empty.count, 0, "ingestingTraces must not mutate the original bank")
    }
}
