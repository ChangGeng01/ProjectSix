import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASSovereign
import BASOrchestration
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M131 — deep review fixes + edge-case regression tests.
///
/// Three production-code fixes from the M126-M130 self-review:
///
///   * **FIX_A** — `TurnResidue` was missing `renderFrame`
///     (M127 added the 4th parallel storage but M124's residue
///     shape predated it, so `outcome.residue` was incomplete).
///     Test suite pins the new field + 4 new verifier findings.
///   * **FIX_B** — `sendSession` computed `deriveSurfaceDecision`
///     four times per turn (3 inline helpers + outcome return);
///     M131 folds them into one compute. Pinned indirectly —
///     the result is byte-identical across all 4 usages, which
///     the test confirms.
///   * **FIX_C** — `SurfaceRetryPolicy` accepted negative seconds
///     and would emit `deferToLater(retryAfterSeconds: -45)` to
///     the UI. M131 clamps to ≥ 0 at init + in
///     `effectiveSeconds`.
///
/// Plus additional edge-case coverage flushed out during the
/// review (concurrent sessions, extreme inputs, storage growth).
final class QinaoRuntimeDeepReviewTests: XCTestCase {

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
        actor ToolRecorder {
            func record(name: String, payload: Data) -> Data {
                Data()
            }
        }
        let recorder = ToolRecorder()
        let snapshotManager = BASSovereignSnapshotManager(now: now)
        let versionTree = BASSovereignHostVersionTree(now: now)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        let coordinator = BASSovereignCleanRebootCoordinator(
            snapshotManager: snapshotManager,
            versionTree: versionTree,
            ledger: ledger,
            now: now)
        let tokenAuthority = BASSovereignTokenAuthority(now: now)
        let engine = BASSovereignVerdictEngine(
            ledger: ledger, now: now)
        let verifier = BASSovereignTurnVerifier(engine: engine)
        let sovereign = QinaoSovereignControlPlane(
            coordinator: coordinator,
            tokenAuthority: tokenAuthority,
            turnVerifier: verifier,
            auditLedger: ledger,
            warrantTTLSeconds: 10,
            now: now)
        let risk = QinaoRiskGate(permitTTLSeconds: 10, now: now)
        let constitution = BASHostConstitution(
            hostID: "host.m131",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        let host = QinaoHost(pipeline: pipeline)
        let memory = QinaoMemory()
        let loop = QinaoLoop()

        let executor: QinaoRuntime.ToolExecutor = { name, payload in
            await recorder.record(name: name, payload: payload)
        }
        let runtime = QinaoRuntime(
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: executor, now: now, lifecycle: nil)
        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String = "sess.m131",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.m131",
            policyHash: "policy.m131")
    }

    // MARK: - FIX_A — TurnResidue.renderFrame

    func testResidueCarriesRenderFramePostM131() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.residue.render")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let residue = try XCTUnwrap(outcome.residue)

        XCTAssertNotNil(
            residue.renderFrame,
            "residue must carry the M127 render frame")
        XCTAssertTrue(
            residue.isComplete,
            "all four surfaces present = complete")
    }

    func testVerifierFiresMissingRenderFrameWhenAbsent()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.render.missing")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let residueWithRender = try XCTUnwrap(outcome.residue)
        // Re-build a synthetic residue with sovereign frame but
        // no render frame — pins the .missingRenderFrame finding.
        let synth = QinaoSovereignControlPlane.TurnResidue(
            sessionID: residueWithRender.sessionID,
            turnID: residueWithRender.turnID,
            coverageReading: residueWithRender.coverageReading,
            observationBundle:
                residueWithRender.observationBundle,
            sovereignFrame: residueWithRender.sovereignFrame,
            renderFrame: nil)
        let v = fx.sovereign.verifyTurnResidue(synth)
        XCTAssertTrue(
            v.findings.contains(.missingRenderFrame),
            ".missingRenderFrame must fire when frame absent" +
                " but sovereign frame present")
    }

    func testVerifierFlagsRenderFrameIDDrift() async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.render.drift")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let base = try XCTUnwrap(outcome.residue)
        // Swap in a render frame whose frameID doesn't match
        // "render.<sess>.<turn>".
        let badRender = BASRenderFrame(
            frameID: "corrupt.render.id",
            mergedChoiceRef:
                "fold." + obs.sessionID + "." + obs.turnID,
            sovereignSurfaceRef: base.sovereignFrame?.frameID)
        let drifted = QinaoSovereignControlPlane.TurnResidue(
            sessionID: base.sessionID,
            turnID: base.turnID,
            coverageReading: base.coverageReading,
            observationBundle: base.observationBundle,
            sovereignFrame: base.sovereignFrame,
            renderFrame: badRender)
        let v = fx.sovereign.verifyTurnResidue(drifted)
        let hit = v.findings.contains {
            if case .renderFrameIDConventionMismatch(
                let expected, let got
            ) = $0 {
                return got == "corrupt.render.id"
                    && expected.hasPrefix("render.")
            }
            return false
        }
        XCTAssertTrue(
            hit,
            ".renderFrameIDConventionMismatch must fire")
    }

    func testVerifierFlagsRenderSovereignBackRefBroken()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.render.backref")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let base = try XCTUnwrap(outcome.residue)
        // Render frame with a bogus sovereignSurfaceRef that
        // doesn't point at the sovereign frame's frameID.
        let badRender = BASRenderFrame(
            frameID: "render." + obs.sessionID + "." + obs.turnID,
            mergedChoiceRef:
                "fold." + obs.sessionID + "." + obs.turnID,
            sovereignSurfaceRef: "frame.other.turn.other")
        let broken = QinaoSovereignControlPlane.TurnResidue(
            sessionID: base.sessionID,
            turnID: base.turnID,
            coverageReading: base.coverageReading,
            observationBundle: base.observationBundle,
            sovereignFrame: base.sovereignFrame,
            renderFrame: badRender)
        let v = fx.sovereign.verifyTurnResidue(broken)
        let hit = v.findings.contains {
            if case .renderSovereignBackRefBroken = $0 {
                return true
            }
            return false
        }
        XCTAssertTrue(
            hit,
            ".renderSovereignBackRefBroken must fire when" +
                " render.sovereignSurfaceRef !=" +
                " sovereign.frameID")
    }

    func testVerifierFlagsRenderMergedChoiceRefDrift()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.render.merged")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let base = try XCTUnwrap(outcome.residue)
        let badRender = BASRenderFrame(
            frameID: "render." + obs.sessionID + "." + obs.turnID,
            mergedChoiceRef: "drifted.fold.id",
            sovereignSurfaceRef: base.sovereignFrame?.frameID)
        let broken = QinaoSovereignControlPlane.TurnResidue(
            sessionID: base.sessionID,
            turnID: base.turnID,
            coverageReading: base.coverageReading,
            observationBundle: base.observationBundle,
            sovereignFrame: base.sovereignFrame,
            renderFrame: badRender)
        let v = fx.sovereign.verifyTurnResidue(broken)
        let hit = v.findings.contains {
            if case
                .renderMergedChoiceRefConventionMismatch(
                    _, let got
                ) = $0 {
                return got == "drifted.fold.id"
            }
            return false
        }
        XCTAssertTrue(
            hit,
            ".renderMergedChoiceRefConventionMismatch" +
                " must fire")
    }

    // MARK: - FIX_B — single deriveSurfaceDecision compute

    /// The render frame's three derived refs must match the
    /// surfaceDecision exposed on TurnOutcome — pins that the
    /// M131 dedup preserved byte-identity between the single
    /// compute and all downstream consumers.
    func testRenderFrameRefsAgreeWithOutcomeSurfaceDecision()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.dedup")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let decision = try XCTUnwrap(outcome.surfaceDecision)
        let rf = try XCTUnwrap(outcome.residue?.renderFrame)

        XCTAssertEqual(
            rf.outputSurfaceRef, decision.surface.rawValue,
            "output surface ref must equal outcome decision" +
                " (M131 dedup pin)")
        XCTAssertEqual(
            rf.substituteRef,
            decision.substitute.kind.rawValue,
            "substitute ref must equal outcome decision" +
                " (M131 dedup pin)")
        XCTAssertEqual(
            rf.disclosureProfileRef,
            decision.disclosure.rawValue,
            "disclosure ref must equal outcome decision" +
                " (M131 dedup pin)")
    }

    // MARK: - FIX_C — SurfaceRetryPolicy clamping

    func testSurfaceRetryPolicyClampsNegativeSeconds() {
        let policy = QinaoRuntime.SurfaceRetryPolicy(
            throttleSeconds: -30,
            shadowLockSeconds: -60,
            toolCutSeconds: -1,
            memoryFreezeSeconds: Int.min,
            quarantineSeconds: 0)
        XCTAssertEqual(policy.throttleSeconds, 0)
        XCTAssertEqual(policy.shadowLockSeconds, 0)
        XCTAssertEqual(policy.toolCutSeconds, 0)
        XCTAssertEqual(policy.memoryFreezeSeconds, 0)
        XCTAssertEqual(policy.quarantineSeconds, 0)
    }

    func testEffectiveSecondsNeverReturnsNegative() {
        // Even with a clamped-to-zero base, multiplier × 0 = 0.
        // Test defense-in-depth against a future multiplier
        // regression that might go negative.
        let policy = QinaoRuntime.SurfaceRetryPolicy(
            throttleSeconds: 0)
        let s = policy.effectiveSeconds(
            for: .throttle, thermalLevel: .emergency)
        XCTAssertNotNil(s)
        XCTAssertGreaterThanOrEqual(s ?? -1, 0)
    }

    func testSurfaceRetryPolicyAcceptsValidSeconds() {
        // Positive values pass through unchanged.
        let policy = QinaoRuntime.SurfaceRetryPolicy(
            throttleSeconds: 42,
            shadowLockSeconds: 99,
            toolCutSeconds: 200,
            memoryFreezeSeconds: 400,
            quarantineSeconds: 600)
        XCTAssertEqual(policy.throttleSeconds, 42)
        XCTAssertEqual(policy.shadowLockSeconds, 99)
        XCTAssertEqual(policy.toolCutSeconds, 200)
        XCTAssertEqual(policy.memoryFreezeSeconds, 400)
        XCTAssertEqual(policy.quarantineSeconds, 600)
    }

    // MARK: - Edge case: many turns in one session (storage growth)

    /// Long-running sessions: many turns all LWW-by-(sess, turn)
    /// produce distinct records. Each sendSession call adds one
    /// entry to sovereignFrames + observationBundles + renderFrames.
    /// 50 turns → 50 sovereign frames on the same session.
    func testManyTurnsProduceDistinctFramesSameSession()
        async throws {
        let fx = await makeRuntime()
        for i in 0..<50 {
            let obs = observations(
                turnID: "turn.seq.\(i)")
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
        }
        let count = await fx.sovereign.sovereignFrameCount()
        XCTAssertEqual(
            count, 50,
            "50 distinct turns produce 50 frames (no" +
                " accretion, no collapse)")
        let perSession = await fx.sovereign.sovereignFrames(
            forSession: "sess.m131")
        XCTAssertEqual(perSession.count, 50)
        // First-seen order preserved.
        XCTAssertEqual(
            perSession.first?.turnID, "turn.seq.0")
        XCTAssertEqual(
            perSession.last?.turnID, "turn.seq.49")
    }

    // MARK: - Edge case: empty snapshotRef passes through

    /// A TurnObservations with snapshotRef = "" (empty string)
    /// produces a sovereign frame where continuityRef stays nil
    /// (the empty check in QinaoRuntime.sendSession). Pinned so
    /// the documented contract survives future refactors.
    func testEmptySnapshotRefNilsOutContinuityRef() async throws {
        let fx = await makeRuntime()
        let emptyObs = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.empty-snap",
            turnID: "turn.empty-snap",
            snapshotRef: "",    // empty
            policyHash: "p.empty")
        _ = try await fx.runtime.sendSession(
            emptyObs, coordinatorSeverity: .pass)

        let frame = await fx.sovereign.sovereignFrame(
            sessionID: "sess.empty-snap",
            turnID: "turn.empty-snap")
        XCTAssertNotNil(frame)
        XCTAssertNil(
            frame?.continuityRef,
            "empty snapshotRef → nil continuityRef")
    }

    // MARK: - Edge case: concurrent sessions isolation

    /// Running sendSession on two distinct sessions concurrently
    /// must not collide on frame storage. Each session sees its
    /// own frames in its own first-seen order.
    func testConcurrentSessionsDoNotCollideOnStorage()
        async throws {
        let fx = await makeRuntime()

        // Run two sessions concurrently with 5 turns each.
        async let sessA: Void = {
            for i in 0..<5 {
                let obs = QinaoSovereignControlPlane
                    .TurnObservations(
                        sessionID: "sess.A",
                        turnID: "turn.A.\(i)",
                        snapshotRef: "snap.A.\(i)",
                        policyHash: "p.A")
                _ = try await fx.runtime.sendSession(
                    obs, coordinatorSeverity: .pass)
            }
        }()
        async let sessB: Void = {
            for i in 0..<5 {
                let obs = QinaoSovereignControlPlane
                    .TurnObservations(
                        sessionID: "sess.B",
                        turnID: "turn.B.\(i)",
                        snapshotRef: "snap.B.\(i)",
                        policyHash: "p.B")
                _ = try await fx.runtime.sendSession(
                    obs, coordinatorSeverity: .pass)
            }
        }()
        _ = try await (sessA, sessB)

        let totalFrames = await fx.sovereign
            .sovereignFrameCount()
        XCTAssertEqual(
            totalFrames, 10,
            "2 sessions × 5 turns = 10 distinct frames")

        let aFrames = await fx.sovereign.sovereignFrames(
            forSession: "sess.A")
        let bFrames = await fx.sovereign.sovereignFrames(
            forSession: "sess.B")
        XCTAssertEqual(aFrames.count, 5)
        XCTAssertEqual(bFrames.count, 5)
        // Frames are session-isolated — no cross-contamination.
        XCTAssertTrue(
            aFrames.allSatisfy { $0.sessionID == "sess.A" })
        XCTAssertTrue(
            bFrames.allSatisfy { $0.sessionID == "sess.B" })
    }

    // MARK: - FIX_A reproducer — real outcome residue verifies clean

    /// End-to-end: real sendSession → outcome.residue →
    /// verifyTurnResidue should return zero findings. This
    /// exercises the new render-frame convention checks against
    /// production-path values (M131 pre-fix would have missed
    /// the render-frame entry altogether).
    func testRealOutcomeResidueVerifiesCleanAllFourSurfaces()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(turnID: "turn.end-to-end")

        let outcome = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)
        let residue = try XCTUnwrap(outcome.residue)
        XCTAssertTrue(residue.isComplete)

        let v = fx.sovereign.verifyTurnResidue(residue)
        XCTAssertTrue(
            v.isValid,
            "four-surface residue must verify clean e2e")
        XCTAssertTrue(
            v.findings.isEmpty,
            "no cross-surface findings on healthy turn")
    }
}
