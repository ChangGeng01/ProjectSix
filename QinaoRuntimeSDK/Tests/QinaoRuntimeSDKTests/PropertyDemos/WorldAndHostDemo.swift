import XCTest
import BASMemory
@testable import QinaoHost
@testable import QinaoMemory

/// Property 2 · 懂世界也懂宿主 — World and host.
///
/// **What this demo proves:** host experience has two legal
/// landing zones, and neither one is the neural network's base
/// weights. A new host goal lands in the versioned host
/// constitution; a distilled episodic insight lands in the
/// governed memory store. Both are deletable and rollback-able.
///
/// We walk two tracks and then prove the deletion / rollback
/// story that keeps the landing zones honest:
///
/// 1. **Host track** — submit → preview → approve a host-change
///    candidate, observe the version tree advance, then roll
///    back to the genesis version. The committed change is no
///    longer projected.
/// 2. **Memory track** — admit a governed episodic memory,
///    recall it, then forget it. Recall after forget is empty.
final class WorldAndHostDemo: XCTestCase {

    // MARK: - Host track

    func testHostCandidateFlowsSubmitPreviewApproveRollback() async throws {
        let fx = PropertyDemoFixture.makeRuntime()

        // Genesis state.
        let genesis = await fx.host.currentHost()
        XCTAssertEqual(
            genesis.constitutionSnapshot.activeVersion, "host.v1")

        let candidate = BASHostChangeCandidate(
            candidateID: "cand.add-goal",
            changeType: "goal.add",
            proposedDelta: ["goal:walk-daily"],
            confidence: 0.9)

        // Stage — submit.
        _ = try await fx.host.submit(candidate)

        // Preview — shadow projection the host can inspect.
        let preview = try await fx.host.preview(
            candidateID: candidate.candidateID)
        XCTAssertEqual(preview.hostID, genesis.constitutionSnapshot.hostID)

        // Approve — the version tree advances; the active
        // pointer moves off host.v1 onto a new version.
        let approved = try await fx.host.approve(
            candidateID: candidate.candidateID)
        XCTAssertNotEqual(approved.activeVersion, "host.v1")

        // Rollback — the active pointer moves back to host.v1.
        // This is a pointer move, not a reconstruction; the
        // approved-version record still exists in the tree, but
        // is no longer the projection root.
        let rolled = try await fx.host.rollback(toVersionID: "host.v1")
        XCTAssertEqual(rolled.activeVersion, "host.v1")
    }

    // MARK: - Memory track

    func testMemoryAdmitRecallForgetIsEndToEndCascade() async throws {
        let fx = PropertyDemoFixture.makeRuntime()

        let request = QinaoMemory.AdmitRequest(
            kind: .episodic,
            content: "Host took a walk at 7am; mood improved.",
            scope: .user,
            sensitivity: .medium,
            confidence: 0.82,
            preferredTier: .warm)
        let admitted = try await fx.memory.admit(request)

        // Before forget — frontstage recall returns the memory.
        let frontstageBefore = await fx.memory.recallFrontstage()
        XCTAssertEqual(frontstageBefore.count, 1)
        XCTAssertEqual(frontstageBefore.first?.id, admitted.id)

        // Forget — cascade delete across every tier.
        _ = try await fx.memory.forget(id: admitted.id)

        // After forget — recall is empty, count is zero.
        let frontstageAfter = await fx.memory.recallFrontstage()
        XCTAssertTrue(frontstageAfter.isEmpty)
        let count = await fx.memory.count()
        XCTAssertEqual(count, 0)
    }

    /// Sensitivity-scoped cascade forget: "forget anything
    /// sensitive" wipes only high-sensitivity rows. This proves
    /// deletion is *typed* — a host can refuse the whole brain's
    /// memory of a category without touching the rest.
    func testSensitivityCascadeForgetIsTyped() async throws {
        let fx = PropertyDemoFixture.makeRuntime()

        _ = try await fx.memory.admit(.init(
            kind: .episodic, content: "low",
            scope: .user, sensitivity: .low,
            confidence: 0.8))
        _ = try await fx.memory.admit(.init(
            kind: .episodic, content: "high-1",
            scope: .user, sensitivity: .high,
            confidence: 0.8))
        _ = try await fx.memory.admit(.init(
            kind: .episodic, content: "high-2",
            scope: .user, sensitivity: .high,
            confidence: 0.8))

        let removed = await fx.memory.forget(sensitivity: .high)
        XCTAssertEqual(removed.count, 2)

        let remaining = await fx.memory.recallFrontstage()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.sensitivity, .low)
    }
}
