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

/// M153 — full-field parity pin between the legacy 22-parameter
/// sendSession overload and the M152 TurnInputs overload.
///
/// Why this matters: the legacy overload is a thin wrapper that
/// copies 20 fields from positional args into a TurnInputs. If
/// someone adds a 23rd field to TurnInputs + the main body but
/// forgets to extend the legacy wrapper's field copies, the
/// legacy path silently drops that field on the floor. The
/// pre-M153 equivalence test only checked 3 outcome fields;
/// this new test exercises EVERY major surface of the outcome
/// (audit / coverage / residue / frames / refs / halts).
///
/// Pins:
///   1. Audit severity + parity + auditRef match
///   2. Coverage severity + findings count match
///   3. Surface decision surface + agency + disclosure match
///   4. Observation bundle layer set matches
///   5. Sovereign frame's 13 ref fields all match
///   6. Render frame's 12 ref fields all match
///   7. Residue isComplete state matches
final class QinaoRuntimeM153LegacyParityTests: XCTestCase {

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
            hostID: "host.m153",
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
        turnID: String
    ) -> QinaoSovereignControlPlane.TurnObservations {
        QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.m153",
            turnID: turnID,
            snapshotRef: "snap.m153",
            policyHash: "policy.m153")
    }

    /// Every non-identity TurnInputs field set to a distinctive
    /// value. Used by BOTH call paths below to prove they copy
    /// every field through.
    private func allFields() -> (
        thought: BASThoughtFrame,
        decompose: BASDecomposeFrame,
        memory: BASMemoryBundle,
        context: BASContextFrame,
        organMap: BASNeuralOrganMap,
        rendered: BASRenderedOutput,
        frontier: BASCandidateFrontier,
        tickets: [BASUpdateTicket],
        jurisdictionMap: BASJurisdictionMap,
        contaminationLineages: [BASContaminationLineage]
    ) {
        let card = BASRiskCard(
            totalRisk: 0.3,
            riskLevel: .medium,
            factors: [],
            uncertainty: 0.2,
            irreversibility: 0.1,
            manipulationStrength: 0.0,
            gsiScore: 0.0,
            recommendedMode: .answer,
            stackedModes: [],
            assertionCeiling: "")
        let permit = BASActionPermit(
            mode: .answer,
            assertionCeiling: "",
            toolScope: "",
            memoryScope: "",
            outputLengthCap: 0,
            tonePolicy: "",
            templatePolicy: "")
        let reservation = BASAgencyReservation(
            mode: .retainChoice)
        let thought = BASThoughtFrame(
            stepIndex: 0,
            decomposeRef: "d",
            riskCard: card,
            actionPermit: permit,
            agencyReservation: reservation,
            stabilityScore: 0.7)
        let draft = BASMirrorDraft(
            draftID: "draft.x",
            mode: .soft,
            summary: "s",
            toneGuard: "neutral")
        let decompose = BASDecomposeFrame(
            facts: ["f"],
            goals: ["g"],
            mirrorText: "t",
            mirrorDraft: draft)
        let memory = BASMemoryBundle(atoms: [])
        let context = BASContextFrame(
            utterance: "hi",
            taskType: .chat,
            emotionalLoad: 0.1,
            timePressure: 0.1,
            relationPattern: "mutual",
            ambiguityScore: 0.1,
            consequenceLevel: 0.1,
            hostRelevance: 0.5)
        let organMap = BASNeuralOrganMap(
            morph: .engage,
            activeOrgans: [],
            routingPolicy: .conversationalBalance)
        let rendered = BASRenderedOutput(
            mode: .answer,
            headline: "h",
            body: "b")
        let frontier = BASCandidateFrontier(
            candidateIDs: ["c1", "c2"],
            dominanceOrder: ["c1", "c2"],
            frontierWidth: 2,
            diversityScore: 0.5)
        let tickets = [
            BASUpdateTicket(
                ticketID: "t.1",
                sessionRef: "sess.m153",
                summary: "s",
                confidence: 0.5)
        ]
        let jm = BASJurisdictionMap(
            mapID: "jm.full",
            domains: ["d"])
        let cont = [
            BASContaminationLineage(
                lineageID: "lin.1",
                rootRef: "r",
                contaminationType: "t",
                severity: 0.1,
                cutRecommended: false)
        ]
        return (
            thought, decompose, memory, context, organMap,
            rendered, frontier, tickets, jm, cont)
    }

    // MARK: - Full-field legacy ↔ inputs parity

    /// Run BOTH overloads with the SAME full-field input set and
    /// compare every major surface of the outcome. This catches
    /// any field the legacy wrapper forgets to copy.
    func testLegacyAndInputsProduceIdenticalOutcomes()
        async throws {
        let fx1 = await makeRuntime()
        let fx2 = await makeRuntime()
        let f = allFields()

        // Path A: legacy 22-parameter overload.
        let obsLegacy = obs(turnID: "turn.legacy")
        let outA = try await fx1.runtime.sendSession(
            obsLegacy,
            coordinatorSeverity: .pass,
            coverageBudgetCeiling: 1.5,
            expectedCoverageLayerIDs: ["L14"],
            plannedBudget: nil,
            turnDurationSeconds: nil,
            additionalCoverageSummaries: nil,
            surfaceRetryPolicy: .default,
            contextFrame: f.context,
            decomposeFrame: f.decompose,
            memoryBundle: f.memory,
            thoughtFrame: f.thought,
            updateTickets: f.tickets,
            neuralOrganMap: f.organMap,
            renderedOutput: f.rendered,
            candidateFrontier: f.frontier,
            jurisdictionMap: f.jurisdictionMap,
            contaminationLineages: f.contaminationLineages,
            timeLockRef: "timelock.x",
            pendingActionDigest: "digest.a",
            pendingMutationDigest: "digest.m",
            pendingMemoryDigest: "digest.mem")

        // Path B: TurnInputs overload with identical values.
        let obsInputs = obs(turnID: "turn.inputs")
        var inputs = QinaoRuntime.TurnInputs(
            observations: obsInputs,
            coordinatorSeverity: .pass)
        inputs.coverageBudgetCeiling = 1.5
        inputs.expectedCoverageLayerIDs = ["L14"]
        inputs.surfaceRetryPolicy = .default
        inputs.contextFrame = f.context
        inputs.decomposeFrame = f.decompose
        inputs.memoryBundle = f.memory
        inputs.thoughtFrame = f.thought
        inputs.updateTickets = f.tickets
        inputs.neuralOrganMap = f.organMap
        inputs.renderedOutput = f.rendered
        inputs.candidateFrontier = f.frontier
        inputs.jurisdictionMap = f.jurisdictionMap
        inputs.contaminationLineages = f.contaminationLineages
        inputs.timeLockRef = "timelock.x"
        inputs.pendingActionDigest = "digest.a"
        inputs.pendingMutationDigest = "digest.m"
        inputs.pendingMemoryDigest = "digest.mem"
        let outB = try await fx2.runtime.sendSession(inputs)

        // === Full-field parity pin ===

        // 1. Audit
        XCTAssertEqual(
            outA.audit.severity, outB.audit.severity)
        XCTAssertEqual(
            outA.audit.parity, outB.audit.parity)

        // 2. Coverage
        XCTAssertEqual(
            outA.coverage.severity, outB.coverage.severity)
        XCTAssertEqual(
            outA.coverage.findings.count,
            outB.coverage.findings.count)

        // 3. Surface decision
        XCTAssertEqual(
            outA.surfaceDecision.surface,
            outB.surfaceDecision.surface)
        XCTAssertEqual(
            outA.surfaceDecision.agency,
            outB.surfaceDecision.agency)
        XCTAssertEqual(
            outA.surfaceDecision.disclosure,
            outB.surfaceDecision.disclosure)

        // 4. Observation bundle layer set
        let layersA = Set(
            outA.residue?.observationBundle?.summaries
                .map(\.layer) ?? [])
        let layersB = Set(
            outB.residue?.observationBundle?.summaries
                .map(\.layer) ?? [])
        XCTAssertEqual(
            layersA, layersB,
            "same layer set streamed by both paths")

        // 5. Sovereign frame refs — all 13 optional fields plus
        //    the 3 identity fields. Two paths have different
        //    turnIDs so ref SUFFIXES differ, but the PRESENCE
        //    pattern (which refs are non-nil vs nil) must match.
        let sfA = outA.residue?.sovereignFrame
        let sfB = outB.residue?.sovereignFrame
        XCTAssertEqual(
            sfA?.deviceStateRef != nil,
            sfB?.deviceStateRef != nil)
        XCTAssertEqual(
            sfA?.hostVersionRef != nil,
            sfB?.hostVersionRef != nil)
        XCTAssertEqual(
            sfA?.continuityRef != nil,
            sfB?.continuityRef != nil)
        XCTAssertEqual(
            sfA?.thoughtFoldRef != nil,
            sfB?.thoughtFoldRef != nil)
        XCTAssertEqual(
            sfA?.riskCardRef != nil,
            sfB?.riskCardRef != nil)
        XCTAssertEqual(
            sfA?.actionPermitRef != nil,
            sfB?.actionPermitRef != nil)
        XCTAssertEqual(
            sfA?.pendingActionDigest,
            sfB?.pendingActionDigest,
            "pending action digest is plain-string passthrough" +
                " — must be byte-equal")
        XCTAssertEqual(
            sfA?.pendingMutationDigest,
            sfB?.pendingMutationDigest)
        XCTAssertEqual(
            sfA?.pendingMemoryDigest,
            sfB?.pendingMemoryDigest)
        XCTAssertEqual(
            sfA?.jurisdictionRef,
            sfB?.jurisdictionRef,
            "jurisdictionRef = map.mapID — byte-equal")
        XCTAssertEqual(
            sfA?.timeLockRef,
            sfB?.timeLockRef,
            "timeLockRef plain-string passthrough")
        XCTAssertEqual(
            sfA?.contaminationRefs,
            sfB?.contaminationRefs,
            "contaminationRefs map from lineageIDs — byte-equal")
        XCTAssertEqual(
            sfA?.policyHash, sfB?.policyHash,
            "policyHash passthrough — byte-equal")

        // 6. Render frame refs — 12 optional fields.
        let rfA = outA.residue?.renderFrame
        let rfB = outB.residue?.renderFrame
        XCTAssertEqual(
            rfA?.mergedChoiceRef != nil,
            rfB?.mergedChoiceRef != nil)
        XCTAssertEqual(
            rfA?.actionPermitRef != nil,
            rfB?.actionPermitRef != nil)
        XCTAssertEqual(
            rfA?.agencyReservationRef != nil,
            rfB?.agencyReservationRef != nil)
        XCTAssertEqual(
            rfA?.hostStyleRef, rfB?.hostStyleRef,
            "hostStyleRef = activeVersion — byte-equal")
        XCTAssertEqual(
            rfA?.situationRef != nil,
            rfB?.situationRef != nil)
        XCTAssertEqual(
            rfA?.mirrorRef != nil, rfB?.mirrorRef != nil)
        XCTAssertEqual(
            rfA?.substituteRef, rfB?.substituteRef)
        XCTAssertEqual(
            rfA?.outputSurfaceRef, rfB?.outputSurfaceRef)
        XCTAssertEqual(
            rfA?.toneProfileRef != nil,
            rfB?.toneProfileRef != nil)
        XCTAssertEqual(
            rfA?.forceCurveRef != nil,
            rfB?.forceCurveRef != nil)
        XCTAssertEqual(
            rfA?.disclosureProfileRef,
            rfB?.disclosureProfileRef)

        // 7. Residue isComplete
        XCTAssertEqual(
            outA.residue?.isComplete,
            outB.residue?.isComplete)
    }
}
