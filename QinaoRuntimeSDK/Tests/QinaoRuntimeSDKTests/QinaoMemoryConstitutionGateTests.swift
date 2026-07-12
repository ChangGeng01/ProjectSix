import XCTest
import BASMemory
@testable import QinaoMemory

/// charter audit 2026-07-12 — the constitution-aware admit overload (first production
/// wiring of BASMemoryGovernance.shouldAdmit(under:)): a consent-lattice memoryWriteScope
/// of "disabled"/"none" fails closed with its own stable reason.
final class QinaoMemoryConstitutionGateTests: XCTestCase {

    private func constitution(
        scope: String, promotion: String = "review_required"
    ) -> BASHostConstitution {
        var c = BASHostConstitution(hostID: "h", activeVersion: "v1")
        c.consentLattice.memoryWriteScope = scope
        c.consentLattice.memoryPromotionScope = promotion
        return c
    }

    private func request(tier: BASMemoryTier = .warm) -> QinaoMemory.AdmitRequest {
        QinaoMemory.AdmitRequest(
            kind: .episodic, content: "llm text", scope: .session,
            sensitivity: .low, confidence: 0.8, preferredTier: tier,
            sourceType: "qinao-sample.llm:test")
    }

    func testWarmOnlyScopeAdmits() async throws {
        let memory = QinaoMemory()
        let governed = try await memory.admit(request(), under: constitution(scope: "warm_only"))
        XCTAssertEqual(governed.sourceType, "qinao-sample.llm:test")
        let count = await memory.count()
        XCTAssertEqual(count, 1)
    }

    // deep-audit HIGH-1 (2026-07-13): the gate must enforce at PROMOTION, not only at
    // admission. These pin the governance OUTCOME the earlier tests were blind to
    // (green-by-luck under both the buggy blind-promote and the correct constitution-promote).

    /// review_required (the seed default) → HELD as .candidate, excluded from frontstage.
    func testReviewRequiredHoldsAsCandidateOutOfFrontstage() async throws {
        let memory = QinaoMemory()
        let m = try await memory.admit(
            request(), under: constitution(scope: "warm_only", promotion: "review_required"))
        XCTAssertEqual(m.governanceStatus, .candidate,
            "unreviewed content must be held, not auto-promoted to governed")
        XCTAssertEqual(m.sourceType, "qinao-sample.llm:test",
            "the held candidate keeps its truthful LLM provenance")
        let frontstage = await memory.recallFrontstage()
        XCTAssertTrue(frontstage.isEmpty, "a held candidate must not be frontstage-eligible")
        let recalled = await memory.recall()
        XCTAssertTrue(recalled.isEmpty, "recall() is governed-only, so a candidate is absent")
        let stored = await memory.count()
        XCTAssertEqual(stored, 1, "but it IS stored (held for review), not dropped")
    }

    /// A permissive constitution (promotion allowed) → .governed + frontstage-eligible.
    func testPermissivePromotionGovernsAndReachesFrontstage() async throws {
        let memory = QinaoMemory()
        let m = try await memory.admit(
            request(), under: constitution(scope: "warm_only", promotion: "auto"))
        XCTAssertEqual(m.governanceStatus, .governed)
        let frontstage = await memory.recallFrontstage()
        XCTAssertEqual(frontstage.count, 1, "governed memory is frontstage-eligible")
    }

    /// The tier CAP is enforced: cold_only projects the atom to .cold regardless of
    /// preferredTier (the blind promote kept preferredTier).
    func testColdOnlyScopeCapsTier() async throws {
        let memory = QinaoMemory()
        let m = try await memory.admit(
            request(tier: .hot), under: constitution(scope: "cold_only", promotion: "auto"))
        XCTAssertEqual(m.tier, .cold, "cold_only must cap the tier, not honor preferredTier .hot")
    }

    func testDisabledScopeFailsClosedWithTypedReason() async {
        let memory = QinaoMemory()
        for scope in ["disabled", "none"] {
            do {
                _ = try await memory.admit(request(), under: constitution(scope: scope))
                XCTFail("scope \(scope) must refuse the write")
            } catch QinaoMemory.MemoryError.rejectedByGovernance(let reason) {
                XCTAssertEqual(reason, "memory-write-scope-disabled")
            } catch {
                XCTFail("unexpected error: \(error)")
            }
        }
        let count = await memory.count()
        XCTAssertEqual(count, 0, "refused writes must leave zero state")
    }

    /// deep-audit L-5 (2026-07-13): non-canonical scope spellings must ALSO fail closed
    /// (the gate previously used exact case-sensitive == and would silently admit these,
    /// diverging from the substrate's canonical lowercase+contains reader).
    func testNonCanonicalDisabledSpellingsFailClosed() async {
        let memory = QinaoMemory()
        for scope in ["Disabled", "NONE", "cold_disabled", "  none  "] {
            do {
                _ = try await memory.admit(request(), under: constitution(scope: scope))
                XCTFail("non-canonical off-scope '\(scope)' must still refuse")
            } catch QinaoMemory.MemoryError.rejectedByGovernance(let reason) {
                XCTAssertEqual(reason, "memory-write-scope-disabled")
            } catch { XCTFail("unexpected: \(error)") }
        }
        let count = await memory.count()
        XCTAssertEqual(count, 0)
    }

    func testConfidenceFloorStillFirst() async {
        let memory = QinaoMemory()
        var req = request()
        req = QinaoMemory.AdmitRequest(
            kind: .episodic, content: "x", scope: .session,
            sensitivity: .low, confidence: 0.1, sourceType: "t")
        do {
            _ = try await memory.admit(req, under: constitution(scope: "warm_only"))
            XCTFail("confidence floor must refuse")
        } catch QinaoMemory.MemoryError.rejectedByGovernance(let reason) {
            XCTAssertEqual(reason, "confidence-below-floor")
        } catch { XCTFail("unexpected: \(error)") }
    }
}
