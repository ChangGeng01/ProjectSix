import XCTest
import CryptoKit
import BASRuntimeCore
import BASPolicy
import BASMemory
import BASSovereign
import BASOrchestration
import BASObservability
import BASHostKit
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign
@testable import QinaoLoop

/// M82 — `QinaoRuntime.QinaoTurnArtifacts` + projection helper +
/// `sendSession(artifacts:)` main-trunk wiring.
///
/// These tests prove that a completed substrate turn can be projected
/// into a Qinao-safe mirror and fed into the sovereign audit path
/// with no hand-unpacking — which closes the final 1% of
/// invariant #2 (「神经不直接掌权」) and property #4
/// (「会保护不接管」). The file covers three layers in order:
///
///   1. **Mirror type identity**: `QinaoTurnArtifacts.turnObservations`
///      produces a `TurnObservations` byte-for-byte identical to a
///      hand-rolled one with the same 22 fields. The mirror is not a
///      compaction; it's a relabeling that hides substrate type
///      names from the public API surface.
///
///   2. **Projection correctness**: every bypass signal in the
///      projection table maps substrate state honestly. A clean
///      turn projects to clean artifacts; a turn that staged a
///      side effect without the matching sovereign signature
///      projects to a flagged artifact that the audit engine's
///      BR-006..BR-009 rules will convert to a fail-closed verdict.
///
///   3. **End-to-end integration**: `sendSession(artifacts:)`
///      delegates to the primitive `sendSession(_ observations:)`
///      without changing behavior — clean turn passes, laxer parity
///      halts, pre-halted session refuses, same as the M15
///      primitive-path tests.
///
/// The tests also verify the `SessionMode` / `BrakeLevel` bridge
/// helpers are exhaustive — every substrate case has a Qinao mirror
/// case, no crashing default path. That exhaustiveness is what lets
/// M82 claim "projection cannot fail" as a type-level property,
/// not just a behavioral one.
final class QinaoTurnArtifactsBridgeTests: XCTestCase {

    // MARK: - Shared fixture

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
        let engine = BASSovereignVerdictEngine(ledger: ledger, now: now)
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

    // MARK: - BASEBrainTurnResult builder
    //
    // `cleanTurnResult()` returns a completed-turn record with:
    //
    //   - no sovereign actuation commands
    //   - no sovereign commit tokens
    //   - no sovereign warrants
    //   - no version deltas
    //   - no update tickets
    //   - no experience candidates
    //   - no quarantine records
    //   - no host-forget request
    //   - sovereignAuditEntry = nil
    //   - policyLineage = nil
    //
    // With those defaults the projection must produce:
    //
    //   - every bypass bool = false (nothing was staged without a
    //     signature)
    //   - policyLineageMissing = true
    //   - auditEntryMissing = true
    //   - quarantineCount = 0
    //
    // Specific tests then mutate the record to drive a single
    // bypass signal to `true` and assert the projection flips
    // exactly that signal.

    private func cleanTurnResult(
        overrides: (inout BASEBrainTurnResult) -> Void = { _ in }
    ) -> BASEBrainTurnResult {
        let deviceState = BASDeviceState(
            batteryLevel: 0.72,
            thermalLevel: .nominal,
            memoryFreeMB: 2_048,
            networkState: .online,
            foregroundState: .foreground,
            cpuLoad: 0.21,
            gpuLoad: 0.10,
            npuAvailable: true,
            latencyBudgetMs: 1_200
        )
        let budgetFrame = BASBudgetFrame.guardedLocal(
            maxLoops: 2,
            maxCandidates: 2,
            maxDecodeTokens: 160,
            retrievalDepth: 2
        )
        let hostContext = BASHostProfile(
            hostID: "host.primary",
            longTermGoals: ["Stay calm"],
            noGoZones: ["unsafe"]
        )
        let contextFrame = BASContextFrame(
            utterance: "Mirror body",
            taskType: .highPressure,
            emotionalLoad: 0.42,
            timePressure: 0.24,
            relationPattern: "self",
            ambiguityScore: 0.31,
            consequenceLevel: 0.28,
            manipulationHints: [],
            hostRelevance: 0.88
        )
        let decomposeFrame = BASDecomposeFrame(
            facts: ["Ambient"],
            goals: ["Stay steady"],
            emotions: [],
            unknowns: [],
            contradictions: [],
            pressureSignals: [],
            manipulationSignals: [],
            mirrorText: "Mirror body"
        )
        let memoryAtom = BASMemoryAtom(
            memoryID: "mem-clean",
            summary: "Clean warm memory.",
            contentType: .warm,
            source: "session",
            confidence: 0.82,
            conflictFingerprint: "fp-clean"
        )
        let memoryBundle = BASMemoryBundle(
            atoms: [memoryAtom],
            retrievalTags: ["clean"],
            conflictRefs: [],
            activeHostVersion: hostContext.activeVersion
        )
        let candidate = BASCandidatePath(
            candidateID: "cand-clean",
            title: "Answer plainly",
            actionSummary: "Direct, unblocked response.",
            requiredEvidence: [],
            expectedBenefit: 0.6,
            expectedCost: 0.1,
            reversibility: 0.95,
            confidence: 0.88
        )
        let forecast = BASForecastItem(
            candidateID: candidate.candidateID,
            shortTermOutcome: "Clear response",
            midTermOutcome: "Continued steady session",
            worstCase: "Minor phrasing miss",
            uncertainty: 0.1,
            affectedRelations: []
        )
        let critique = BASCritiqueItem(
            candidateID: candidate.candidateID,
            critiqueType: .boundaryConflict,
            critiqueText: "No conflict detected.",
            severity: 0.05
        )
        let triScore = BASTriSelfScore(
            candidateID: candidate.candidateID,
            idScore: 0.62,
            egoScore: 0.74,
            superegoScore: 0.69,
            mergedScore: 0.72,
            veto: false
        )
        let mergedChoice = BASMergedChoice(
            candidateID: candidate.candidateID,
            title: "Answer plainly",
            actionSummary: "Direct response."
        )
        let riskCard = BASRiskCard(
            totalRisk: 0.12,
            riskLevel: .low,
            factors: [],
            uncertainty: 0.08,
            irreversibility: 0.05,
            manipulationStrength: 0.03,
            gsiScore: 0.09,
            recommendedMode: .answer
        )
        let actionPermit = BASActionPermit(
            mode: .answer,
            reasonCodes: [],
            requireSecondCheck: false,
            outputLengthCap: 400,
            tonePolicy: "grounded_clear",
            templatePolicy: "default"
        )
        let thoughtFrame = BASThoughtFrame(
            stepIndex: 1,
            decomposeRef: "decomp-clean",
            memoryRefs: [memoryAtom.memoryID],
            candidates: [candidate],
            forecasts: [forecast],
            critiques: [critique],
            triScores: [triScore],
            riskCard: riskCard,
            actionPermit: actionPermit,
            stabilityScore: 0.94,
            stopReason: .candidateStable
        )
        let thoughtFold = BASThoughtFold(
            foldID: "fold-clean",
            compactSlots: ["headline": "Answer plainly"],
            candidateSignatures: [candidate.candidateID],
            riskSnapshot: riskCard,
            hostEffectSummary: "No host constitution change.",
            restorePointer: "restore-clean",
            checksum: "checksum-clean"
        )
        let runtimeTrace = BASRuntimeTrace(
            sessionID: "session-clean",
            layerEvents: [
                BASRuntimeTraceEvent(
                    layerID: "L2",
                    event: "neural_core",
                    detail: "Clean turn."
                )
            ],
            latencyBreakdownMs: ["L2": 2],
            powerEstimate: 0.06,
            thermalTrace: ["cool"],
            modelRoute: "default",
            loopCount: 1,
            cacheHitRate: 0,
            activeKillSwitches: [],
            guardrailFindings: [],
            recommendedKillSwitches: []
        )
        var turn = BASEBrainTurnResult(
            deviceState: deviceState,
            budgetFrame: budgetFrame,
            wakeIntent: BASWakeIntent(
                intentLevel: .engage,
                estimatedValue: 0.62,
                estimatedRisk: 0.18,
                estimatedCost: 0.12,
                preferredMode: budgetFrame.runMode
            ),
            vitalState: BASVitalState(
                wakeState: budgetFrame.runMode,
                survivalMargin: 0.88,
                thermalMargin: 0.92,
                powerMargin: 0.91,
                continuityScore: 0.89,
                stabilityScore: 0.94
            ),
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: [triScore],
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            hostGateValue: 0.84,
            renderedOutput: BASRenderedOutput(
                mode: .answer,
                headline: "Answer plainly",
                body: "Mirror body",
                alternativeActions: [],
                explanationCodes: []
            ),
            updateTickets: [],
            runtimeTrace: runtimeTrace
        )
        overrides(&turn)
        return turn
    }

    /// Produce a turn whose `policyLineage` and `sovereignAuditEntry`
    /// are both populated — mirrors a turn that has successfully
    /// written both records through the substrate's lineage writer
    /// and audit ledger. The end-to-end `sendSession(artifacts:)`
    /// tests need this because the projection faithfully reports nil
    /// fields as "missing" and the audit engine treats both-missing
    /// as a BR-004 deadStop violation.
    ///
    /// Kept separate from `cleanTurnResult` so the baseline projection
    /// test can still exercise the "missing flags propagate through
    /// projection" invariant.
    private func sealedTurnResult(
        overrides: (inout BASEBrainTurnResult) -> Void = { _ in }
    ) -> BASEBrainTurnResult {
        return cleanTurnResult { turn in
            turn.policyLineage = BASRuntimePolicyLineage(
                bundleVersion: "bundle.bridge.1",
                providerRoutingRegistryVersion: "pr-registry.1",
                providerRoutingPolicyID: "pr-policy.1",
                runtimeTuningRegistryVersion: "rt-registry.1",
                runtimeTuningPolicyID: "rt-policy.1",
                resolutionSourceID: "src.bridge.1")
            turn.sovereignAuditEntry = BASSovereignAuditEntry(
                auditID: "audit.bridge.1",
                sessionID: "sess.bridge.sealed",
                turnID: "turn.bridge.sealed",
                verdictRef: "verdict.bridge.1",
                snapshotRef: "snap.bridge.1",
                signature: "sig.bridge.1",
                appendedAt: Date(timeIntervalSince1970: 1_700_000_000))
            overrides(&turn)
        }
    }

    // Helpers that build the auxiliary objects a bypass-signal test
    // layers onto the clean turn.

    private func makeCommitToken(
        id: String = "token.bridge",
        scope: BASSovereignCommitScope = .toolWrite
    ) -> BASSovereignCommitToken {
        BASSovereignCommitToken(
            tokenID: id,
            sessionID: "session-clean",
            turnID: "turn-clean",
            scope: scope,
            allowedTargets: ["target-clean"],
            actionDigest: "digest-\(id)",
            snapshotRef: "snap.bridge",
            policyHash: "policy.bridge",
            ttlMs: 10_000,
            nonce: "nonce-\(id)",
            singleUse: true,
            signature: "signature-\(id)"
        )
    }

    private func makeWarrant(
        id: String = "warrant.bridge",
        scope: BASSovereignCommitScope = .hostMutate
    ) -> BASSovereignWarrant {
        BASSovereignWarrant(
            warrantID: id,
            scope: scope,
            actionDigest: "digest-\(id)",
            commitTokenRef: "token-ref-\(id)",
            jurisdictionRef: "jur.\(id)",
            snapshotRef: "snap.\(id)",
            timeLockRef: "timelock.\(id)",
            policyHash: "policy.\(id)",
            witnessRefs: ["witness.\(id)"],
            singleUse: true,
            signature: "sig.\(id)"
        )
    }

    private func makeActuationCommand(
        id: String = "actuation.bridge"
    ) -> BASSovereignActuationCommand {
        BASSovereignActuationCommand(
            commandID: id,
            kind: .toolCut,
            reasonCodes: ["bridge.test"],
            issuedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeVersionDelta(
        id: String = "delta.bridge"
    ) -> BASVersionDelta {
        BASVersionDelta(
            deltaID: id,
            targetType: "host",
            beforeRef: "host.v1",
            afterRef: "host.v2",
            reason: "bridge test",
            impactScope: "host.primary",
            rollbackRef: "rollback.bridge"
        )
    }

    private func makeUpdateTicket(
        id: String = "ticket.bridge"
    ) -> BASUpdateTicket {
        BASUpdateTicket(
            ticketID: id,
            sessionRef: "session-clean",
            summary: "Bridge test ticket.",
            memoryWriteSuggestion: "Add warm memory.",
            hostProfileChangeSuggestion: nil,
            ruleCandidateRef: nil,
            confidence: 0.8,
            conflictFlag: false,
            requiresReview: true
        )
    }

    private func makeExperienceCandidate(
        id: String = "experience.bridge"
    ) -> BASExperienceCandidate {
        BASExperienceCandidate(
            candidateID: id,
            sourceRefs: ["ticket.\(id)"],
            candidateType: .guardPattern,
            summary: "Bridge test experience candidate.",
            stabilitySignal: 0.7,
            contaminationRisk: 0.1,
            hostScope: "host.primary",
            sovereignScope: "scope.test"
        )
    }

    private func makeForgetRequest(
        id: String = "forget.bridge"
    ) -> BASForgetRequest {
        BASForgetRequest(
            requestID: id,
            targetRefs: ["mem-clean"],
            cascadeScope: ["session"],
            executedSteps: [],
            verified: false
        )
    }

    // MARK: - Mirror round-trip

    /// The mirror is not a compaction — `turnObservations` must
    /// produce a `TurnObservations` byte-for-byte identical to one
    /// hand-built with the same 22 values. If this breaks, the
    /// `sendSession(artifacts:)` overload delegates wrong fields and
    /// every downstream audit test becomes meaningless.
    func testArtifactsTurnObservationsRoundTripByteEqual() {
        let artifacts = QinaoRuntime.QinaoTurnArtifacts(
            sessionID: "sess.roundtrip",
            turnID: "turn.roundtrip",
            snapshotRef: "snap.roundtrip",
            policyHash: "policy.roundtrip",
            policyLineageMissing: true,
            auditEntryMissing: true,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: true,
            externalSideEffectWithoutSCT: true,
            hostRemovalBypassed: true,
            unauthorizedSelfMutation: true,
            memoryOrHostWriteBypass: true,
            irreversibilityScore: 0.33,
            manipulationStrength: 0.55,
            uncertaintyScore: 0.66,
            gsiScore: 0.88,
            hostGateValue: 0.44,
            quarantineCount: 3,
            mode: .deepLoop,
            brake: .caution,
            operation: .hostMutate,
            evidenceSufficient: false)

        let handRolled = QinaoSovereignControlPlane.TurnObservations(
            sessionID: "sess.roundtrip",
            turnID: "turn.roundtrip",
            snapshotRef: "snap.roundtrip",
            policyHash: "policy.roundtrip",
            policyLineageMissing: true,
            auditEntryMissing: true,
            runtimeUnstableInHighRisk: true,
            riskPermitHeadConflict: true,
            externalSideEffectWithoutSCT: true,
            hostRemovalBypassed: true,
            unauthorizedSelfMutation: true,
            memoryOrHostWriteBypass: true,
            irreversibilityScore: 0.33,
            manipulationStrength: 0.55,
            uncertaintyScore: 0.66,
            gsiScore: 0.88,
            hostGateValue: 0.44,
            quarantineCount: 3,
            mode: .deepLoop,
            brake: .caution,
            operation: .hostMutate,
            evidenceSufficient: false)

        XCTAssertEqual(artifacts.turnObservations, handRolled)
    }

    /// The mirror init clamps doubles to [0, 1] and counts to [0, ∞).
    /// A host that passes a malformed score must get a safe default,
    /// not a hostile one. We check one above, one below, and the
    /// count floor.
    func testArtifactsInitClampsOutOfRangeInputs() {
        let clamped = QinaoRuntime.QinaoTurnArtifacts(
            sessionID: "sess.clamp",
            turnID: "turn.clamp",
            snapshotRef: "snap.clamp",
            policyHash: "policy.clamp",
            irreversibilityScore: 1.75,
            manipulationStrength: -0.5,
            gsiScore: 2.0,
            hostGateValue: -0.25,
            quarantineCount: -4)

        XCTAssertEqual(clamped.irreversibilityScore, 1.0)
        XCTAssertEqual(clamped.manipulationStrength, 0.0)
        XCTAssertEqual(clamped.gsiScore, 1.0)
        XCTAssertEqual(clamped.hostGateValue, 0.0)
        XCTAssertEqual(clamped.quarantineCount, 0)
    }

    /// Codable preservation — the mirror must survive a JSON round
    /// trip so it can be logged, journaled, or transmitted across
    /// process boundaries without losing signal fidelity.
    func testArtifactsCodableRoundTrip() throws {
        let original = QinaoRuntime.QinaoTurnArtifacts(
            sessionID: "sess.codable",
            turnID: "turn.codable",
            snapshotRef: "snap.codable",
            policyHash: "policy.codable",
            runtimeUnstableInHighRisk: true,
            externalSideEffectWithoutSCT: true,
            irreversibilityScore: 0.42,
            gsiScore: 0.58,
            quarantineCount: 2,
            mode: .quarantine,
            brake: .quarantine,
            operation: .memoryPromote,
            evidenceSufficient: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(
            QinaoRuntime.QinaoTurnArtifacts.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Projection: clean baseline

    /// A default clean turn projects to all-clean artifacts except
    /// the two "missing" flags that reflect the absence of the
    /// optional `policyLineage` and `sovereignAuditEntry` fields.
    /// This is the fixed point of the projection — if a bypass flag
    /// creeps into true here, the projection is lying about a clean
    /// turn.
    func testProjectionCleanTurnProducesCleanArtifacts() {
        let turn = cleanTurnResult()
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.clean",
            turnID: "turn.clean",
            snapshotRef: "snap.clean",
            policyHash: "policy.clean")

        XCTAssertEqual(artifacts.sessionID, "sess.clean")
        XCTAssertEqual(artifacts.turnID, "turn.clean")
        XCTAssertEqual(artifacts.snapshotRef, "snap.clean")
        XCTAssertEqual(artifacts.policyHash, "policy.clean")

        XCTAssertFalse(artifacts.externalSideEffectWithoutSCT)
        XCTAssertFalse(artifacts.unauthorizedSelfMutation)
        XCTAssertFalse(artifacts.memoryOrHostWriteBypass)
        XCTAssertFalse(artifacts.hostRemovalBypassed)
        XCTAssertFalse(artifacts.runtimeUnstableInHighRisk)
        XCTAssertFalse(artifacts.riskPermitHeadConflict)

        // policyLineage / sovereignAuditEntry are nil on the clean
        // fixture, so both missing flags must be true. This is the
        // "honesty" term — a clean turn that forgot to write its
        // policy lineage and audit entry is still "missing" those
        // records, and the projection must say so.
        XCTAssertTrue(artifacts.policyLineageMissing)
        XCTAssertTrue(artifacts.auditEntryMissing)

        XCTAssertEqual(artifacts.quarantineCount, 0)
        XCTAssertEqual(
            artifacts.mode,
            QinaoSovereignControlPlane.SessionMode.guard)
        XCTAssertEqual(artifacts.brake, .none)
        XCTAssertEqual(artifacts.operation, .pureInference)
        XCTAssertTrue(artifacts.evidenceSufficient)
    }

    // MARK: - Projection: bypass signals

    /// External side-effect without sovereign commit token:
    /// actuation staged but no SCT to sign it. BR-006 level.
    func testProjectionFlagsExternalSideEffectWithoutSCT() {
        let turn = cleanTurnResult { turn in
            turn.sovereignActuationCommands = [self.makeActuationCommand()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.bypass",
            turnID: "turn.bypass",
            snapshotRef: "snap.bypass",
            policyHash: "policy.bypass")

        XCTAssertTrue(artifacts.externalSideEffectWithoutSCT)
        // Other bypass signals stay clean — only the targeted one
        // trips. This isolates the substrate→flag path so a
        // regression can't mask itself by tripping multiple flags.
        XCTAssertFalse(artifacts.unauthorizedSelfMutation)
        XCTAssertFalse(artifacts.memoryOrHostWriteBypass)
        XCTAssertFalse(artifacts.hostRemovalBypassed)
    }

    /// Actuation + commit token together → signal clears.
    /// This is the inverse of the prior test; a signed actuation is
    /// not a bypass. The projection must recognize the commit token
    /// signature.
    func testProjectionClearsSideEffectFlagWhenCommitTokenPresent() {
        let turn = cleanTurnResult { turn in
            turn.sovereignActuationCommands = [self.makeActuationCommand()]
            turn.sovereignCommitTokens = [self.makeCommitToken()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.signed",
            turnID: "turn.signed",
            snapshotRef: "snap.signed",
            policyHash: "policy.signed")

        XCTAssertFalse(artifacts.externalSideEffectWithoutSCT)
    }

    /// Unauthorized self-mutation: version delta staged without a
    /// warrant signing it. BR-007 level.
    func testProjectionFlagsUnauthorizedSelfMutation() {
        let turn = cleanTurnResult { turn in
            turn.versionDeltas = [self.makeVersionDelta()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.selfmut",
            turnID: "turn.selfmut",
            snapshotRef: "snap.selfmut",
            policyHash: "policy.selfmut")

        XCTAssertTrue(artifacts.unauthorizedSelfMutation)
        XCTAssertFalse(artifacts.externalSideEffectWithoutSCT)
        XCTAssertFalse(artifacts.memoryOrHostWriteBypass)
        XCTAssertFalse(artifacts.hostRemovalBypassed)
    }

    /// Version delta + warrant together → signal clears.
    func testProjectionClearsSelfMutationFlagWhenWarrantPresent() {
        let turn = cleanTurnResult { turn in
            turn.versionDeltas = [self.makeVersionDelta()]
            turn.sovereignWarrants = [self.makeWarrant()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.signedmut",
            turnID: "turn.signedmut",
            snapshotRef: "snap.signedmut",
            policyHash: "policy.signedmut")

        XCTAssertFalse(artifacts.unauthorizedSelfMutation)
    }

    /// Memory/host write bypass via update ticket: ticket staged
    /// without a commit token. BR-008 level.
    func testProjectionFlagsWriteBypassViaUpdateTicket() {
        let turn = cleanTurnResult { turn in
            turn.updateTickets = [self.makeUpdateTicket()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.ticket",
            turnID: "turn.ticket",
            snapshotRef: "snap.ticket",
            policyHash: "policy.ticket")

        XCTAssertTrue(artifacts.memoryOrHostWriteBypass)
        XCTAssertFalse(artifacts.externalSideEffectWithoutSCT)
        XCTAssertFalse(artifacts.unauthorizedSelfMutation)
        XCTAssertFalse(artifacts.hostRemovalBypassed)
    }

    /// Memory/host write bypass via experience candidate: alternate
    /// branch of the OR — experience candidate staged without a
    /// commit token. Covers the second half of BR-008's
    /// (tickets OR experienceCandidates) condition.
    func testProjectionFlagsWriteBypassViaExperienceCandidate() {
        let turn = cleanTurnResult { turn in
            turn.experienceCandidates = [self.makeExperienceCandidate()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.exp",
            turnID: "turn.exp",
            snapshotRef: "snap.exp",
            policyHash: "policy.exp")

        XCTAssertTrue(artifacts.memoryOrHostWriteBypass)
    }

    /// Host removal bypass: forget request staged without a warrant
    /// signing it. BR-005 level (host deletion must have sovereign
    /// authority).
    func testProjectionFlagsHostRemovalBypassed() {
        let turn = cleanTurnResult { turn in
            turn.hostForgetRequest = self.makeForgetRequest()
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.forget",
            turnID: "turn.forget",
            snapshotRef: "snap.forget",
            policyHash: "policy.forget")

        XCTAssertTrue(artifacts.hostRemovalBypassed)
        XCTAssertFalse(artifacts.externalSideEffectWithoutSCT)
        XCTAssertFalse(artifacts.unauthorizedSelfMutation)
        XCTAssertFalse(artifacts.memoryOrHostWriteBypass)
    }

    // MARK: - Projection: scalar pass-through

    /// Risk-card scores and the host-gate value are direct copies.
    /// A test that passes a non-default value must see it byte-equal
    /// on the artifact. If the projection accidentally rounded /
    /// bucketed / remapped a score, the audit engine would see a
    /// different risk picture than the substrate did.
    func testProjectionPassesScalarsThrough() {
        let turn = cleanTurnResult { turn in
            turn.riskCard = BASRiskCard(
                totalRisk: 0.77,
                riskLevel: .high,
                factors: ["bridge.test"],
                uncertainty: 0.34,
                irreversibility: 0.61,
                manipulationStrength: 0.47,
                gsiScore: 0.83,
                recommendedMode: .delay)
            turn.hostGateValue = 0.29
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.scalars",
            turnID: "turn.scalars",
            snapshotRef: "snap.scalars",
            policyHash: "policy.scalars")

        XCTAssertEqual(artifacts.irreversibilityScore, 0.61)
        XCTAssertEqual(artifacts.manipulationStrength, 0.47)
        XCTAssertEqual(artifacts.gsiScore, 0.83)
        XCTAssertEqual(artifacts.hostGateValue, 0.29)
    }

    /// Quarantine record count: direct count pass-through.
    func testProjectionCountsQuarantineRecords() {
        let turn = cleanTurnResult { turn in
            turn.quarantineRecords = [
                BASQuarantineRecord(
                    quarantineID: "q-1",
                    zone: .session,
                    sourceRef: "session-clean",
                    reasonCodes: [],
                    isolatedAt: Date(),
                    releasePolicy: "manual",
                    reviewState: .held),
                BASQuarantineRecord(
                    quarantineID: "q-2",
                    zone: .memory,
                    sourceRef: "mem-clean",
                    reasonCodes: [],
                    isolatedAt: Date(),
                    releasePolicy: "manual",
                    reviewState: .held)
            ]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.q",
            turnID: "turn.q",
            snapshotRef: "snap.q",
            policyHash: "policy.q")

        XCTAssertEqual(artifacts.quarantineCount, 2)
    }

    // MARK: - Enum bridges

    /// `BASEBrainRunMode` and `SessionMode` are 10-case mirrors.
    /// Iterate every substrate case through the bridge and assert
    /// the corresponding Qinao case has the same `rawValue`
    /// (both enums are backed by `String`). An added BAS case will
    /// fail the bridge's exhaustive switch at compile time, so this
    /// test is the behavioral counterpart.
    func testSessionModeBridgeCoversAllRunModes() {
        for runMode in BASEBrainRunMode.allCases {
            let sessionMode = QinaoRuntime.sessionMode(
                fromRunMode: runMode)
            XCTAssertEqual(sessionMode.rawValue, runMode.rawValue,
                "sessionMode bridge for \(runMode) must preserve rawValue")
        }
    }

    /// `BASEmergencyBrakeLevel` and `BrakeLevel` are 5-case mirrors.
    /// Same rawValue-equality test as `SessionMode`.
    func testBrakeLevelBridgeCoversAllBrakeLevels() {
        for brake in BASEmergencyBrakeLevel.allCases {
            let mirror = QinaoRuntime.brakeLevel(
                fromBrakeLevel: brake)
            XCTAssertEqual(mirror.rawValue, brake.rawValue,
                "brakeLevel bridge for \(brake) must preserve rawValue")
        }
    }

    /// A specific mode mapping: `.quarantine` substrate → `.quarantine`
    /// mirror, with brake `.lockdown` → `.lockdown` mirror. Exercises
    /// the projection's combined mode+brake read path.
    func testProjectionReadsBudgetRunModeAndBrakeLevel() {
        let turn = cleanTurnResult { turn in
            turn.budgetFrame = BASBudgetFrame(
                runMode: .reflect,
                maxLoops: 3,
                maxCandidates: 3,
                maxDecodeTokens: 180,
                retrievalDepth: 2,
                precisionProfile: .protected,
                deviceRoute: .hybridLocal,
                thermalGuardLevel: .watch,
                maintenanceAllowed: false)
            turn.emergencyBrake = BASEmergencyBrake(
                brakeLevel: .guard,
                reasonCodes: ["bridge.test"])
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.mode",
            turnID: "turn.mode",
            snapshotRef: "snap.mode",
            policyHash: "policy.mode")

        XCTAssertEqual(
            artifacts.mode,
            QinaoSovereignControlPlane.SessionMode.reflect)
        XCTAssertEqual(
            artifacts.brake,
            QinaoSovereignControlPlane.BrakeLevel.guard)
    }

    // MARK: - sendSession(artifacts:) end-to-end

    /// Clean turn through the full artifact path: no throw, no halt.
    /// Mirrors `testCleanTurnPassesWithoutHalting` from
    /// `QinaoRuntimeSessionTests`, but via the M82 overload.
    func testSendSessionArtifactsAuditsCleanTurn() async throws {
        let fx = await makeRuntime()
        let turn = sealedTurnResult()
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.artifacts.clean",
            turnID: "turn.artifacts.clean",
            snapshotRef: "snap.artifacts.clean",
            policyHash: "policy.artifacts.clean")

        let outcome = try await fx.runtime.sendSession(
            artifacts: artifacts,
            coordinatorSeverity: .pass)

        XCTAssertFalse(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .pass)
        XCTAssertEqual(outcome.audit.parity, .match)
        let halted = await fx.sovereign.isSessionHalted(
            artifacts.sessionID)
        XCTAssertFalse(halted)
    }

    /// Laxer parity fails closed: coordinator reported `.pass` but
    /// the engine upgrades past it because `runtimeUnstableInHighRisk`
    /// is true. Mirrors `testLaxerParityFailsClosedAndMarksHalted`
    /// from the primitive-path tests, but the audit engine sees
    /// values projected from the substrate turn.
    func testSendSessionArtifactsLaxerParityFailsClosedAndMarksHalted()
        async throws
    {
        let fx = await makeRuntime()
        // Build sealed turn (policyLineage + sovereignAuditEntry both
        // populated), then explicitly set the caller-supplied
        // composite that the audit engine treats as a shadow-lock
        // trigger. The projection itself cannot derive this from
        // substrate state alone; the caller passes it through.
        let turn = sealedTurnResult()
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.artifacts.laxer",
            turnID: "turn.artifacts.laxer",
            snapshotRef: "snap.artifacts.laxer",
            policyHash: "policy.artifacts.laxer",
            runtimeUnstableInHighRisk: true)

        do {
            _ = try await fx.runtime.sendSession(
                artifacts: artifacts,
                coordinatorSeverity: .pass)
            XCTFail("expected auditParityFailure")
        } catch QinaoRuntime.TurnError.auditParityFailure(
            let sessionID, let severity, let auditRef)
        {
            XCTAssertEqual(sessionID, artifacts.sessionID)
            XCTAssertGreaterThanOrEqual(severity, .shadowLock)
            XCTAssertFalse(auditRef.isEmpty)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let halted = await fx.sovereign.isSessionHalted(
            artifacts.sessionID)
        XCTAssertTrue(halted)
        let reason = await fx.sovereign.haltReason(
            sessionID: artifacts.sessionID)
        XCTAssertEqual(reason, "audit-parity:coordinator-laxer")
    }

    /// A session halted before the call refuses without auditing,
    /// just like the primitive path.
    func testSendSessionArtifactsPreHaltedSessionRefuses() async throws {
        let fx = await makeRuntime()
        let sessionID = "sess.artifacts.prehalted"
        await fx.sovereign.markSessionHalted(
            sessionID: sessionID,
            reason: "manual-pre-halt")
        let turn = sealedTurnResult()
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: sessionID,
            turnID: "turn.artifacts.prehalted",
            snapshotRef: "snap.artifacts.prehalted",
            policyHash: "policy.artifacts.prehalted")

        do {
            _ = try await fx.runtime.sendSession(
                artifacts: artifacts,
                coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted(let id) {
            XCTAssertEqual(id, sessionID)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// A projected unauthorized-self-mutation drives the audit engine
    /// into `.deadStop` severity, which is in the auto-halt set. End
    /// to end: the substrate staged an unauthorized version delta,
    /// the projection flagged it, and the audit engine halted the
    /// session without ever seeing `BASEBrainTurnResult` directly.
    func testSendSessionArtifactsDeadStopSeverityAutoHalts() async throws {
        let fx = await makeRuntime()
        let turn = sealedTurnResult { turn in
            turn.versionDeltas = [self.makeVersionDelta()]
        }
        let artifacts = QinaoRuntime.projectTurnArtifacts(
            fromTurnResult: turn,
            sessionID: "sess.artifacts.deadstop",
            turnID: "turn.artifacts.deadstop",
            snapshotRef: "snap.artifacts.deadstop",
            policyHash: "policy.artifacts.deadstop")

        let outcome = try await fx.runtime.sendSession(
            artifacts: artifacts,
            coordinatorSeverity: nil)

        XCTAssertTrue(outcome.sessionHalted)
        XCTAssertEqual(outcome.audit.severity, .deadStop)
        XCTAssertEqual(outcome.audit.parity, .engineOnly)
        let halted = await fx.sovereign.isSessionHalted(
            artifacts.sessionID)
        XCTAssertTrue(halted)
        let reason = await fx.sovereign.haltReason(
            sessionID: artifacts.sessionID)
        XCTAssertEqual(reason, "audit-severity:deadStop")
    }
}
