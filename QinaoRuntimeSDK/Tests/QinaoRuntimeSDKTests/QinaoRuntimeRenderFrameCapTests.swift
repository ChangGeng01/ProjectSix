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

/// M132 — bounded `renderFrameEntries[]` with FIFO eviction.
///
/// Pre-M132 the Qinao-side render-frame storage grew unbounded —
/// a long chat session would accumulate hundreds or thousands of
/// entries forever. M132 caps the storage at a configurable
/// ceiling (default 4096); when a new (sessionID, turnID) tuple
/// would push it past the cap, the oldest entry gets evicted
/// FIFO-style.
///
/// Pins:
///   1. Cap is configurable via bootstrap init (ControlPlane ctor).
///   2. Cap of N + (N + k) distinct turns ⇒ exactly N entries
///      remain after the last record call.
///   3. Evicted entries are the OLDEST (first-seen), not newest.
///   4. LWW on an EXISTING (sessionID, turnID) key does NOT
///      increment size or trigger eviction.
///   5. Cap clamped to ≥ 1 — zero or negative cap falls back to 1
///      (conservative: at least one entry always holds).
///   6. Default-constructed runtime uses 4096 cap (sanity check).
final class QinaoRuntimeRenderFrameCapTests: XCTestCase {

    struct Fixture: Sendable {
        let sovereign: QinaoSovereignControlPlane
        let runtime: QinaoRuntime
    }

    private func makeRuntime(
        cap: Int? = nil,
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

        let sovereign: QinaoSovereignControlPlane
        if let cap = cap {
            sovereign = QinaoSovereignControlPlane(
                coordinator: coordinator,
                tokenAuthority: tokenAuthority,
                turnVerifier: verifier,
                auditLedger: ledger,
                warrantTTLSeconds: 10,
                now: now,
                renderFrameCapacity: cap)
        } else {
            sovereign = QinaoSovereignControlPlane(
                coordinator: coordinator,
                tokenAuthority: tokenAuthority,
                turnVerifier: verifier,
                auditLedger: ledger,
                warrantTTLSeconds: 10,
                now: now)
        }

        let risk = QinaoRiskGate(permitTTLSeconds: 10, now: now)
        let constitution = BASHostConstitution(
            hostID: "host.m132",
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
        return Fixture(sovereign: sovereign, runtime: runtime)
    }

    // MARK: - 1. Cap enforced — array bounded at capacity

    func testCapIsEnforced() async throws {
        let fx = await makeRuntime(cap: 8)
        for i in 0..<12 {
            let obs = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: "sess.cap",
                    turnID: "turn.\(i)",
                    snapshotRef: "snap.\(i)",
                    policyHash: "p.\(i)")
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
        }
        let remaining = await fx.sovereign.renderFrameCount()
        XCTAssertEqual(
            remaining, 8,
            "cap 8 + 12 distinct turns = 8 frames remain")
    }

    // Helper to keep XCTAssertEqual autoclosures synchronous:
    // actor-isolated calls must be awaited before the assertion.

    // MARK: - 2. FIFO eviction drops the OLDEST

    func testFIFOEvictsOldestFirst() async throws {
        let fx = await makeRuntime(cap: 3)
        // Record 5 distinct turns: turn.0 .. turn.4.
        for i in 0..<5 {
            let obs = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: "sess.fifo",
                    turnID: "turn.\(i)",
                    snapshotRef: "snap.\(i)",
                    policyHash: "p.\(i)")
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
        }
        // After 5 records into a cap-3 store:
        // - turn.0 and turn.1 should be evicted (oldest)
        // - turn.2, turn.3, turn.4 should remain in order
        let frames = await fx.sovereign.renderFrames(
            forSession: "sess.fifo")
        XCTAssertEqual(frames.count, 3)
        let ids = frames.map(\.frameID)
        XCTAssertEqual(
            ids,
            // M163 — IDs containing '.' are percent-escaped per
            // QinaoSovereignControlPlane.syntheticRef convention.
            [
                "render.sess%2Efifo.turn%2E2",
                "render.sess%2Efifo.turn%2E3",
                "render.sess%2Efifo.turn%2E4",
            ],
            "oldest evicted, newest preserved in order")
    }

    // MARK: - 3. LWW on existing key does not evict

    func testLWWDoesNotTriggerEviction() async throws {
        // M161 — sendSession now rejects duplicate (sess, turn)
        // submissions. The LWW property is a STORAGE-LAYER
        // invariant tested by direct recordRenderFrame calls
        // (which the M127 storage retains for hosts that re-emit
        // mid-turn). Test rewritten to call the lower-level
        // record API directly.
        let fx = await makeRuntime(cap: 2)
        // Fill to capacity with two distinct (sess, turn) keys
        // via direct record calls. M163 — frameIDs use the
        // percent-escape syntheticRef convention.
        func renderRef(_ i: Int) -> String {
            QinaoSovereignControlPlane.syntheticRef(
                prefix: "render",
                sessionID: "sess.lww",
                turnID: "turn.\(i)")
        }
        for i in 0..<2 {
            let frame = BASRenderFrame(
                frameID: renderRef(i))
            await fx.sovereign.recordRenderFrame(
                frame,
                sessionID: "sess.lww",
                turnID: "turn.\(i)")
        }
        let countAfterFill = await fx.sovereign
            .renderFrameCount()
        XCTAssertEqual(countAfterFill, 2)
        // Re-record turn.0 50 times — LWW replaces in place;
        // count stays 2; no eviction triggers.
        for _ in 0..<50 {
            let frame = BASRenderFrame(
                frameID: renderRef(0))
            await fx.sovereign.recordRenderFrame(
                frame,
                sessionID: "sess.lww",
                turnID: "turn.0")
        }
        let frames = await fx.sovereign.renderFrames(
            forSession: "sess.lww")
        XCTAssertEqual(frames.count, 2)
        // Original order preserved — turn.0 stays at position 0,
        // turn.1 at position 1 — LWW rewrites in place.
        XCTAssertEqual(
            frames.map(\.frameID),
            [renderRef(0), renderRef(1)])
    }

    // MARK: - 4. Zero / negative cap clamps to 1

    func testZeroOrNegativeCapClampsToOne() async throws {
        let fxZero = await makeRuntime(cap: 0)
        let fxNeg = await makeRuntime(cap: -50)

        for fx in [fxZero, fxNeg] {
            for i in 0..<3 {
                let obs = QinaoSovereignControlPlane
                    .TurnObservations(
                        sessionID: "sess.clamp",
                        turnID: "turn.\(i)",
                        snapshotRef: "s",
                        policyHash: "p")
                _ = try await fx.runtime.sendSession(
                    obs, coordinatorSeverity: .pass)
            }
            let count = await fx.sovereign.renderFrameCount()
            XCTAssertEqual(
                count, 1,
                "clamp-to-1: only the newest turn survives")
            let frames = await fx.sovereign.renderFrames(
                forSession: "sess.clamp")
            XCTAssertEqual(
                frames.first?.frameID,
                // M163 — percent-escaped per syntheticRef convention.
                "render.sess%2Eclamp.turn%2E2",
                "newest turn survives after FIFO eviction")
        }
    }

    // MARK: - 5. Default cap is 4096

    func testDefaultCapacityIs4096() {
        XCTAssertEqual(
            QinaoSovereignControlPlane
                .defaultRenderFrameCapacity,
            4096)
    }

    // MARK: - 6. Cross-session FIFO respects global order

    func testCrossSessionFIFOOrderIsGlobal() async throws {
        let fx = await makeRuntime(cap: 4)
        // Interleave sessions A and B over 6 turns total.
        let sequence: [(String, Int)] = [
            ("sess.A", 0),
            ("sess.B", 0),
            ("sess.A", 1),
            ("sess.B", 1),
            ("sess.A", 2),
            ("sess.B", 2),
        ]
        for (sid, t) in sequence {
            let obs = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: sid,
                    turnID: "turn.\(t)",
                    snapshotRef: "s",
                    policyHash: "p")
            _ = try await fx.runtime.sendSession(
                obs, coordinatorSeverity: .pass)
        }
        // First two records (sess.A.turn.0, sess.B.turn.0) should
        // be evicted. Remaining 4 are the last 4 records.
        let totalCount = await fx.sovereign.renderFrameCount()
        XCTAssertEqual(totalCount, 4)
        let aFrames = await fx.sovereign.renderFrames(
            forSession: "sess.A")
        let bFrames = await fx.sovereign.renderFrames(
            forSession: "sess.B")
        // M163 — percent-escaped per syntheticRef convention.
        XCTAssertEqual(
            aFrames.map(\.frameID),
            [
                "render.sess%2EA.turn%2E1",
                "render.sess%2EA.turn%2E2",
            ])
        XCTAssertEqual(
            bFrames.map(\.frameID),
            [
                "render.sess%2EB.turn%2E1",
                "render.sess%2EB.turn%2E2",
            ])
    }
}
