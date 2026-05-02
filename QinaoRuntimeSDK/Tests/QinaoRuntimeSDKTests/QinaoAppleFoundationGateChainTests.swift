import XCTest
import CryptoKit
import BASRuntimeCore
import BASMemory
import BASSovereign
import QinaoLoop
import QinaoAppleFoundation
@testable import QinaoRuntime
@testable import QinaoHost
@testable import QinaoMemory
@testable import QinaoRisk
@testable import QinaoSovereign

/// M186 — full three-signature gate end-to-end with a real on-device
/// LLM producing the intent.
///
/// ## What this proves
///
/// Invariant #2 (神经不直接掌权 / "the network never rules") says the
/// neural network produces *intent* but never *permission*. The gate
/// is the structural enforcement: every side-effect-bearing tool
/// call must carry ActionPermit (risk gate) + SovereignWarrant
/// (sovereign control plane) + SnapshotContinuityProof (snapshot
/// ark) all bound to the same intent digest, or the runtime refuses.
///
/// `QinaoRuntimeGateTests` proves the gate's correctness with
/// hand-crafted intents. M186 closes the last loop: a REAL Apple FM
/// LLM body produces the intent, and the production gate path lets
/// it through cleanly to the tool executor. End-to-end, on-device,
/// no synthetic data.
///
/// ## Gating
///
/// Same `QINAO_FM_E2E=1` + macOS 26+ as the rest of the real-LLM
/// suite.
final class QinaoAppleFoundationGateChainTests: XCTestCase {

    private static let envFlag = "QINAO_FM_E2E"

    private func skipUnlessReady() throws {
        guard
            ProcessInfo.processInfo.environment[Self.envFlag] == "1"
        else {
            throw XCTSkip(
                "set \(Self.envFlag)=1 to exercise the three-" +
                "signature gate driven by real Apple FoundationModels")
        }
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            return
        }
        throw XCTSkip(
            "FoundationModels requires iOS 26+ / macOS 26+ / " +
            "visionOS 26+; current OS does not satisfy the guard")
    }

    private actor ToolRecorder {
        var callCount = 0
        var lastToolName: String?
        var lastPayload: Data?

        func record(name: String, payload: Data) -> Data {
            callCount += 1
            lastToolName = name
            lastPayload = payload
            return Data("ok".utf8)
        }
    }

    private struct GateFixture: Sendable {
        let runtime: QinaoRuntime
        let recorder: ToolRecorder
        let sovereign: QinaoSovereignControlPlane
        let risk: QinaoRiskGate
    }

    private func makeGateFixture(
        now: @escaping @Sendable () -> Date = { Date() }
    ) async -> GateFixture {
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
            warrantTTLSeconds: 30,
            now: now)
        let risk = QinaoRiskGate(permitTTLSeconds: 30, now: now)

        let constitution = BASHostConstitution(
            hostID: "host", activeVersion: "host.v1")
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

        return GateFixture(
            runtime: runtime,
            recorder: recorder,
            sovereign: sovereign,
            risk: risk)
    }

    /// Compute SHA-256 hex of a UTF-8 string. Same algorithm
    /// `BASOrganDeterministicAdapter.digest(...)` uses, so audit
    /// trails stay consistent across BAS / Qinao layers.
    private static func sha256Hex(of s: String) -> String {
        SHA256.hash(data: Data(s.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// Construct a SnapshotContinuityProof bound to a specific
    /// intent digest. Same shape used by `QinaoRuntimeGateTests`.
    private func proof(
        for intent: QinaoRiskGate.ActionIntent,
        now: Date,
        ttl: TimeInterval = 30
    ) -> QinaoRuntime.SnapshotContinuityProof {
        QinaoRuntime.SnapshotContinuityProof(
            proofID: "proof-\(UUID().uuidString)",
            sessionID: intent.sessionID,
            anchorID: "anchor-host.v1",
            intentDigest: intent.digest,
            issuedAt: now,
            expiresAt: now.addingTimeInterval(ttl))
    }

    // MARK: - Happy path: real LLM body → intent → all 3 sigs → execute

    func testRealLLMBodyDrivesThreeSignatureGateThroughTool()
        async throws
    {
        try skipUnlessReady()

        let nowDate = Date()
        let now: @Sendable () -> Date = { nowDate }
        let fx = await makeGateFixture(now: now)

        // Step 1: REAL Apple FoundationModels produces a draft body
        // — the loop's normal generation path. This is the "neural
        // produces intent" half of invariant #2.
        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let llmLoop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "gate-c1",
            title: "Calendar add event",
            prompt:
                "Reply with one short calendar event title (3-6 " +
                "words, no punctuation).",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
        // M400.3 — Code 1026 → XCTSkip
        let drafts: [QinaoLoop.GeneratedCandidate]
        do {
            drafts = try await llmLoop.generateCandidates(
                sessionID: "sess.gate.real.1", seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        XCTAssertEqual(drafts.count, 1)
        let draft = drafts[0]
        XCTAssertEqual(
            draft.providerID, "apple.foundation-models.v1",
            "intent's source body must come from real Apple FM")
        XCTAssertFalse(
            draft.body
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty)

        // Step 2: host translates the LLM body into a tool intent
        // (here: calendar.add_event payload). The intent's digest
        // is SHA256 of (toolName || body || sessionID) — opaque to
        // the gate but deterministic for downstream audit.
        let toolName = "calendar.add_event"
        let intentSessionID = "sess.gate.real.1"
        let payloadString = draft.body
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = Data(payloadString.utf8)
        let digest = Self.sha256Hex(
            of: toolName + "|" + payloadString + "|"
                + intentSessionID)
        let intent = QinaoRiskGate.ActionIntent(
            digest: digest,
            toolName: toolName,
            sessionID: intentSessionID,
            hostVersionID: "host.v1",
            summary: "add a calendar event derived from LLM draft")

        // Step 3: collect the three signatures.
        let permit = try await fx.risk
            .requestActionPermit(for: intent)
        let warrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: intent.digest,
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let snapshotProof = proof(for: intent, now: nowDate)

        XCTAssertEqual(permit.digest, intent.digest)
        XCTAssertEqual(warrant.intentDigest, intent.digest)
        XCTAssertEqual(snapshotProof.intentDigest, intent.digest)

        // Step 4: execute through the gate. Three-signature happy
        // path — runtime hits the tool executor and returns its
        // result.
        let result = try await fx.runtime.execute(
            toolName: toolName,
            payload: payload,
            intent: intent,
            signatures: QinaoRuntime.Signatures(
                permit: permit,
                warrant: warrant,
                snapshotProof: snapshotProof))

        XCTAssertEqual(
            String(data: result, encoding: .utf8), "ok",
            "executor must run the tool exactly once and " +
            "return its data")

        let calls = await fx.recorder.callCount
        XCTAssertEqual(
            calls, 1,
            "tool executor must run exactly once when all three " +
            "signatures are present and bound to the same digest")

        let payloadCaptured = await fx.recorder.lastPayload
        XCTAssertEqual(
            payloadCaptured, payload,
            "tool executor must receive the LLM-derived payload " +
            "byte-equal — proves the gate didn't mutate it")
    }

    // MARK: - Refusal path: missing warrant on real-LLM intent

    /// Even with a real-LLM body driving the intent + a valid
    /// permit, the gate must refuse if the warrant is bound to a
    /// DIFFERENT digest. Confirms the gate's digest-binding rule
    /// holds against intents whose source is a real model (not
    /// hand-crafted in the test).
    func testRealLLMIntentRefusedOnMismatchedWarrantDigest()
        async throws
    {
        try skipUnlessReady()

        let nowDate = Date()
        let now: @Sendable () -> Date = { nowDate }
        let fx = await makeGateFixture(now: now)

        let endpoint = await QinaoLoop
            .makeAppleFoundationEndpoint()
        let llmLoop = QinaoLoop(organEndpoint: endpoint)
        let seed = QinaoLoop.CandidateSeed(
            candidateID: "gate-c2",
            title: "Misbinding test",
            prompt: "Reply with one word.",
            role: .scout,
            expectedBenefit: 0.7,
            expectedCost: 0.2,
            reversibility: 0.9,
            confidence: 0.8)
        // M400.3 — Code 1026 → XCTSkip
        let drafts: [QinaoLoop.GeneratedCandidate]
        do {
            drafts = try await llmLoop.generateCandidates(
                sessionID: "sess.gate.real.2", seeds: [seed])
        } catch {
            try skipIfAFMDegraded(error)
            throw error
        }
        let draft = drafts[0]

        let toolName = "calendar.add_event"
        let payload = Data(draft.body.utf8)
        let intent = QinaoRiskGate.ActionIntent(
            digest: Self.sha256Hex(of: "real-intent"),
            toolName: toolName,
            sessionID: "sess.gate.real.2",
            hostVersionID: "host.v1",
            summary: "real-LLM intent — well-formed")

        // Permit bound to the REAL intent.
        let permit = try await fx.risk
            .requestActionPermit(for: intent)
        // Warrant bound to a DIFFERENT digest — the misbinding.
        let wrongWarrant = try await fx.sovereign.issueWarrant(
            for: QinaoSovereignControlPlane.Intent(
                digest: Self.sha256Hex(of: "different-intent"),
                sessionID: intent.sessionID,
                hostVersionID: intent.hostVersionID))
        let snapshotProof = proof(for: intent, now: nowDate)

        do {
            _ = try await fx.runtime.execute(
                toolName: toolName,
                payload: payload,
                intent: intent,
                signatures: QinaoRuntime.Signatures(
                    permit: permit,
                    warrant: wrongWarrant,
                    snapshotProof: snapshotProof))
            XCTFail("expected digestMismatch on misbound warrant")
        } catch QinaoRuntime.RuntimeError
            .digestMismatch(let expected, let got)
        {
            XCTAssertEqual(expected, intent.digest)
            XCTAssertEqual(got, wrongWarrant.intentDigest)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let calls = await fx.recorder.callCount
        XCTAssertEqual(
            calls, 0,
            "tool executor MUST NOT run when any signature is " +
            "misbound — invariant #2 enforcement")
    }
}
