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
/// M95 adds one optional parameter to `sendSession`:
///
///     additionalCoverageSummaries: [BASObservationCoverageSummary]?
///         = nil
///
/// Nil (default) preserves the pre-M95 path byte-for-byte: zero
/// streamed bundles. Non-nil (even empty) triggers the streaming
/// branch — the per-turn observation bundle lands in the ledger's
/// parallel storage alongside the always-present L14 summary.
///
/// Covered contracts:
///
/// 1. **Backward compat** — default nil leaves `observationBundle`
///    lookup returning `nil` for the turn; pre-M95 byte-for-byte.
/// 2. **Streaming path** — non-nil forwards and the bundle
///    round-trips via `observationBundle(sessionID:turnID:)`.
/// 3. **Empty-array path** — `[]` still triggers streaming (nil vs
///    non-nil is the signal, not count).
/// 4. **Halt path with streaming** — a coverage-halt throw still
///    streams the bundle (recordTurnCoverage runs before the halt
///    branch fires).
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

    // MARK: - 1. Default nil preserves pre-M95 behavior

    /// Without `additionalCoverageSummaries:`, the ledger's
    /// observation-bundle storage stays empty for the turn —
    /// pre-M95 contract preserved byte-for-byte.
    func testDefaultNilDoesNotStreamObservationBundle() async throws {
        let fx = await makeRuntime()
        let obs = observations()

        _ = try await fx.runtime.sendSession(
            obs, coordinatorSeverity: .pass)

        let bundle = await fx.sovereign.observationBundle(
            sessionID: obs.sessionID, turnID: obs.turnID)
        XCTAssertNil(
            bundle,
            "pre-M95 default path must leave observationBundle empty")
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

    /// Passing `[]` (non-nil but empty) still fires the streaming
    /// branch — nil vs non-nil is the trigger, not count. The bundle
    /// carries exactly the L14 summary.
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
        XCTAssertEqual(bundle?.summaries.count, 1,
            "only L14 in the bundle when extras is empty")
        XCTAssertEqual(
            bundle?.summaries.first?.layer, .sovereign)
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
        XCTAssertEqual(
            bundle?.summaries.map(\.layer),
            [.sovereign, .leaseLife])
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
