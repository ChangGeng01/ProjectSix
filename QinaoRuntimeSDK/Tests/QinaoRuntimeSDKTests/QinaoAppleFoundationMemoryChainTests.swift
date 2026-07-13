import XCTest
import BASMemory
import QinaoLoop
import QinaoMemory
import QinaoAppleFoundation

/// M194 — real Apple FoundationModels output flowing through the
/// L8 memory governance gate + cascade delete.
///
/// ## What this proves
///
/// `QinaoMemory.admit(_:)` runs the substrate's governance gate
/// (confidence floor + sensitivity check). Existing tests use
/// hand-crafted bodies. M194 wraps a REAL on-device LLM body as
/// the memory content and proves three things:
///
/// 1. Sufficient-confidence real-LLM body → admitted, retrievable
///    via `recall()`, and a deletion path produces a cascade receipt.
/// 2. Below-floor confidence → `.rejectedByGovernance` with the
///    stable `confidence-below-floor` reason — no leak into the
///    store, no UUID returned to the caller.
/// 3. After admit + forget, `recall()` returns nothing and the
///    cascade ledger has the receipt — invariant #3 (宿主私有
///    经验不进基础权重) commits to "delete is real delete" on the
///    real-model chain.
final class QinaoAppleFoundationMemoryChainTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise real Apple FM " +
                "body flowing through L8 memory gate")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+")
    }

    private func generateRealLLMBody() async throws -> String {
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "mem-c1",
            title: "Memory chain seed",
            prompt:
                "Reply with one short sentence about a calming " +
                "evening habit.",
            role: .scout,
            expectedBenefit: 0.7, expectedCost: 0.2,
            reversibility: 0.9, confidence: 0.8)
        // M400.3 — Code 1026 → XCTSkip
        let drafts: [QinaoLoop.GeneratedCandidate]
        do {
            drafts = try await loop.generateCandidates(
                sessionID: "mem.real.1", seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        XCTAssertEqual(drafts.count, 1)
        return drafts[0].body
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 1. High-confidence admit + recall + cascade delete

    func testRealLLMBodyAdmittedRecallableAndCascadeDeletable()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody()
        XCTAssertFalse(body.isEmpty)

        let memory = QinaoMemory(minimumConfidence: 0.5)
        let admitted = try await memory.admit(
            QinaoMemory.AdmitRequest(
                kind: .episodic,
                content: body,
                scope: .session,
                sensitivity: .low,
                confidence: 0.85,
                preferredTier: .warm,
                sourceType: "qinao.test.m194",
                tags: ["m194", "real-llm"]),
            under: p1_7PermissiveConstitution())  // P1-7: governed path for recallability

        // Recall — body must come back byte-equal.
        let recalled = await memory.recall(
            scope: .session, sensitivity: .low)
        let bodies = recalled.map(\.content)
        XCTAssertTrue(
            bodies.contains(body),
            "admitted body must be retrievable via recall(...)")

        // Cascade-delete by ID + receipt check.
        let removed = try await memory.forget(id: admitted.id)
        XCTAssertEqual(
            removed.content, body,
            "forget(id:) must return the same memory it deleted")

        let postDelete = await memory.recall(
            scope: .session, sensitivity: .low)
        let postBodies = postDelete.map(\.content)
        XCTAssertFalse(
            postBodies.contains(body),
            "after forget(id:), recall MUST NOT return the body — " +
            "delete is real delete (invariant #3)")

        // The cascade ledger contains the proof-of-delete receipt.
        let receipts = await memory.cascadeLedger()
        XCTAssertEqual(
            receipts.count, 1,
            "exactly one cascade receipt expected after one forget")
        guard let receipt = receipts.first else { return }
        XCTAssertTrue(
            receipt.removedMemoryIDs.contains(admitted.id),
            "receipt MUST cite the deleted memory's UUID")
        XCTAssertEqual(receipt.executionState, .completed)
    }

    // MARK: - 2. Below-floor confidence → governance refusal

    func testRealLLMBodyBelowConfidenceFloorIsRefused()
        async throws
    {
        try skipUnlessReady()

        let body = try await generateRealLLMBody()
        XCTAssertFalse(body.isEmpty)

        // Floor is 0.6; admit at 0.4 — should be refused regardless
        // of how plausible the body is.
        let memory = QinaoMemory(minimumConfidence: 0.6)
        do {
            _ = try await memory.admit(
                QinaoMemory.AdmitRequest(
                    kind: .episodic,
                    content: body,
                    scope: .session,
                    sensitivity: .low,
                    confidence: 0.4,
                    preferredTier: .warm,
                    sourceType: "qinao.test.m194"))
            XCTFail(
                "admit at confidence=0.4 below floor=0.6 must throw")
        } catch let QinaoMemory.MemoryError
            .rejectedByGovernance(reason)
        {
            XCTAssertEqual(
                reason, "confidence-below-floor",
                "stable reason code MUST be " +
                "`confidence-below-floor` for floor-violation " +
                "refusal")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        // Refused content MUST NOT have leaked into the store.
        let recalled = await memory.recall(
            scope: .session, sensitivity: .low)
        XCTAssertTrue(
            recalled.isEmpty,
            "store MUST be empty after governance refusal — no " +
            "leak path. recalled.count = \(recalled.count)")
    }

    // MARK: - 3. Determinism: gate is pure-function over signals

    /// Pin the governance floor's purity offline. Required for the
    /// LLM-driven assertions to be reproducible.
    func testGovernanceFloorIsPureGivenIdenticalConfidence() async throws {
        let memory = QinaoMemory(minimumConfidence: 0.5)
        let request = QinaoMemory.AdmitRequest(
            kind: .episodic,
            content: "fixed body",
            scope: .session,
            sensitivity: .low,
            confidence: 0.49,
            preferredTier: .warm,
            sourceType: "qinao.test.m194")

        for _ in 0..<3 {
            do {
                _ = try await memory.admit(request)
                XCTFail("expected refusal at confidence < floor")
            } catch QinaoMemory.MemoryError
                .rejectedByGovernance
            {
                // expected
            }
        }
    }
}
