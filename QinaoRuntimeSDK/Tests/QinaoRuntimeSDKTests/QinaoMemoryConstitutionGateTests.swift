import XCTest
import BASMemory
@testable import QinaoMemory

/// charter audit 2026-07-12 — the constitution-aware admit overload (first production
/// wiring of BASMemoryGovernance.shouldAdmit(under:)): a consent-lattice memoryWriteScope
/// of "disabled"/"none" fails closed with its own stable reason.
final class QinaoMemoryConstitutionGateTests: XCTestCase {

    private func constitution(scope: String) -> BASHostConstitution {
        var c = BASHostConstitution(hostID: "h", activeVersion: "v1")
        c.consentLattice.memoryWriteScope = scope
        return c
    }

    private func request() -> QinaoMemory.AdmitRequest {
        QinaoMemory.AdmitRequest(
            kind: .episodic, content: "llm text", scope: .session,
            sensitivity: .low, confidence: 0.8, sourceType: "qinao-sample.llm:test")
    }

    func testWarmOnlyScopeAdmits() async throws {
        let memory = QinaoMemory()
        let governed = try await memory.admit(request(), under: constitution(scope: "warm_only"))
        XCTAssertEqual(governed.sourceType, "qinao-sample.llm:test")
        let count = await memory.count()
        XCTAssertEqual(count, 1)
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
