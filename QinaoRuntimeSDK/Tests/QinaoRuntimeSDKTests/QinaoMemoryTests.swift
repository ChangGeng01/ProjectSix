import XCTest
import BASMemory
@testable import QinaoMemory

/// M7.4 — QinaoMemory façade over `BASMemoryGovernance` +
/// `BASMemoryTierFilter`.
///
/// The substrate primitives are exhaustively tested in the BAS suite;
/// this file only proves the *façade* behavior:
///
/// 1. Admission runs through the real governance gate (confidence
///    floor enforced; on-floor accepts, below-floor rejects).
/// 2. Recall honours scope / sensitivity / tier filters using the
///    substrate's canonical ordering.
/// 3. Frontstage recall drops cold-tier entries (L8 rule).
/// 4. Cascade deletes actually clear every matching memory across
///    all tiers — not just one.
/// 5. Targeted `forget(id:)` surfaces `MemoryError.notFound` for
///    unknown IDs.
final class QinaoMemoryTests: XCTestCase {

    private func makeMemory(
        minimumConfidence: Double = 0.6
    ) -> QinaoMemory {
        QinaoMemory(
            minimumConfidence: minimumConfidence,
            now: { Date(timeIntervalSince1970: 1_700_000_000) })
    }

    private func admitRequest(
        kind: BASMemoryKind = .episodic,
        content: String = "default content",
        scope: BASMemoryScope = .session,
        sensitivity: BASMemorySensitivity = .low,
        confidence: Double = 0.8,
        preferredTier: BASMemoryTier = .warm
    ) -> QinaoMemory.AdmitRequest {
        QinaoMemory.AdmitRequest(
            kind: kind,
            content: content,
            scope: scope,
            sensitivity: sensitivity,
            confidence: confidence,
            preferredTier: preferredTier)
    }

    // MARK: - Admission

    func testAdmitPromotesCandidateAboveConfidenceFloor() async throws {
        let memory = makeMemory(minimumConfidence: 0.6)
        let governed = try await memory.admit(
            admitRequest(confidence: 0.75))
        XCTAssertEqual(governed.governanceStatus, .governed)
        XCTAssertEqual(governed.content, "default content")
        let count = await memory.count()
        XCTAssertEqual(count, 1)
    }

    func testAdmitRejectsCandidateBelowConfidenceFloor() async throws {
        let memory = makeMemory(minimumConfidence: 0.6)
        do {
            _ = try await memory.admit(admitRequest(confidence: 0.4))
            XCTFail("admit should reject below-floor candidate")
        } catch QinaoMemory.MemoryError.rejectedByGovernance(let reason) {
            XCTAssertEqual(reason, "confidence-below-floor")
        }
        let count = await memory.count()
        XCTAssertEqual(count, 0,
            "rejected admission must not mutate the store")
    }

    // MARK: - Recall: scope / sensitivity / tier filters

    func testRecallHonoursScopeFilter() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(content: "a", scope: .session))
        _ = try await memory.admit(
            admitRequest(content: "b", scope: .user))
        _ = try await memory.admit(
            admitRequest(content: "c", scope: .device))
        let sessionOnly = await memory.recall(scope: .session)
        XCTAssertEqual(sessionOnly.map(\.content), ["a"])
    }

    func testRecallHonoursTierFilter() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(content: "hot", preferredTier: .hot))
        _ = try await memory.admit(
            admitRequest(content: "warm", preferredTier: .warm))
        _ = try await memory.admit(
            admitRequest(content: "cold", preferredTier: .cold))
        let hotOnly = await memory.recall(tiers: [.hot])
        XCTAssertEqual(hotOnly.map(\.content), ["hot"])
        let hotOrWarm = await memory.recall(tiers: [.hot, .warm])
        XCTAssertEqual(Set(hotOrWarm.map(\.content)), ["hot", "warm"])
    }

    func testRecallOrdersByTierThenConfidence() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(
                content: "warm-lo",
                confidence: 0.7,
                preferredTier: .warm))
        _ = try await memory.admit(
            admitRequest(
                content: "hot-lo",
                confidence: 0.65,
                preferredTier: .hot))
        _ = try await memory.admit(
            admitRequest(
                content: "hot-hi",
                confidence: 0.95,
                preferredTier: .hot))

        // Expected substrate ordering: tier desc, then confidence desc.
        let recalled = await memory.recall()
        XCTAssertEqual(
            recalled.map(\.content),
            ["hot-hi", "hot-lo", "warm-lo"])
    }

    // MARK: - Frontstage recall

    func testFrontstageRecallDropsColdTier() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(content: "hot-trace", preferredTier: .hot))
        _ = try await memory.admit(
            admitRequest(content: "warm-thread", preferredTier: .warm))
        _ = try await memory.admit(
            admitRequest(content: "cold-prior", preferredTier: .cold))

        let front = await memory.recallFrontstage()
        XCTAssertEqual(
            Set(front.map(\.content)),
            ["hot-trace", "warm-thread"])
        XCTAssertFalse(front.map(\.content).contains("cold-prior"))
    }

    // MARK: - Forget (cascade semantics)

    func testForgetByScopeRemovesAllMatches() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(content: "a", scope: .session))
        _ = try await memory.admit(
            admitRequest(content: "b", scope: .session))
        _ = try await memory.admit(
            admitRequest(content: "keep", scope: .user))

        let removed = await memory.forget(scope: .session)
        XCTAssertEqual(removed.count, 2)
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["keep"])
    }

    func testForgetBySensitivityRemovesAllMatches() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(content: "low-1", sensitivity: .low))
        _ = try await memory.admit(
            admitRequest(content: "high-1", sensitivity: .high))
        _ = try await memory.admit(
            admitRequest(content: "high-2", sensitivity: .high))

        let removed = await memory.forget(sensitivity: .high)
        XCTAssertEqual(removed.count, 2)
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["low-1"])
    }

    func testForgetByIDRemovesExactlyOne() async throws {
        let memory = makeMemory()
        let a = try await memory.admit(admitRequest(content: "a"))
        _ = try await memory.admit(admitRequest(content: "b"))

        let removed = try await memory.forget(id: a.id)
        XCTAssertEqual(removed.content, "a")
        let remaining = await memory.recall()
        XCTAssertEqual(remaining.map(\.content), ["b"])
    }

    func testForgetByIDNotFoundSurfacesTypedError() async throws {
        let memory = makeMemory()
        let ghost = UUID()
        do {
            _ = try await memory.forget(id: ghost)
            XCTFail("expected notFound")
        } catch QinaoMemory.MemoryError.notFound(let id) {
            XCTAssertEqual(id, ghost)
        }
    }

    func testForgetAllWipesEveryTier() async throws {
        let memory = makeMemory()
        _ = try await memory.admit(
            admitRequest(preferredTier: .hot))
        _ = try await memory.admit(
            admitRequest(preferredTier: .warm))
        _ = try await memory.admit(
            admitRequest(preferredTier: .cold))

        let removed = await memory.forgetAll()
        XCTAssertEqual(removed, 3)
        let count = await memory.count()
        XCTAssertEqual(count, 0)
    }
}
