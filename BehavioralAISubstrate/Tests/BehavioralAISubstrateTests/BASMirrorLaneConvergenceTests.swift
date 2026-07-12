import XCTest
import CryptoKit
@testable import BASHostKit
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
        modelID: String = "qwen3.5-2b-v12",
        promptDigest: String = "pd-abc123",
        claimedPolicy: String = "policy.trusted.v1"
    ) -> BASMirrorLaneCandidate {
        BASMirrorLaneCandidate(
            claimedKind: kind, content: content, evidenceIDs: evidence,
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
            modelID: "SWAPPED-MODEL", promptDigest: env.promptDigest,
            policyHash: env.policyHash, producedAtMs: env.producedAtMs,
            provenance: env.provenance, signature: env.signature)
        XCTAssertFalse(tampered.verifySignature(with: key))
    }

    func testEvidenceArityIsBoundIntoSignature() {
        func env(_ evidence: [String]) -> BASConvergedProposalEnvelope {
            BASConvergedProposalEnvelope(
                envelopeID: "e", kind: .proposal, content: "c",
                contentDigest: "d", evidenceIDs: evidence, modelID: "m",
                promptDigest: "p", policyHash: "ph", producedAtMs: 0,
                provenance: "prov", signature: "").signed(with: key)
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

    func testTamperedEnvelopeRejectedWithZeroWrites() async throws {
        let ledger = BASSovereignAuditLedger(
            signingSecret: SymmetricKey(size: .bits256))
        guard case .accepted(let env) = dispose(candidate()) else { return XCTFail() }
        let tampered = BASConvergedProposalEnvelope(
            envelopeID: env.envelopeID, kind: env.kind, content: env.content,
            contentDigest: env.contentDigest, evidenceIDs: env.evidenceIDs,
            modelID: "SWAPPED", promptDigest: env.promptDigest,
            policyHash: env.policyHash, producedAtMs: env.producedAtMs,
            provenance: env.provenance, signature: env.signature)

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
            modelID: env.modelID, promptDigest: env.promptDigest,
            policyHash: env.policyHash, producedAtMs: env.producedAtMs,
            provenance: env.provenance, signature: env.signature)
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
        XCTAssertEqual(replay.reason, .appendFailed)
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
