import XCTest
import BASMemory
@testable import QinaoHost
@testable import QinaoMemory

/// Property 5 · 会成长不乱长 — Grow, not wildly.
///
/// **What this demo proves:** the host constitution can grow and
/// shrink, but only through named, reversible transitions —
/// submit, preview, approve, reject, rollback, freeze, thaw.
/// There is no hidden "auto-learn" shortcut; every committed
/// change leaves an auditable trail, and every rollback returns
/// a clean projection.
///
/// We drive the candidate pipeline through its full state
/// machine, then prove two adjacent growth-control properties:
/// freeze makes a version unrollbackable, and `forgetAll`
/// resets the memory store without touching the host versions.
final class GrowNotWildlyDemo: XCTestCase {

    // MARK: - Full lifecycle

    func testSubmitPreviewApproveRollbackRoundTrips() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        let genesis = await fx.host.currentHost()
        XCTAssertEqual(
            genesis.constitutionSnapshot.activeVersion, "host.v1")

        let cand = BASHostChangeCandidate(
            candidateID: "cand.grow-1",
            changeType: "rhythm.adjust",
            proposedDelta: ["rhythm:shift-bedtime-22:30"],
            confidence: 0.88)
        _ = try await fx.host.submit(cand)
        _ = try await fx.host.preview(candidateID: cand.candidateID)
        let approved = try await fx.host.approve(
            candidateID: cand.candidateID)
        XCTAssertNotEqual(approved.activeVersion, "host.v1")
        let grownVersionID = approved.activeVersion

        // Rollback returns to genesis — the grown version still
        // exists in the tree (not deleted, just not projected).
        let rolled = try await fx.host.rollback(toVersionID: "host.v1")
        XCTAssertEqual(rolled.activeVersion, "host.v1")

        // Forward again to prove rollback is a pointer move,
        // not destruction: the grown version is still selectable.
        let reforward = try await fx.host.rollback(
            toVersionID: grownVersionID)
        XCTAssertEqual(reforward.activeVersion, grownVersionID)
    }

    // MARK: - Reject path

    func testRejectedCandidateLeavesAuditRecordAndNoVersion() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        let cand = BASHostChangeCandidate(
            candidateID: "cand.grow-reject",
            changeType: "boundary.relax",
            proposedDelta: ["boundary:relax-late-night-messages"],
            confidence: 0.30)
        _ = try await fx.host.submit(cand)

        let rec = try await fx.host.reject(
            candidateID: cand.candidateID,
            reason: "confidence-too-low")
        XCTAssertEqual(rec.candidateID, cand.candidateID)
        XCTAssertEqual(rec.reason, "confidence-too-low")

        // Active version is unchanged — a reject never writes to
        // the version tree.
        let after = await fx.host.currentHost()
        XCTAssertEqual(
            after.constitutionSnapshot.activeVersion, "host.v1")
    }

    // MARK: - Freeze stops unwanted growth paths

    func testFreezeVersionBlocksRollbackToIt() async throws {
        let fx = PropertyDemoFixture.makeRuntime()
        let cand = BASHostChangeCandidate(
            candidateID: "cand.grow-freeze",
            changeType: "style.tune",
            proposedDelta: ["style:more-concise"],
            confidence: 0.9)
        _ = try await fx.host.submit(cand)
        _ = try await fx.host.preview(candidateID: cand.candidateID)
        let approved = try await fx.host.approve(
            candidateID: cand.candidateID)
        let growID = approved.activeVersion

        // Roll back to genesis, then freeze the grown version so
        // no one can resurrect it by rolling forward again.
        _ = try await fx.host.rollback(toVersionID: "host.v1")
        _ = try await fx.host.freeze(versionID: growID)

        do {
            _ = try await fx.host.rollback(toVersionID: growID)
            XCTFail("frozen version should refuse rollback")
        } catch QinaoHost.HostError.versionFrozen(let id) {
            XCTAssertEqual(id, growID)
        }

        // Thaw restores the ability to roll forward — growth is
        // reversible without being destructive.
        _ = try await fx.host.thaw(versionID: growID)
        let back = try await fx.host.rollback(toVersionID: growID)
        XCTAssertEqual(back.activeVersion, growID)
    }

    // MARK: - Memory wipe is orthogonal to host versions

    func testForgetAllWipesMemoryButNotHostVersions() async throws {
        let fx = PropertyDemoFixture.makeRuntime()

        // Grow the host and seed some memory.
        let cand = BASHostChangeCandidate(
            candidateID: "cand.grow-coexist",
            changeType: "goal.add",
            proposedDelta: ["goal:read-before-bed"],
            confidence: 0.9)
        _ = try await fx.host.submit(cand)
        let approved = try await fx.host.approve(
            candidateID: cand.candidateID)
        let growID = approved.activeVersion

        for i in 0..<3 {
            _ = try await fx.memory.admit(.init(
                kind: .episodic,
                content: "ep-\(i)",
                scope: .user, sensitivity: .low,
                confidence: 0.8))
        }
        let beforeCount = await fx.memory.count()
        XCTAssertEqual(beforeCount, 3)

        // Wipe memory — this is a cascade, not a rollback; the
        // host version tree is untouched.
        let wiped = await fx.memory.forgetAll()
        XCTAssertEqual(wiped, 3)
        let afterCount = await fx.memory.count()
        XCTAssertEqual(afterCount, 0)

        let stillThere = await fx.host.currentHost()
        XCTAssertEqual(
            stillThere.constitutionSnapshot.activeVersion, growID)
    }
}
