import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M95 — `QinaoRuntime.sendSession` L1–L13 observation bundle
/// auto-streaming hook.
///
/// Pre-M95 state: `sendSession` called `recordTurnCoverage` without
/// forwarding any additional summaries, so the ledger's parallel
/// observation-bundle storage stayed empty for every turn. M90 had
/// already built the streaming machinery on the sovereign side, but
/// no caller in the main trunk ever used it.
///
/// M95 added one optional parameter to `sendSession`:
///
///     additionalCoverageSummaries: [BASObservationCoverageSummary]?
///         = nil
///
/// Nil (default) *used to* preserve the pre-M95 path byte-for-byte:
/// zero streamed bundles. Non-nil (even empty) triggered the streaming
/// branch — the per-turn observation bundle lands in the ledger's
/// parallel storage alongside the always-present L14 summary.
///
/// ## M122 update
///
/// M121 wired L1 (lease-life) auto-stream on `sendSession` when the
/// caller attaches a `QinaoLifecycle` + `plannedBudget`. M122 extended
/// the same choke-point to L3 (thought-fold) and L5 (host-
/// constitution), which auto-inject on *every* healthy turn — no
/// gating. Consequence: the "default nil produces an empty bundle"
/// pin no longer holds — the bundle always carries at least L14 + L3
/// + L5, plus L1 when a lifecycle is attached.
///
/// Covered contracts (post-M122):
///
/// 1. **Default path auto-streams L3+L5** — default nil still fires
///    the streaming branch because L3+L5 are auto-injected. (Formerly
///    pinned "no bundle", now pins "L14 + L3 + L5".)
/// 2. **Streaming path** — non-nil forwards and the bundle
///    round-trips via `observationBundle(sessionID:turnID:)`.
/// 3. **Empty-array path** — `[]` still triggers streaming; post-M122
///    the bundle carries L14 + auto L3 + auto L5 (= 3 summaries).
/// 4. **Halt path with streaming** — a coverage-halt throw still
///    streams the bundle (recordTurnCoverage runs before the halt
///    branch fires). Post-M122 the halt bundle includes L14 + caller
///    extras + auto L3 + auto L5.
/// 5. **Pre-halted session** — nothing streams because the pre-flight
///    gate refuses the turn before recordTurnCoverage runs.
final class QinaoRuntimeSendSessionStreamingTests: XCTestCase {

    // MARK: - Fixture (parallel to QinaoRuntimeCoverageTests)

    actor ToolRecorder {
        var callCount = 0
        func record(name: String, payload: Data) -> Data {
            callCount += 1
            return Data()
        }
    }

    struct Fixture: Sendable {
        let runtime: QinaoRuntime
        let sovereign: QinaoSovereignControlPlane
    }

    private func makeRuntime(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> Fixture {
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
            hostID: "host",
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
            host: host,
            memory: memory,
            risk: risk,
            sovereign: sovereign,
            loop: loop,
            toolExecutor: executor,
            now: now)

        return Fixture(runtime: runtime, sovereign: sovereign)
    }

    private func observations(
        sessionID: String = "sess.m95",
        turnID: String = "turn.1"
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "snap.1",
            policyHash: "policy.hash.1")
    }

    private func makeSummary(
        layer: BASCognitiveLayer,
        sessionID: String,
        turnID: String
    ) -> BASObservationCoverageSummary {
        BASObservationCoverageSummary(
            layer: layer,
            turnID: turnID,
            sessionID: sessionID,
            totalObservations: 3,
            distinctSubjectCount: 3,
            hasCoreSignalCoverage: true,
            budgetTotalCost: 0.2,
            emittedAt: Date(timeIntervalSince1970: 1_700_000_000))
    }

    // MARK: - 1. Default nil still auto-streams L3 + L5 (M122)

    /// Post-M122 contract: default nil still fires the streaming
    /// branch because L3 (thought-fold) + L5 (host-constitution)
    /// auto-inject on every healthy turn regardless of the caller
    /// passing `additionalCoverageSummaries:`. This supersedes the
    /// pre-M95 pin of "default → empty bundle".
    func testDefaultNilDoesNotStreamObservationBundle() async throws {
        let fx = await makeRuntime()
        let obs = observations()

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(
            bundle,
            "M122: L3+L5 auto-inject fires every turn")
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign, .thoughtFold, .hostConstitution],
            "L14 + auto L3 + auto L5 (no L1 — no lifecycle here)")
    }

    // MARK: - 2. Non-nil triggers streaming; bundle round-trips

    /// Passing three L1–L13 summaries produces a 4-summary bundle
    /// (L14 prepended by `recordTurnCoverage`, then caller order).
    func testStreamingThreeSummariesProducesFourLayerBundle()
        async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.m95.stream", turnID: "turn.1")
        let extras = [
            makeSummary(layer: .leaseLife,
                sessionID: obs.sessionID, turnID: obs.turnID),
            makeSummary(layer: .thoughtFold,
                sessionID: obs.sessionID, turnID: obs.turnID),
            makeSummary(layer: .hostConstitution,
                sessionID: obs.sessionID, turnID: obs.turnID),
        ]

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            expectedCoverageLayerIDs: [
                BASCognitiveLayer.sovereign.rawValue,
                BASCognitiveLayer.leaseLife.rawValue,
                BASCognitiveLayer.thoughtFold.rawValue,
                BASCognitiveLayer.hostConstitution.rawValue,
            ],
            additionalCoverageSummaries: extras)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle,
            "streaming path must land a bundle in the ledger")
        XCTAssertEqual(bundle?.summaries.count, 4,
            "L14 always prepended, then caller-supplied in order")
        XCTAssertEqual(
            bundle?.summaries.first?.layer,
            .sovereign,
            "L14 (sovereign) comes first")
        XCTAssertEqual(
            bundle?.summaries.dropFirst().map(\.layer),
            [.leaseLife, .thoughtFold, .hostConstitution],
            "caller-order preserved after L14")
    }

    // MARK: - 3. Empty array still triggers streaming

    /// Passing `[]` (non-nil but empty) fires the streaming branch.
    /// Post-M122 the bundle is L14 + auto L3 + auto L5 = 3 summaries
    /// (L1 stays absent without a lifecycle).
    func testEmptyArrayTriggersStreamingWithOnlyL14() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.m95.empty", turnID: "turn.1")

        _ = try await fx.runtime.sendSession(
            obs,
            coordinatorSeverity: .pass,
            additionalCoverageSummaries: [])

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle,
            "non-nil empty array still triggers streaming")
        XCTAssertEqual(bundle?.summaries.count, 3,
            "L14 + auto L3 + auto L5 = 3")
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign, .thoughtFold, .hostConstitution])
    }

    // MARK: - 4. Coverage-halt still streams the bundle

    /// A low-ceiling coverage-halt path still records the observation
    /// bundle because `recordTurnCoverage` fires before the halt
    /// throw. Audit replay must see the per-turn coverage even on
    /// halt.
    func testCoverageHaltStillStreamsBundle() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.m95.halt", turnID: "turn.1")
        let extras = [
            makeSummary(layer: .leaseLife,
                sessionID: obs.sessionID, turnID: obs.turnID),
        ]

        do {
            _ = try await fx.runtime.sendSession(
                obs,
                coordinatorSeverity: .pass,
                coverageBudgetCeiling: 0.05,
                additionalCoverageSummaries: extras)
            XCTFail("expected coverageHalt")
        } catch QinaoRuntime.TurnError.coverageHalt {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNotNil(bundle,
            "halt branch must still have streamed the bundle")
        // Post-M122: halt branch still carries caller extras AND
        // the auto-injected L3 + L5. Order = L14, caller extras
        // (first-seen positions), auto L3 (dedup with caller L3 if
        // any — none here), auto L5.
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign, .leaseLife, .thoughtFold, .hostConstitution])
    }

    // MARK: - 5. Pre-halted session streams nothing

    /// Pre-flight gate refuses the turn before recordTurnCoverage
    /// runs, so additional summaries never reach the ledger.
    func testPreHaltedSessionDoesNotStream() async throws {
        let fx = await makeRuntime()
        let obs = observations(
            sessionID: "sess.m95.prehalted", turnID: "turn.1")
        await fx.sovereign.markSessionHalted(
            sessionID: obs.sessionID,
            reason: "test-preset-halt")

        let extras = [
            makeSummary(layer: .leaseLife,
                sessionID: obs.sessionID, turnID: obs.turnID),
        ]

        do {
            _ = try await fx.runtime.sendSession(
                obs,
                coordinatorSeverity: .pass,
                additionalCoverageSummaries: extras)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNil(bundle,
            "pre-halted session must not write any bundle")
    }
}
