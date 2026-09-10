// ch1047 / v1.0 L13 — proofs for BASDistillationBank (蒸馏池) + its ProcessTrace / bundle adapters.
//
// Verifies the red-line fail-closed admission (scrub/privacy/sovereign), the quality floor, dedup,
// immutability (ingesting returns a NEW bank), score ranking, the training-manifest export, and the
// two ingest adapters (accepted ProcessTrace → entry, rejected → nil; bundle flags flow through).

import XCTest
import Foundation
@testable import BASMemory
@testable import BASOrchestration
import BASOrgan

final class BASDistillationBankTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func goodQuality() -> BASDistillationQuality {
        BASDistillationQuality(utility: 0.9, tokenToSignal: 0.8, verifierPassed: true, criticReviewed: true)
    }

    private func entry(ref: String, scrubbed: Bool = true, privacy: Bool = true, sovereign: Bool = true,
                       quality: BASDistillationQuality? = nil, at: Date? = nil, purpose: String = "plan")
        -> BASDistillationEntry {
        BASDistillationEntry(
            id: "dist:" + ref, sourceKind: .processTrace, sourceRef: ref, purposeTag: purpose,
            quality: quality ?? goodQuality(),
            scrubbed: scrubbed, privacySafe: privacy, sovereignSafe: sovereign,
            producedAt: at ?? t0)
    }

    // A safe, high-quality entry is admitted and appended.
    func testAdmitsSafeHighQuality() {
        let (bank, verdict) = BASDistillationBank().ingesting(entry(ref: "a"))
        XCTAssertEqual(verdict, .admitted)
        XCTAssertEqual(bank.count, 1)
    }

    // Each safety gate rejects fail-closed (红线), in order scrub → privacy → sovereign.
    func testRejectsUnsafeFailClosed() {
        XCTAssertEqual(BASDistillationBank().ingesting(entry(ref: "a", scrubbed: false)).admission,
                       .rejected(.notScrubbed))
        XCTAssertEqual(BASDistillationBank().ingesting(entry(ref: "a", privacy: false)).admission,
                       .rejected(.notPrivacySafe))
        XCTAssertEqual(BASDistillationBank().ingesting(entry(ref: "a", sovereign: false)).admission,
                       .rejected(.notSovereignSafe))
    }

    // Below the quality floor is rejected (after passing the safety gates).
    func testRejectsBelowFloor() {
        let low = BASDistillationQuality(utility: 0.1, tokenToSignal: 0.1,
                                         verifierPassed: false, criticReviewed: false)
        let (bank, verdict) = BASDistillationBank().ingesting(entry(ref: "a", quality: low))
        XCTAssertEqual(verdict, .rejected(.belowQualityFloor))
        XCTAssertEqual(bank.count, 0)
    }

    // requireVerifierPassed policy rejects an unverified entry even if otherwise high-quality.
    func testRejectsVerifierNotPassedWhenRequired() {
        let pol = BASDistillationAdmissionPolicy(minScore: 0.0, requireVerifierPassed: true)
        let q = BASDistillationQuality(utility: 1, tokenToSignal: 1,
                                       verifierPassed: false, criticReviewed: true)
        let (_, verdict) = BASDistillationBank(policy: pol).ingesting(entry(ref: "a", quality: q))
        XCTAssertEqual(verdict, .rejected(.verifierNotPassed))
    }

    // A duplicate sourceRef does not enter the pool twice.
    func testRejectsDuplicateRef() {
        let (b1, _) = BASDistillationBank().ingesting(entry(ref: "a"))
        let (b2, verdict) = b1.ingesting(entry(ref: "a", at: t0.addingTimeInterval(5)))
        XCTAssertEqual(verdict, .rejected(.duplicateRef))
        XCTAssertEqual(b2.count, 1)
    }

    // Immutability: ingesting returns a NEW bank; the original is unchanged.
    func testIngestIsImmutable() {
        let empty = BASDistillationBank()
        let (full, _) = empty.ingesting(entry(ref: "a"))
        XCTAssertEqual(empty.count, 0, "original bank must be unchanged")
        XCTAssertEqual(full.count, 1)
    }

    // top(n) ranks by descending composite score.
    func testTopRanksByScore() {
        let hi = BASDistillationQuality(utility: 1, tokenToSignal: 1,
                                        verifierPassed: true, criticReviewed: true)   // 1.0
        let lo = BASDistillationQuality(utility: 0.6, tokenToSignal: 0.6,
                                        verifierPassed: false, criticReviewed: false) // 0.48
        var bank = BASDistillationBank(policy: BASDistillationAdmissionPolicy(minScore: 0.0))
        bank = bank.ingesting(entry(ref: "lo", quality: lo)).bank
        bank = bank.ingesting(entry(ref: "hi", quality: hi)).bank
        XCTAssertEqual(bank.top(1).first?.sourceRef, "hi")
        XCTAssertEqual(bank.top(2).map { $0.sourceRef }, ["hi", "lo"])
    }

    // exportManifest produces a safe bundle of the ranked refs + sorted purpose tags.
    func testExportManifest() {
        var bank = BASDistillationBank()
        bank = bank.ingesting(entry(ref: "a", purpose: "plan")).bank
        bank = bank.ingesting(entry(ref: "b", purpose: "critique")).bank
        let bundle = bank.exportManifest(bundleID: "exp1")
        XCTAssertEqual(Set(bundle.candidateRefs), ["a", "b"])
        XCTAssertTrue(bundle.scrubbed && bundle.privacySafe && bundle.sovereignSafe)
        XCTAssertEqual(bundle.evaluationTags, ["critique", "plan"])
    }

    // ProcessTrace adapter: accepted trace → entry; rejected trace → nil.
    func testFromProcessTrace() {
        let accepted = BASProcessTrace(
            callID: "c1", purpose: .plan, agentRef: "planner", verifierRef: nil, inputRefs: [],
            contractDigestHex: "deadbeef", providerID: "det", inputTokens: 10, outputTokens: 20,
            producedAt: t0, traceID: "tr1", verdict: .accepted)
        let e = BASDistillationEntry.from(processTrace: accepted, quality: goodQuality(),
                                          scrubbed: true, privacySafe: true, sovereignSafe: true)
        XCTAssertEqual(e?.sourceRef, "tr1")
        XCTAssertEqual(e?.purposeTag, "plan")
        XCTAssertEqual(e?.sourceKind, .processTrace)

        let rejected = BASProcessTrace(
            callID: "c2", purpose: .plan, agentRef: nil, verifierRef: nil, inputRefs: [],
            contractDigestHex: "x", providerID: "", inputTokens: 0, outputTokens: 0,
            producedAt: t0, traceID: "tr2", verdict: .rejected(reason: "forbidden"))
        XCTAssertNil(BASDistillationEntry.from(processTrace: rejected, quality: goodQuality(),
                                               scrubbed: true, privacySafe: true, sovereignSafe: true),
                     "a rejected trace has no output to distill")
    }

    // Bundle adapter: the bundle's safety flags flow into the entry, which then admits.
    func testFromLearningExportBundle() {
        let bundle = BASLearningExportBundle(
            bundleID: "lb1", candidateRefs: ["x"], scrubbed: true, privacySafe: true, sovereignSafe: true)
        let e = BASDistillationEntry.from(learningExportBundle: bundle, quality: goodQuality(), producedAt: t0)
        XCTAssertEqual(e.sourceRef, "lb1")
        XCTAssertEqual(e.sourceKind, .learningBundle)
        XCTAssertTrue(e.isSafeForPool)
        XCTAssertEqual(BASDistillationBank().ingesting(e).admission, .admitted)
    }
}
