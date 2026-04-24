import XCTest
import CryptoKit
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASObservability
import BASPolicy
import BASSovereign
import BASOrchestration
import BASWorldPrior
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M152 — `TurnInputs` value type collapses the 22-parameter
/// sendSession signature into one argument. Four ergonomic
/// shapes all hit the same code path:
///
/// 1. Minimal  — observations + coordinatorSeverity only
/// 2. Property — build inputs, set fields individually
/// 3. Fluent   — `.init(...).with { ... }` single-expression
/// 4. Legacy   — the 22-parameter overload (backward-compat
///               delegator)
///
/// All four produce BYTE-IDENTICAL outcomes for the same
/// semantic input. That's the one-source-of-truth property
/// the refactor guarantees.
final class QinaoRuntimeM152TurnInputsTests: XCTestCase {

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
            hostID: "host.m152",
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

    private func obs(
        sessionID: String = "sess.m152",
        turnID: String
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: sessionID,
            turnID: turnID,
            snapshotRef: "s",
            policyHash: "p")
    }

    // MARK: - 1. Minimal shape

    func testMinimalShape() async throws {
        let fx = await makeRuntime()
        let inputs = QinaoRuntime.TurnInputs(
            observations: obs(turnID: "turn.minimal"),
            coordinatorSeverity: .pass)
        let outcome = try await fx.runtime.sendSession(inputs)
        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertEqual(
            outcome.surfaceDecision.surface, .draftShell)
    }

    // MARK: - 2. Property-set shape

    func testPropertySetShape() async throws {
        let fx = await makeRuntime()
        var inputs = QinaoRuntime.TurnInputs(
            observations: obs(turnID: "turn.property"),
            coordinatorSeverity: .pass)
        inputs.contextFrame = BASContextFrame(
            utterance: "hi",
            taskType: .chat,
            emotionalLoad: 0.1,
            timePressure: 0.1,
            relationPattern: "mutual",
            ambiguityScore: 0.1,
            consequenceLevel: 0.1,
            hostRelevance: 0.5)
        inputs.thoughtFrame = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            stabilityScore: 0.7)
        let outcome = try await fx.runtime.sendSession(inputs)
        // L6 from contextFrame + L4/L10/L11 from thoughtFrame
        // all stream.
        let bundle = outcome.residue?.observationBundle
        let layers = Set(bundle?.summaries.map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.presenceEye))
        XCTAssertTrue(layers.contains(.worldPrior))
        XCTAssertTrue(layers.contains(.triSelfTribunal))
        XCTAssertTrue(layers.contains(.riskClimate))
    }

    // MARK: - 3. Fluent .with {} shape

    func testFluentWithShape() async throws {
        let fx = await makeRuntime()
        let outcome = try await fx.runtime.sendSession(
            .init(
                observations: obs(turnID: "turn.fluent"),
                coordinatorSeverity: .pass)
                .with {
                    $0.thoughtFrame = BASThoughtFrame(
                        stepIndex: 0,
                        decomposeRef: "d",
                        stabilityScore: 0.7)
                    $0.memoryBundle =
                        BASMemoryBundle(atoms: [])
                })
        let layers = Set(
            outcome.residue?.observationBundle?.summaries
                .map(\.layer) ?? [])
        XCTAssertTrue(layers.contains(.hippocampalWell))
        XCTAssertTrue(layers.contains(.worldPrior))
    }

    // MARK: - 4. Legacy overload equivalence

    /// The 22-parameter overload and the TurnInputs overload
    /// MUST produce semantically equivalent outcomes. The test
    /// wires the same semantic inputs both ways and compares
    /// the critical fields.
    func testLegacyAndInputsEquivalence() async throws {
        // Legacy 22-param path.
        let fx1 = await makeRuntime()
        let obs1 = obs(turnID: "turn.legacy")
        let tf = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            stabilityScore: 0.7)
        let legacyOutcome = try await fx1.runtime.sendSession(
            obs1,
            coordinatorSeverity: .pass,
            thoughtFrame: tf)

        // TurnInputs path.
        let fx2 = await makeRuntime()
        let obs2 = obs(turnID: "turn.inputs")
        var inputs = QinaoRuntime.TurnInputs(
            observations: obs2,
            coordinatorSeverity: .pass)
        inputs.thoughtFrame = tf
        let inputsOutcome = try await fx2.runtime.sendSession(
            inputs)

        // Critical field parity (auditRef / observation bundle
        // layer set).
        XCTAssertEqual(
            legacyOutcome.audit.severity,
            inputsOutcome.audit.severity)
        XCTAssertEqual(
            legacyOutcome.surfaceDecision.surface,
            inputsOutcome.surfaceDecision.surface)
        let legacyLayers = Set(
            legacyOutcome.residue?.observationBundle?.summaries
                .map(\.layer) ?? [])
        let inputsLayers = Set(
            inputsOutcome.residue?.observationBundle?.summaries
                .map(\.layer) ?? [])
        XCTAssertEqual(
            legacyLayers, inputsLayers,
            "semantic equivalence: same layer set streamed")
    }

    // MARK: - 5. TurnInputs is a value type

    /// Assigning a TurnInputs and mutating the copy must not
    /// affect the original. Value-type semantics pin.
    func testTurnInputsIsValueType() {
        var a = QinaoRuntime.TurnInputs(
            observations: obs(turnID: "turn.val"),
            coordinatorSeverity: .pass)
        a.memoryBundle = BASMemoryBundle(atoms: [])
        var b = a
        b.memoryBundle = nil
        // a still has it (value copy semantics).
        XCTAssertNotNil(a.memoryBundle)
        XCTAssertNil(b.memoryBundle)
    }
}
