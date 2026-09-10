import XCTest
@testable import BASRuntimeCore
@testable import BASMemory

/// Tests for the L5 host-constitution candidate pipeline.
///
/// The single most important test here is
/// `testParityBetweenActorPathAndPureComposition`. It pins the
/// contract that the pipeline and the raw pure helpers produce the
/// same external projection. Every other test is lifecycle
/// coverage: submit, preview, approve, reject, rollback, freeze,
/// thaw, and the error paths around them.
final class BASHostCandidatePipelineTests: XCTestCase {

    // MARK: - Parity

    /// Running `submit → preview → approve` through the actor must
    /// produce the exact same `BASHostConstitutionVault` as the
    /// pure composition helper. This is the M6 "projection parity
    /// proof" promise — without it the pipeline is just another
    /// mutable cache.
    func testParityBetweenActorPathAndPureComposition() async throws {
        let base = Self.baseConstitution()
        let tree = Self.baseVersionTree()
        let candidate = Self.candidate(id: "candidate.goal.v2")

        let fixedClock: @Sendable () -> Date = {
            Date(timeIntervalSince1970: 1_730_000_000)
        }

        // Path A: through the actor
        let pipeline = BASHostCandidatePipeline(
            constitution: base,
            versionTree: tree,
            clock: fixedClock)
        _ = try await pipeline.submit(candidate)
        _ = try await pipeline.preview(candidate.candidateID)
        _ = try await pipeline.approve(candidate.candidateID)
        let actorProjection = await pipeline.project()

        // Path B: pure composition (no actor)
        let pureProjection = BASHostCandidatePipeline.parityProjection(
            of: candidate,
            from: base,
            versionTree: tree,
            approvedAt: fixedClock())

        XCTAssertEqual(
            actorProjection.constitutionSnapshot.activeVersion,
            pureProjection.constitutionSnapshot.activeVersion)
        XCTAssertEqual(
            actorProjection.rollbackLineage,
            pureProjection.rollbackLineage)
        XCTAssertEqual(
            actorProjection.constitutionSnapshot.narrativeLoom.currentPhase,
            pureProjection.constitutionSnapshot.narrativeLoom.currentPhase)
        XCTAssertEqual(
            actorProjection.constitutionSnapshot.narrativeLoom.continuityLinks,
            pureProjection.constitutionSnapshot.narrativeLoom.continuityLinks)
        XCTAssertEqual(
            actorProjection.constitutionSnapshot.narrativeLoom.unresolvedTensions,
            pureProjection.constitutionSnapshot.narrativeLoom.unresolvedTensions)

        // A tighter assertion: the two constitutions must be
        // byte-wise equal when encoded through JSON. This catches
        // drift in any field the per-field asserts above miss.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let actorBytes = try encoder.encode(
            actorProjection.constitutionSnapshot)
        let pureBytes = try encoder.encode(
            pureProjection.constitutionSnapshot)
        if actorBytes != pureBytes {
            let a = String(data: actorBytes, encoding: .utf8) ?? ""
            let p = String(data: pureBytes, encoding: .utf8) ?? ""
            // Find first diff index to narrow down the drift.
            var idx = 0
            for (ca, cp) in zip(a, p) {
                if ca != cp { break }
                idx += 1
            }
            let start = max(0, idx - 40)
            let endA = min(a.count, idx + 80)
            let endP = min(p.count, idx + 80)
            let aSlice = String(a[a.index(a.startIndex, offsetBy: start)
                ..< a.index(a.startIndex, offsetBy: endA)])
            let pSlice = String(p[p.index(p.startIndex, offsetBy: start)
                ..< p.index(p.startIndex, offsetBy: endP)])
            XCTFail("""
                Actor projection diverged from pure composition
                first diff at offset \(idx)
                ACTOR: \(aSlice)
                PURE : \(pSlice)
                """)
        }
    }

    // MARK: - Lifecycle: submit

    func testSubmitAddsCandidateAndPending() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.a")
        let stored = try await pipeline.submit(c)
        XCTAssertEqual(stored.approvalState, "pending")
        let pending = await pipeline.pendingIDs()
        XCTAssertEqual(pending, ["candidate.a"])
    }

    func testSubmitRejectsDuplicate() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "dup")
        _ = try await pipeline.submit(c)
        do {
            _ = try await pipeline.submit(c)
            XCTFail("expected duplicateCandidate")
        } catch BASHostCandidatePipeline.PipelineError
            .duplicateCandidate(let id)
        {
            XCTAssertEqual(id, "dup")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Lifecycle: preview

    func testPreviewReturnsStagedConstitution() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.preview")
        _ = try await pipeline.submit(c)

        let staged = try await pipeline.preview(c.candidateID)
        XCTAssertEqual(
            staged.narrativeLoom.currentPhase, "preview")
        XCTAssertTrue(staged.narrativeLoom.continuityLinks.contains(
            "host.v1->candidate.preview"))
    }

    func testPreviewRejectsUnknownCandidate() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        do {
            _ = try await pipeline.preview("ghost")
            XCTFail("expected unknownCandidate")
        } catch BASHostCandidatePipeline.PipelineError
            .unknownCandidate(let id)
        {
            XCTAssertEqual(id, "ghost")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Lifecycle: approve

    func testApproveCommitsAndUpdatesActiveVersion() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.approve")
        _ = try await pipeline.submit(c)
        _ = try await pipeline.preview(c.candidateID)
        let committed = try await pipeline.approve(c.candidateID)

        XCTAssertEqual(committed.activeVersion, "candidate.approve")
        let tree = await pipeline.currentVersionTree()
        XCTAssertEqual(tree.activeVersionID, "candidate.approve")
        XCTAssertTrue(tree.versions.contains(
            where: { $0.versionID == "candidate.approve" }))
        XCTAssertTrue(tree.pendingCandidateIDs.isEmpty)
    }

    /// The pipeline auto-stages if `preview()` was skipped — the
    /// committed constitution must still carry the candidate
    /// annotations. Callers that go `submit → approve` directly
    /// (e.g. via auto-approval policy) should see the same
    /// projection as the normal `submit → preview → approve` path.
    func testApproveWithoutPreviewStillFoldsStagedNarrative() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.fast-track")
        _ = try await pipeline.submit(c)
        let committed = try await pipeline.approve(c.candidateID)
        XCTAssertEqual(
            committed.narrativeLoom.currentPhase, "preview")
    }

    func testApproveTwiceRejectsSecondCall() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.twice")
        _ = try await pipeline.submit(c)
        _ = try await pipeline.approve(c.candidateID)
        do {
            _ = try await pipeline.approve(c.candidateID)
            XCTFail("expected candidateAlreadyDecided")
        } catch BASHostCandidatePipeline.PipelineError
            .candidateAlreadyDecided(let id, let state)
        {
            XCTAssertEqual(id, "candidate.twice")
            XCTAssertEqual(state, "approved")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Lifecycle: reject

    func testRejectRemovesPendingAndLogs() async throws {
        let clockValue = Date(timeIntervalSince1970: 1_750_000_000)
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree(),
            clock: { clockValue })
        let c = Self.candidate(id: "candidate.reject")
        _ = try await pipeline.submit(c)
        let record = try await pipeline.reject(
            c.candidateID, reason: "violates boundary")

        XCTAssertEqual(record.reason, "violates boundary")
        XCTAssertEqual(record.recordedAt, clockValue)

        let pending = await pipeline.pendingIDs()
        XCTAssertTrue(pending.isEmpty)

        let log = await pipeline.rejectionLog()
        XCTAssertEqual(log.count, 1)

        do {
            _ = try await pipeline.approve(c.candidateID)
            XCTFail("expected candidateAlreadyDecided")
        } catch BASHostCandidatePipeline.PipelineError
            .candidateAlreadyDecided {
            // ok
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Rollback / freeze / thaw

    func testRollbackUpdatesActiveVersionAndTree() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.v2")
        _ = try await pipeline.submit(c)
        _ = try await pipeline.approve(c.candidateID)

        let rolled = try await pipeline.rollback(to: "host.v1")
        XCTAssertEqual(rolled.activeVersion, "host.v1")
        let tree = await pipeline.currentVersionTree()
        XCTAssertEqual(tree.activeVersionID, "host.v1")
    }

    func testRollbackToFrozenIsRejected() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.v2")
        _ = try await pipeline.submit(c)
        _ = try await pipeline.approve(c.candidateID)
        _ = try await pipeline.freeze(versionID: "host.v1")

        do {
            _ = try await pipeline.rollback(to: "host.v1")
            XCTFail("expected versionFrozen")
        } catch BASHostCandidatePipeline.PipelineError
            .versionFrozen(let id)
        {
            XCTAssertEqual(id, "host.v1")
        } catch {
            XCTFail("unexpected: \(error)")
        }

        // Thaw, then rollback succeeds.
        _ = try await pipeline.thaw(versionID: "host.v1")
        _ = try await pipeline.rollback(to: "host.v1")
        let tree = await pipeline.currentVersionTree()
        XCTAssertEqual(tree.activeVersionID, "host.v1")
    }

    func testRollbackUnknownVersionFails() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        do {
            _ = try await pipeline.rollback(to: "ghost")
            XCTFail("expected versionNotFound")
        } catch BASHostCandidatePipeline.PipelineError
            .versionNotFound(let id)
        {
            XCTAssertEqual(id, "ghost")
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - Projection helpers

    func testProjectReflectsActiveVersion() async throws {
        let pipeline = BASHostCandidatePipeline(
            constitution: Self.baseConstitution(),
            versionTree: Self.baseVersionTree())
        let c = Self.candidate(id: "candidate.project")
        _ = try await pipeline.submit(c)
        _ = try await pipeline.approve(c.candidateID)
        let vault = await pipeline.project()
        XCTAssertEqual(
            vault.constitutionSnapshot.activeVersion,
            "candidate.project")
        XCTAssertTrue(vault.rollbackLineage.contains("candidate.project"))
    }

    // MARK: - Fixtures

    private static func baseConstitution() -> BASHostConstitution {
        BASHostConstitution(
            hostID: "host",
            activeVersion: "host.v1",
            narrativeLoom: BASNarrativeLoom(
                longFormSummary: "stable",
                currentPhase: "stable",
                continuityLinks: ["host.v0->host.v1"],
                unresolvedTensions: []))
    }

    private static func baseVersionTree() -> BASHostVersionTree {
        BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: Date(timeIntervalSince1970: 1_600_000_000),
                    changedFields: ["identity_lattice"],
                    reason: "bootstrap",
                    approvedByPolicy: true)
            ])
    }

    private static func candidate(id: String) -> BASHostChangeCandidate {
        BASHostChangeCandidate(
            candidateID: id,
            changeType: "goal_spine",
            proposedDelta: ["goal_spine", "boundary_veil"],
            evidenceRefs: ["memory.turn.42"],
            confidence: 0.88,
            conflictRefs: ["boundary.review"])
    }
}
