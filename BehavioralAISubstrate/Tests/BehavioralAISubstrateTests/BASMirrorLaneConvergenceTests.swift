import XCTest
import CryptoKit
@testable import BASHostKit
import BASOrgan
@testable import BASSovereign
@testable import BASRuntimeCore

/// Mirror-lane charter M1-M3 (2026-07-12) — operator rulings ①②③.
/// Load-bearing claims:
///  1. The disposer is deterministic: schema-reject / evidence-reduce / accept, with
///     trusted values STAMPED (policy hash, clock), never copied from the claim.
///  2. The envelope's HMAC binds every ruling-③ provenance field incl. evidence arity.
///  3. The Ledger ingest gate is verify-then-append: unsigned/tampered/schema-invalid
///     envelopes are rejected with a typed reason and ZERO writes.
final class BASMirrorLaneConvergenceTests: XCTestCase {

    private let key = SymmetricKey(data: Data("mirror-lane-test-key".utf8))
    private let policy = BASMirrorLanePolicy(trustedPolicyHash: "policy.trusted.v1")
    private let frozen = Date(timeIntervalSince1970: 1_700_000_000)

    private func candidate(
        kind: BASMirrorLaneKind = .proposal,
        content: String = "the operator tends to over-commit on Fridays",
        evidence: [String] = ["atom:1234", "atom:5678"],
        evidenceDigests: [String]? = nil,
        modelID: String = "qwen3.5-2b-v12",
        promptDigest: String = "pd-abc123",
        claimedPolicy: String = "policy.trusted.v1"
    ) -> BASMirrorLaneCandidate {
        BASMirrorLaneCandidate(
            claimedKind: kind, content: content, evidenceIDs: evidence,
            evidenceDigests: evidenceDigests ?? evidence.map { "digest-\($0)" },
            modelID: modelID, promptDigest: promptDigest,
            claimedPolicyHash: claimedPolicy, provenance: "mirror-lane-test")
    }

    private func dispose(
        _ c: BASMirrorLaneCandidate, id: String = "env-1"
    ) -> BASMirrorLaneDisposer.Disposition {
        BASMirrorLaneDisposer.dispose(
            c, policy: policy, key: key, envelopeID: id, now: frozen)
    }

    // MARK: - M2: accept / reduce / reject

    func testAcceptedEnvelopeIsSignedAndStamped() throws {
        guard case .accepted(let env) = dispose(candidate()) else {
            return XCTFail("evidence-backed proposal must be accepted")
        }
        XCTAssertTrue(env.verifySignature(with: key))
        XCTAssertEqual(env.kind, .proposal)
        XCTAssertEqual(env.policyHash, "policy.trusted.v1", "TRUSTED hash stamped")
        XCTAssertEqual(env.producedAtMs, 1_700_000_000_000, "clock stamped by gate")
        XCTAssertEqual(env.contentDigest,
            BASConvergedProposalEnvelope.sha256Hex(env.content))
    }

    func testDispositionIsDeterministic() {
        guard case .accepted(let a) = dispose(candidate()),
              case .accepted(let b) = dispose(candidate()) else {
            return XCTFail("both must accept")
        }
        XCTAssertEqual(a, b, "same inputs + key + clock ⇒ byte-identical envelope")
    }

    func testEvidenceFreeProposalIsReducedToAnnotation() {
        guard case .reduced(let env, let dropped) =
            dispose(candidate(evidence: [])) else {
            return XCTFail("evidence-free proposal must be REDUCED, not accepted")
        }
        XCTAssertEqual(dropped, .proposal)
        XCTAssertEqual(env.kind, .annotation, "opinion may annotate, not propose")
        XCTAssertTrue(env.verifySignature(with: key), "reduced envelope is still signed")
    }

    func testEvidenceFreeWarrantRequestIsReduced() {
        guard case .reduced(_, let dropped) =
            dispose(candidate(kind: .warrantRequest, evidence: [])) else {
            return XCTFail("evidence-free warrant-request must be reduced")
        }
        XCTAssertEqual(dropped, .warrantRequest)
    }

    func testRejections() {
        func rejects(_ c: BASMirrorLaneCandidate,
                     _ want: BASMirrorLaneDisposer.RejectReason) {
            guard case .rejected(let reason) = dispose(c) else {
                return XCTFail("expected rejection \(want)")
            }
            XCTAssertEqual(reason, want)
        }
        rejects(candidate(content: "   "), .emptyContent)
        rejects(candidate(content: String(repeating: "x", count: 4_001)),
                .contentTooLong)
        rejects(candidate(modelID: ""), .missingModelID)
        rejects(candidate(promptDigest: ""), .missingPromptDigest)
        rejects(candidate(claimedPolicy: "policy.OTHER"), .policyHashMismatch)
        rejects(candidate(claimedPolicy: ""), .policyHashMismatch)

        let narrow = BASMirrorLanePolicy(
            trustedPolicyHash: "policy.trusted.v1",
            allowedKinds: [.annotation])
        guard case .rejected(.kindNotAllowed) = BASMirrorLaneDisposer.dispose(
            candidate(kind: .warrantRequest), policy: narrow, key: key,
            envelopeID: "env-k", now: frozen) else {
            return XCTFail("kind outside policy must reject")
        }
    }

    // MARK: - M1: signature binding

    func testTamperedFieldBreaksSignature() throws {
        guard case .accepted(let env) = dispose(candidate()) else {
            return XCTFail()
        }
        let tampered = BASConvergedProposalEnvelope(
            envelopeID: env.envelopeID, kind: env.kind, content: env.content,
            contentDigest: env.contentDigest, evidenceIDs: env.evidenceIDs,
            evidenceDigests: env.evidenceDigests,
            modelID: "SWAPPED-MODEL", promptDigest: env.promptDigest,
            policyHash: env.policyHash, reducerVersion: env.reducerVersion,
            producedAtMs: env.producedAtMs,
            provenance: env.provenance, signerKeyID: env.signerKeyID,
            signature: env.signature)
        XCTAssertFalse(tampered.verifySignature(with: key))
    }

    func testEvidenceArityIsBoundIntoSignature() {
        func env(_ evidence: [String]) -> BASConvergedProposalEnvelope {
            BASConvergedProposalEnvelope(
                envelopeID: "e", kind: .proposal, content: "c",
                contentDigest: "d", evidenceIDs: evidence,
                evidenceDigests: evidence.map { _ in "x" }, modelID: "m",
                promptDigest: "p", policyHash: "ph",
                reducerVersion: "r1", producedAtMs: 0,
                provenance: "prov", signerKeyID: "k1",
                signature: "").signed(with: key)
        }
        XCTAssertNotEqual(env(["ab"]).signature, env(["a", "b"]).signature,
            "evidence arity must be part of the canonical payload")
    }

    func testWrongKeyFailsVerification() {
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        XCTAssertFalse(env.verifySignature(
            with: SymmetricKey(data: Data("other-key".utf8))))
    }

    // MARK: - M3: verify-then-append, zero partial writes

    /// deep-audit P2-14(c) (2026-07-13): a PRIMARY-KEY (audit_id) collision at append is a REPLAY,
    /// typed .replayed — not the generic .appendFailed. Deterministic setup: two SQLite ledgers
    /// over the SAME file, ledger B created BEFORE A appends, so B's in-memory hasEntry pre-check
    /// never learns the audit_id → the ingest reaches the append path, where B hits the DB
    /// uniqueness constraint. Reversal: the storage mapping SQLITE_CONSTRAINT to .stepFailed (or
    /// the ingest not typing .duplicateAuditID) reds the .replayed assertion.
    func testSQLiteConstraintReplayRaceIsTypedReplayed() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mirror-replay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let path = dir.appendingPathComponent("ledger.sqlite").path
        let secret = SymmetricKey(size: .bits256)

        // B is created FIRST (empty in-memory), then A appends — so B's pre-check will miss.
        let ledgerB = BASSovereignAuditLedger(
            signingSecret: secret, storage: try BASSovereignLedgerSQLiteStorage(path: path))
        let ledgerA = BASSovereignAuditLedger(
            signingSecret: secret, storage: try BASSovereignLedgerSQLiteStorage(path: path))

        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let a = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledgerA, sessionID: "s", turnID: "t", now: frozen)
        XCTAssertTrue(a.appended, "first ingest must append")

        // B ingests the SAME envelope: pre-check misses (B never learned the audit_id), append
        // violates the audit_id PRIMARY KEY → typed .replayed.
        let b = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledgerB, sessionID: "s", turnID: "t", now: frozen)
        XCTAssertFalse(b.appended)
        XCTAssertEqual(b.reason, .replayed,
            "a PRIMARY-KEY replay-race must be typed .replayed, not .appendFailed")
    }

    func testIngestAppendsVerifiedEnvelope() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }

        let outcome = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertTrue(outcome.appended)
        XCTAssertEqual(outcome.auditID, "mirror-env-1")
        XCTAssertNil(outcome.reason)
        let count = await ledger.count()
        XCTAssertEqual(count, 1)
    }

    /// The journal's production ledger sets a HARDENED schema floor (1.2.0) — the ingest
    /// draft must clear it (caught live by the first CLI smoke: default 1.0.0 was floored).
    func testIngestClearsHardenedSchemaFloor() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256),
            minimumSchemaVersion: BASSovereignAuditEntry.hardenedSchemaVersion)
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let outcome = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertTrue(outcome.appended,
            "the mirror draft must use the hardened injective form, got \(String(describing: outcome.reason))")
    }

    /// deep-audit P1-11 (2026-07-13): the ingest gate is defense-in-depth for provenance,
    /// INDEPENDENT of the disposer. A validly-SIGNED envelope with empty provenance (built
    /// directly, bypassing the disposer) must still be refused at the gate with ZERO writes.
    /// Reversal: removing the gate's provenance check appends this unattributed envelope.
    func testEmptyProvenanceEnvelopeIsRejectedAtIngestGate() async throws {
        let ledger = BASSovereignAuditLedger(signingSecret: SymmetricKey(size: .bits256))
        let content = "observation"
        let env = BASConvergedProposalEnvelope(
            envelopeID: "mirror-noprov", kind: .annotation, content: content,
            contentDigest: BASConvergedProposalEnvelope.sha256Hex(content),
            evidenceIDs: [], evidenceDigests: [],
            modelID: "m1", promptDigest: "p1", policyHash: "policy.trusted.v1",
            reducerVersion: BASMirrorLaneDisposer.reducerVersion,
            producedAtMs: 1_700_000_000_000, provenance: "",
            signerKeyID: BASConvergedProposalEnvelope.keyID(of: key), signature: "")
            .signed(with: key)
        // The reject must be the provenance check, NOT a signature failure.
        XCTAssertTrue(env.verifySignature(with: key), "the empty-provenance envelope IS validly signed")

        let outcome = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertFalse(outcome.appended)
        XCTAssertEqual(outcome.reason, .emptyProvenance)
        let count = await ledger.count()
        XCTAssertEqual(count, 0, "an unattributed envelope must leave ZERO writes")
    }

    func testTamperedEnvelopeRejectedWithZeroWrites() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let tampered = BASConvergedProposalEnvelope(
            envelopeID: env.envelopeID, kind: env.kind, content: env.content,
            contentDigest: env.contentDigest, evidenceIDs: env.evidenceIDs,
            evidenceDigests: env.evidenceDigests,
            modelID: "SWAPPED", promptDigest: env.promptDigest,
            policyHash: env.policyHash, reducerVersion: env.reducerVersion,
            producedAtMs: env.producedAtMs,
            provenance: env.provenance, signerKeyID: env.signerKeyID,
            signature: env.signature)

        let outcome = await BASMirrorLaneIngestGate.ingest(
            tampered, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertFalse(outcome.appended)
        XCTAssertEqual(outcome.reason, .badSignature)
        let count = await ledger.count()
        XCTAssertEqual(count, 0, "a rejected envelope must leave ZERO writes")
    }

    /// Content swap AFTER signing: canonical bytes bind the digest, not the raw text,
    /// so the signature stays valid — the ingest gate's digest recheck must catch it.
    func testContentSwapAfterSigningIsRejected() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let swapped = BASConvergedProposalEnvelope(
            envelopeID: env.envelopeID, kind: env.kind,
            content: "totally different text",
            contentDigest: env.contentDigest, evidenceIDs: env.evidenceIDs,
            evidenceDigests: env.evidenceDigests,
            modelID: env.modelID, promptDigest: env.promptDigest,
            policyHash: env.policyHash, reducerVersion: env.reducerVersion,
            producedAtMs: env.producedAtMs,
            provenance: env.provenance, signerKeyID: env.signerKeyID,
            signature: env.signature)
        XCTAssertTrue(swapped.verifySignature(with: key),
            "signature legitimately survives (digest is what is signed) — the gate must catch it")

        let outcome = await BASMirrorLaneIngestGate.ingest(
            swapped, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertFalse(outcome.appended)
        XCTAssertEqual(outcome.reason, .contentDigestMismatch)
        let count = await ledger.count()
        XCTAssertEqual(count, 0)
    }

    /// Replay protection: auditID = "mirror-<envelopeID>" + the SQLite storage's
    /// audit_id PRIMARY KEY ⇒ the SAME envelope cannot land twice. This property lives
    /// in PERSISTENT storage (the in-memory ledger has no uniqueness index), so the
    /// tooth uses SQLite — same as the journal's production ledger.
    func testSameEnvelopeCannotLandTwice() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mirror-replay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: dir.appendingPathComponent("ledger.sqlite").path)
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256), storage: storage)
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }

        let first = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertTrue(first.appended)
        let replay = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.2", now: frozen)
        XCTAssertFalse(replay.appended, "replaying the same envelope must be refused")
        XCTAssertEqual(replay.reason, .replayed, "ruling ③: replay is a TYPED reject now")
    }

    func testWrongKeyIngestRejected() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let outcome = await BASMirrorLaneIngestGate.ingest(
            env, key: SymmetricKey(data: Data("other-key".utf8)), ledger: ledger,
            sessionID: "sess.mirror", turnID: "turn.1", now: frozen)
        XCTAssertFalse(outcome.appended)
        XCTAssertEqual(outcome.reason, .badSignature)
    }
}

/// ruling ③ hardening (2026-07-12) — envelope v2: evidence CONTENT binding, reducer
/// version, signer key ID, and TYPED replay rejection on ANY storage.
final class BASMirrorLaneEnvelopeV2Tests: XCTestCase {

    private let key = SymmetricKey(data: Data("mirror-v2-key".utf8))
    private let policy = BASMirrorLanePolicy(trustedPolicyHash: "policy.trusted.v1")
    private let frozen = Date(timeIntervalSince1970: 1_700_000_000)

    private func cand(
        evidence: [String] = ["atom:1"], digests: [String] = ["d1"]
    ) -> BASMirrorLaneCandidate {
        BASMirrorLaneCandidate(
            claimedKind: .proposal, content: "observation",
            evidenceIDs: evidence, evidenceDigests: digests,
            modelID: "m1", promptDigest: "p1",
            claimedPolicyHash: "policy.trusted.v1", provenance: "t")
    }

    private func dispose(_ c: BASMirrorLaneCandidate) -> BASMirrorLaneDisposer.Disposition {
        BASMirrorLaneDisposer.dispose(
            c, policy: policy, key: key, envelopeID: "env-v2", now: frozen)
    }

    func testUnpairedEvidenceIsRejected() {
        guard case .rejected(.evidenceDigestMismatch) =
            dispose(cand(evidence: ["a", "b"], digests: ["only-one"])) else {
            return XCTFail("evidence without a paired content digest must be rejected")
        }
    }

    // MARK: - deep-audit P1-10 (2026-07-13): pairing must not silently shift across blanks.

    /// Blanks at DIFFERENT indices in each array. Pre-P1-10 the candidate init empty-filtered
    /// each array independently → IDs ["a","c"] / digests ["da","db"] (counts equal!), signing
    /// a SHIFTED pairing ("c"↔"db" instead of "c"↔the dropped blank). Now the disposer rejects
    /// any empty-after-trim entry before the count check. Reverting EITHER the init filter or
    /// the disposer check reds this (the mispair would be accepted).
    func testMispairedBlankEvidenceIsRejectedNotShifted() {
        guard case .rejected(.evidenceEntryEmpty) =
            dispose(cand(evidence: ["a", "", "c"], digests: ["da", "db", ""])) else {
            return XCTFail("mispaired blank evidence must fail closed, never sign a shifted pair")
        }
    }

    /// Whitespace-only entries are empty-after-trim too.
    func testWhitespaceOnlyEvidenceEntryIsRejected() {
        guard case .rejected(.evidenceEntryEmpty) =
            dispose(cand(evidence: ["a", "   "], digests: ["da", "db"])) else {
            return XCTFail("a whitespace-only evidence ID is unusable — reject, don't sign")
        }
    }

    /// The Codable-decode path SKIPS the custom candidate init entirely, so the pairing rule
    /// MUST live at the disposer (the trust boundary / only signed-envelope mint). A decoded
    /// candidate with a blank evidence entry must still be rejected — proving the check is not
    /// merely init hygiene. Reversal: dropping the disposer's empty check signs a blank pair.
    func testDecodedCandidateWithBlankEvidenceIsRejected() throws {
        let json = """
        {"claimedKind":"proposal","content":"observation",\
        "evidenceIDs":["atom:1","","atom:3"],\
        "evidenceDigests":["d1","d2","d3"],\
        "modelID":"m1","promptDigest":"p1",\
        "claimedPolicyHash":"policy.trusted.v1","provenance":"t"}
        """
        let decoded = try JSONDecoder().decode(
            BASMirrorLaneCandidate.self, from: Data(json.utf8))
        // The decode bypassed the init — the blank survives in the decoded value.
        XCTAssertEqual(decoded.evidenceIDs, ["atom:1", "", "atom:3"],
            "decode must not have run the custom init's normalization")
        guard case .rejected(.evidenceEntryEmpty) = dispose(decoded) else {
            return XCTFail("the disposer must reject a decoded candidate's blank evidence entry")
        }
    }

    // MARK: - deep-audit P1-11 (2026-07-13): provenance must at least be PRESENT.

    /// provenance is signed as-CLAIMED (never recomputed). The disposer must at minimum enforce
    /// its presence — an envelope that attributes itself to nothing is unattributable. Reversal:
    /// dropping the disposer's presence check signs an empty-provenance envelope.
    func testEmptyProvenanceIsRejectedAtDisposer() {
        let c = BASMirrorLaneCandidate(
            claimedKind: .proposal, content: "observation",
            evidenceIDs: ["atom:1"], evidenceDigests: ["d1"],
            modelID: "m1", promptDigest: "p1",
            claimedPolicyHash: "policy.trusted.v1", provenance: "")
        guard case .rejected(.missingProvenance) = dispose(c) else {
            return XCTFail("an unattributed candidate must be rejected at mint")
        }
    }

    func testEvidenceContentDigestIsSigned() throws {
        guard case .accepted(let a) = dispose(cand(digests: ["d1"])),
              case .accepted(let b) = dispose(cand(digests: ["DIFFERENT"])) else {
            return XCTFail()
        }
        XCTAssertNotEqual(a.signature, b.signature,
            "swapping the referenced evidence CONTENT must change the signature")
    }

    func testReducerVersionAndSignerKeyIDAreStampedAndSigned() throws {
        guard case .accepted(let env) = dispose(cand()) else { return XCTFail() }
        XCTAssertEqual(env.reducerVersion, BASMirrorLaneDisposer.reducerVersion)
        XCTAssertEqual(env.signerKeyID, BASConvergedProposalEnvelope.keyID(of: key))
        XCTAssertEqual(env.signerKeyID.count, 16)

        // tampering the signed keyID breaks the tag
        let forged = BASConvergedProposalEnvelope(
            envelopeID: env.envelopeID, kind: env.kind, content: env.content,
            contentDigest: env.contentDigest, evidenceIDs: env.evidenceIDs,
            evidenceDigests: env.evidenceDigests,
            modelID: env.modelID, promptDigest: env.promptDigest,
            policyHash: env.policyHash, reducerVersion: env.reducerVersion,
            producedAtMs: env.producedAtMs,
            provenance: env.provenance, signerKeyID: "0000000000000000",
            signature: env.signature)
        XCTAssertFalse(forged.verifySignature(with: key))
    }

    /// The pre-v2 gap: replay was only caught by SQLite's PRIMARY KEY (untyped) — the
    /// in-memory ledger accepted the same envelope twice. Now: typed, any storage.
    func testReplayIsTypedOnInMemoryLedger() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(cand()) else { return XCTFail() }
        let first = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "s", turnID: "t1", now: frozen)
        XCTAssertTrue(first.appended)
        let replay = await BASMirrorLaneIngestGate.ingest(
            env, key: key, ledger: ledger,
            sessionID: "s", turnID: "t2", now: frozen)
        XCTAssertFalse(replay.appended)
        XCTAssertEqual(replay.reason, .replayed)
        let count = await ledger.count()
        XCTAssertEqual(count, 1, "replay must leave the chain untouched")
    }
}

/// ruling ① completion (2026-07-12) — producer orchestration lives in BASHostKit;
/// the adapter is injected through the protocol seam.
final class BASMirrorLaneProducerTests: XCTestCase {

    private struct ScriptedAdapter: BASOrganAdapter {
        let descriptor = BASOrganDescriptor(
            providerID: "scripted.mirror", providerName: "Scripted",
            supportsStreaming: false, maxInputTokens: 1_000, maxOutputTokens: 1_000,
            runsOnDevice: true, supportedRoles: [.scout])
        func draft(_ request: BASOrganRequest) async throws -> BASOrganDraft {
            BASOrganDraft(
                requestID: request.requestID, providerID: descriptor.providerID,
                role: request.role, body: "a mirror observation",
                inputTokensEstimated: 1, outputTokensEstimated: 1,
                producedAt: Date(timeIntervalSince1970: 0), traceID: "t")
        }
        func currentCapacity() async -> BASOrganCapacity { .unlimited }
    }

    func testProducerBindsEvidenceDigestsAndProvenance() async throws {
        let sources = [
            BASMirrorLaneProducer.Source(id: "atom:a", content: "entry A"),
            BASMirrorLaneProducer.Source(id: "atom:b", content: "entry B"),
        ]
        let candidate = try await BASMirrorLaneProducer.produceCandidate(
            adapter: ScriptedAdapter(),
            sources: sources,
            trustedPolicyHash: "ph",
            provenance: "producer-test",
            requestID: "req-1")
        XCTAssertEqual(candidate.claimedKind, .annotation)
        XCTAssertEqual(candidate.content, "a mirror observation")
        XCTAssertEqual(candidate.evidenceIDs, ["atom:a", "atom:b"])
        XCTAssertEqual(candidate.evidenceDigests, [
            BASMirrorLaneProducer.sha256Hex("entry A"),
            BASMirrorLaneProducer.sha256Hex("entry B"),
        ])
        XCTAssertEqual(candidate.modelID, "scripted.mirror")
        XCTAssertFalse(candidate.promptDigest.isEmpty)
    }
}


/// charter audit 2026-07-12 finding ④ — BASChengluPreflightRoute opened from a closed
/// two-model enum to a RawRepresentable struct. Wire format is FROZEN (bare string).
final class BASChengluPreflightRouteOpennessTests: XCTestCase {

    func testWireFormatIsByteIdenticalToTheOldEnum() throws {
        // The old enum encoded as a bare string; the struct must too.
        let data = try JSONEncoder().encode(BASChengluPreflightRoute.afm)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"afm-route\"")
        let decoded = try JSONDecoder().decode(
            BASChengluPreflightRoute.self, from: Data("\"gemma-route\"".utf8))
        XCTAssertEqual(decoded, .gemma)
    }

    func testThirdModelFamilyIsNowExpressible() throws {
        // The whole point of the fix: a route the shipped presets don't know.
        let qwen = BASChengluPreflightRoute(rawValue: "qwen-route")
        let roundTripped = try JSONDecoder().decode(
            BASChengluPreflightRoute.self,
            from: JSONEncoder().encode(qwen))
        XCTAssertEqual(roundTripped, qwen)
        XCTAssertFalse(BASChengluPreflightRoute.knownRoutes.contains(qwen),
            "host-minted routes are deliberately not in the shipped preset list")
    }

    func testShippedPresetRawValuesAreFrozen() {
        XCTAssertEqual(BASChengluPreflightRoute.afm.rawValue, "afm-route")
        XCTAssertEqual(BASChengluPreflightRoute.gemma.rawValue, "gemma-route")
    }
}
