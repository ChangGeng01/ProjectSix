import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
import QinaoLoop
import QinaoRisk
import QinaoMemory
import QinaoHost
import QinaoSovereign
import QinaoAppleFoundation
@testable import QinaoRuntime

/// M201 — comprehensive host-flow demo expressed as a test.
///
/// ## Why this exists
///
/// M177-M200 each pin one slice of the system on a real LLM:
/// streaming, three-signature gate, audit chain, L4 / L8 / L13 /
/// L14 governance, etc. None of those tests exercises ALL of them
/// in one turn. A real host doing the obvious thing — "let the
/// model suggest something, ask for permission, do the action,
/// remember what happened, propose evolving from it" — runs every
/// one of those subsystems in sequence.
///
/// M201 is that test. One end-to-end happy path demonstrating how
/// a host wires the SDK. It serves three purposes:
///
/// 1. Regression alarm: if any layer's contract drifts, the demo
///    breaks before host code does.
/// 2. Documentation: hosts looking for "show me the whole pattern"
///    can copy this file as a starting point.
/// 3. Composition pin: the 7-step host pattern is exercised
///    against a real LLM, not a stub, so the public API is proven
///    sufficient to drive the on-device model.
///
/// ## Steps the demo walks through
///
/// 1. Bootstrap — control plane (with persistent SQLite ledger),
///    risk gate, memory, host, loop with Apple FM endpoint.
/// 2. Generate a candidate from a real LLM prompt
///    (`QinaoLoop.generateCandidates`).
/// 3. Derive an `ActionIntent` from the LLM body; collect permit +
///    warrant + snapshot proof and execute through the
///    three-signature gate (`QinaoRuntime.execute`).
/// 4. Admit the executed action into L8 memory
///    (`QinaoMemory.admit`).
/// 5. Submit an evolution candidate to L13 furnace
///    (`QinaoFurnace.submit`).
/// 6. Observe one effect, finalize as `.passed`, get the seal.
/// 7. Verify the audit chain has accumulated entries by counting
///    them via `QinaoSovereignControlPlane.auditEntryCount()`.
///
/// Gated behind `QINAO_FM_E2E=1` + macOS 26+.
final class QinaoSampleHostFlowTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise the sample " +
                "host flow against a real Apple LLM")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+")
    }

    private func tempLedgerPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-m201-\(UUID().uuidString)")
            .appendingPathExtension("sqlite")
            .path
    }

    private func cleanupLedger(_ path: String) {
        for suffix in ["", "-journal", "-wal", "-shm"] {
            try? FileManager.default
                .removeItem(atPath: path + suffix)
        }
    }

    func testFullHostFlowOnRealAppleLLM() async throws {
        try skipUnlessReady()

        // ---------------------------------------------------------
        // Step 1: bootstrap. Persistent ledger, real Apple FM
        // endpoint, full Qinao stack.
        // ---------------------------------------------------------
        let ledgerPath = tempLedgerPath()
        defer { cleanupLedger(ledgerPath) }

        let now: @Sendable () -> Date = { Date() }
        let config = QinaoSovereignControlPlane.Configuration(
            warrantTTLSeconds: 30,
            ledgerSigningSecret: Data("m201-host-flow".utf8),
            ledgerDatabasePath: ledgerPath,
            now: now)
        let (sovereign, _) = QinaoSovereignControlPlane
            .bootstrap(configuration: config)

        let risk = QinaoRiskGate(
            permitTTLSeconds: 30, now: now)
        let memory = QinaoMemory(
            minimumConfidence: 0.5, now: now)

        let constitution = BASHostConstitution(
            hostID: "host.demo",
            activeVersion: "host.v1")
        let tree = BASHostVersionTree(
            activeVersionID: "host.v1",
            versions: [
                BASHostVersion(
                    versionID: "host.v1",
                    createdAt: now(),
                    changedFields: [],
                    reason: "demo seed",
                    approvedByPolicy: true)
            ])
        let pipeline = BASHostCandidatePipeline(
            constitution: constitution,
            versionTree: tree,
            clock: now)
        let host = QinaoHost(pipeline: pipeline)

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let loop = QinaoLoop(organEndpoint: endpoint)

        actor ToolRecorder {
            var calls = 0
            var lastTool: String?
            var lastPayload: Data?
            func record(name: String, payload: Data) -> Data {
                calls += 1
                lastTool = name
                lastPayload = payload
                return Data("ok".utf8)
            }
        }
        let recorder = ToolRecorder()
        let executor: QinaoRuntime.ToolExecutor = {
            name, payload in
            await recorder.record(name: name, payload: payload)
        }
        let runtime = QinaoRuntime(
            host: host, memory: memory, risk: risk,
            sovereign: sovereign, loop: loop,
            toolExecutor: executor, now: now)

        // ---------------------------------------------------------
        // Step 2: generate a candidate from a real LLM prompt.
        // ---------------------------------------------------------
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "demo-c1",
            title: "Demo seed",
            prompt: "Reply with one short calendar event title.",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
        // M400.3 — Code 1026 → XCTSkip
        let drafts: [QinaoLoop.GeneratedCandidate]
        do {
            drafts = try await loop.generateCandidates(
                sessionID: "sess.demo.1", seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        XCTAssertEqual(drafts.count, 1)
        let draft = drafts[0]
        XCTAssertEqual(
            draft.providerID, "apple.foundation-models.v1",
            "step 2: candidate must come from real Apple LLM")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)

        // ---------------------------------------------------------
        // Step 3: three-signature gate + execute.
        // ---------------------------------------------------------
        let toolName = "calendar.add_event"
        let payload = Data(draft.body.utf8)
        let digest = SHA256.hash(
            data: Data((toolName + "|" + draft.body).utf8))
            .map { String(format: "%02x", $0) }.joined()
        let intent = QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: toolName,
            sessionID: "sess.demo.1",
            hostVersionID: "host.v1",
            summary: "demo: add LLM-suggested event")

        let permit = try await risk
            .requestActionPermit(for: intent)
        let warrant = try await sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let snapshotProof = QinaoRuntime.SnapshotContinuityProof(
            proofID: "proof.demo",
            sessionID: intent.sessionID,
            anchorID: "anchor.demo",
            intentDigest: intent.digest,
            issuedAt: now(),
            expiresAt: now().addingTimeInterval(30))

        let execResult = try await runtime.execute(
            toolName: toolName,
            payload: payload,
            intent: intent,
            signatures: QinaoRuntime.Signatures(
                permit: permit,
                warrant: warrant,
                snapshotProof: snapshotProof))
        XCTAssertEqual(
            String(data: execResult, encoding: .utf8), "ok",
            "step 3: tool executor must return 'ok'")
        let toolCalls = await recorder.calls
        XCTAssertEqual(toolCalls, 1)

        // ---------------------------------------------------------
        // Step 4: admit the action into L8 memory.
        // ---------------------------------------------------------
        let admitted = try await memory.admit(
            QinaoMemory.AdmitRequest(
                kind: .episodic,
                content:
                    "demo: executed calendar.add_event with body " +
                    "'\(draft.body)'",
                scope: .session,
                sensitivity: .low,
                confidence: 0.85,
                preferredTier: .warm,
                sourceType: "qinao.demo.m201",
                tags: ["m201", "demo"]))
        let recalled = await memory.recall(
            scope: .session, sensitivity: .low)
        XCTAssertTrue(
            recalled.contains(where: { $0.id == admitted.id }),
            "step 4: admitted memory must be recallable")

        // ---------------------------------------------------------
        // Step 5: submit an evolution candidate to L13 furnace.
        // ---------------------------------------------------------
        let furnace = QinaoFurnace()
        let evCandidate = QinaoFurnace.ExperienceCandidate(
            candidateID: "demo-evo-c1",
            sourceRefs: ["sess.demo.1#turn.1"],
            candidateType: .workflow,
            summary:
                "demo: when user asks for a calendar event, " +
                "respond with one short title and add it.",
            stabilitySignal: 0.8,
            contaminationRisk: 0.1,
            hostScope: "host.demo",
            sovereignScope: "sovereign.demo")
        let trial = try await furnace.submit(
            candidate: evCandidate,
            sessionID: "sess.demo.1",
            turnID: "turn.demo.1",
            trialScope: "qinao.m201.demo")
        XCTAssertEqual(trial.completionState, "pending")

        // ---------------------------------------------------------
        // Step 6: observe + finalize(.passed) → seal.
        // ---------------------------------------------------------
        _ = try await furnace.observe(
            trialID: trial.trialID,
            effect: "host accepted the demo workflow",
            sessionID: "sess.demo.1",
            turnID: "turn.demo.1")
        let finalized = try await furnace.finalize(
            trialID: trial.trialID,
            outcome: .passed,
            promotionRecommendation: "promote to demo workflows",
            sessionID: "sess.demo.1",
            turnID: "turn.demo.1")
        XCTAssertEqual(finalized.completionState, "passed")

        let seal = await furnace.seal(for: "demo-evo-c1")
        XCTAssertNotNil(
            seal,
            "step 6: passed shadow trial MUST produce an evolution " +
            "seal")

        // ---------------------------------------------------------
        // Step 7: audit the turn — this drives the verdict engine
        // and appends a hash-chained entry to the SQLite ledger.
        // ---------------------------------------------------------
        let observations = QinaoSovereignControlPlane
            .TurnObservations(
                sessionID: "sess.demo.1",
                turnID: "turn.demo.1",
                snapshotRef: "snap.demo",
                policyHash: "policy.demo")
        _ = try await sovereign.auditTurn(
            observations: observations,
            coordinatorSeverity: .pass)

        let auditCount = await sovereign.auditEntryCount()
        XCTAssertGreaterThan(
            auditCount, 0,
            "step 7: persistent audit ledger must have at least " +
            "one entry after auditTurn(...). Got \(auditCount).")

        // The persistent ledger file exists and survives the demo.
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: ledgerPath),
            "ledger SQLite file must be on disk after the demo")
    }
}
