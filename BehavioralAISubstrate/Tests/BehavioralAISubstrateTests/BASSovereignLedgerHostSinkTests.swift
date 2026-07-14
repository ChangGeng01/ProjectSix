// MARK: - BASSovereignLedgerHostSinkTests — 主权闭环宿主接入 gate
//
// The sink closes the gap the promotion inventory found + the
// coordinator comment at EBrainRuntimeCoordinator+SovereignCommit
// .swift:1615-1620 literally describes ("this entry … is NEVER
// passed to the keyed BASSovereignAuditLedger.append … so the keyed
// ledger is the SOLE producer of a real signature when this entry is
// appended")。 Load-bearing claims:
//   1. A real turn's sovereignAuditEntry, recorded, becomes SIGNED +
//      CHAINED (the ledger verifies its own key over the chain)。
//   2. Multiple turns CHAIN (head advances; full-chain audit clean)。
//   3. BYTE-SAFETY: recording is a side effect — the turn result's
//      entry stays signature-empty;the result is untouched。
//   4. The host ledger is the SIGNING AUTHORITY — an inbound
//      signature is cleared and re-signed under the host key。
//   5. CROSS-RESTART: a file-keyed/SQLite reference host rehydrates
//      the chain and appends onto the persisted head。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASSovereignLedgerHostSinkTests: XCTestCase {

    /// Cooperative-pool safe: the 27e0fcb2e stack class is fixed (CoW-boxed turn
    /// result + stage-split runTurn; the 64,000B peak budget is MEASURED and enforced on
    /// every default pass by BASRunTurnFrameBudgetTests (last measured peak: 57,360B)。
    private static func drivenTurn(
        prompt: String = "Should I send this important message now?"
    ) throws -> BASEBrainTurnResult {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: "sovereign-sink",
                riskLevel: .medium))
        // A nil turn from a fixture startSession is a BROKEN TURN PIPELINE — the
        // exact failure this suite exists to catch — so it must RED, not skip.
        // (HostRuntimeCore builds a non-optional eBrainTurn and passes it straight
        // into BASHostSessionResult, so this can only fire on a real regression.)
        // Matches the 10+ sibling call sites that use XCTUnwrap.
        return try XCTUnwrap(
            result.eBrainTurn,
            "fixture startSession must always produce an eBrainTurn")
    }

    private func makeInMemorySink() -> BASSovereignLedgerHostSink {
        // Designated init with a fresh generated key + null storage
        // (in-memory chain) — the host-injected production shape。
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate())
        return BASSovereignLedgerHostSink(ledger: ledger)
    }

    /// deep-audit L-3 follow-on (2026-07-13): a SQLite-backed sink — the coverage GAP that
    /// hid the non-unique-auditID bug. The `audit_id TEXT PRIMARY KEY` constraint rejects a
    /// duplicate auditID on the SECOND append, so two distinct turns chaining to count==2
    /// PROVES each turn now gets a unique auditID (pre-fix this failed here while the
    /// in-memory backend, having no uniqueness check, stayed green).
    func testChainsAcrossTurnsOnSQLiteBackend() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("bas-sink-sqlite-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let storage = try BASSovereignLedgerSQLiteStorage(
            path: dir.appendingPathComponent("ledger.sqlite").path)
        let ledger = BASSovereignAuditLedger(
            ed25519KeyPair: BASSovereignEd25519KeyPair.generate(), storage: storage)
        let sink = BASSovereignLedgerHostSink(ledger: ledger)

        let t1 = try await MainActor.run {
            try Self.drivenTurn(prompt: "First distinct turn.") }
        let t2 = try await MainActor.run {
            try Self.drivenTurn(prompt: "Second, distinct turn.") }
        let o1 = await sink.recordTurn(t1)
        let o2 = await sink.recordTurn(t2)
        XCTAssertTrue(o1.appended, "first turn must append")
        XCTAssertTrue(o2.appended,
            "second turn must append on SQLite — a shared auditID would be rejected by "
            + "the audit_id PRIMARY KEY (reason: \(o2.reason ?? "nil"))")
        let count = await sink.appendedCount()
        XCTAssertEqual(count, 2, "two distinct turns chain to two persisted entries")
        // distinct auditIDs is the underlying invariant
        XCTAssertNotEqual(t1.sovereignAuditEntry?.auditID, t2.sovereignAuditEntry?.auditID,
            "each turn must derive a unique auditID (turn-unique, not session+verdict only)")
    }

    /// deep-audit P2-17 (2026-07-13): auditID must carry a clock-independent uniqueness
    /// component that distinguishes DISTINCT turns even under a frozen host clock — while
    /// staying a PURE function of the turn (the replay-determinism harness requires the same
    /// turn to re-derive the same entry, so the component is a deterministic content digest,
    /// NOT a UUID). Pre-fix the ID ended in the verdict rawValue (no digest) — the distinct-
    /// turn assertion below reds.
    func testAuditIDCarriesDeterministicContentDigest() async throws {
        let t1 = try await MainActor.run { try Self.drivenTurn(prompt: "One.") }
        let t2 = try await MainActor.run { try Self.drivenTurn(prompt: "Two.") }
        let id1 = try XCTUnwrap(t1.sovereignAuditEntry?.auditID)
        let id2 = try XCTUnwrap(t2.sovereignAuditEntry?.auditID)
        // Trailing component is a lowercase-hex digest (16 chars = 8 bytes), not a UUID.
        let last1 = try XCTUnwrap(id1.split(separator: ".").last.map(String.init))
        XCTAssertEqual(last1.count, 16, "auditID must end in a 16-hex-char content digest")
        XCTAssertTrue(last1.allSatisfy { $0.isHexDigit && !$0.isUppercase },
            "the digest must be lowercase hex, got '\(last1)'")
        XCTAssertNotEqual(id1, id2, "distinct turns get distinct auditIDs")
        XCTAssertNotEqual(id1.split(separator: ".").last, id2.split(separator: ".").last,
            "the digest component must differ for distinct turns (clock-independent)")
    }

    /// deep-audit P2-17 (2026-07-13, semantic): the CONTENT digest — not just turnID — must
    /// discriminate. Holds turnID CONSTANT (same session + same frozen recordedAt) and varies only
    /// the content (snapshotRef / actionRefs), proving distinct-content → distinct auditID even
    /// under a frozen clock; and that byte-identical inputs → identical auditID (idempotent replay).
    /// The drivenTurn tests can't isolate this because each turn runs at a distinct wall-clock time.
    /// Reversal: a derivation that digests turnID alone reds the distinct-content assertions.
    func testAuditIDContentDigestDiscriminatesUnderAFrozenTurnID() {
        let turnID = "sess.frozen#123456.0"   // same session + same recordedAt tick for all
        let verdictID = "verdict.sess.frozen"
        let level = "advisory"

        let base = BASEBrainRuntimeCoordinator.deriveSovereignAuditID(
            turnID: turnID, verdictID: verdictID, verdictLevelRaw: level,
            snapshotRef: "snap.A", actionRefs: ["commit.1"])

        // Idempotent: byte-identical inputs (the SAME turn) → the SAME auditID.
        let baseAgain = BASEBrainRuntimeCoordinator.deriveSovereignAuditID(
            turnID: turnID, verdictID: verdictID, verdictLevelRaw: level,
            snapshotRef: "snap.A", actionRefs: ["commit.1"])
        XCTAssertEqual(base, baseAgain, "identical turn inputs must re-derive an identical auditID")

        // Distinct content at the SAME turnID → distinct auditID (via snapshotRef).
        let diffSnapshot = BASEBrainRuntimeCoordinator.deriveSovereignAuditID(
            turnID: turnID, verdictID: verdictID, verdictLevelRaw: level,
            snapshotRef: "snap.B", actionRefs: ["commit.1"])
        XCTAssertNotEqual(base, diffSnapshot,
            "a different thought-fold (snapshotRef) at the SAME frozen turnID must give a distinct auditID")

        // Distinct content at the SAME turnID → distinct auditID (via actionRefs).
        let diffActions = BASEBrainRuntimeCoordinator.deriveSovereignAuditID(
            turnID: turnID, verdictID: verdictID, verdictLevelRaw: level,
            snapshotRef: "snap.A", actionRefs: ["commit.2"])
        XCTAssertNotEqual(base, diffActions,
            "different commit/warrant tokens at the SAME frozen turnID must give a distinct auditID")

        // The trailing digest is 16 lowercase hex (8-byte SHA-256), not a UUID.
        let last = String(base.split(separator: ".").last ?? "")
        XCTAssertEqual(last.count, 16)
        XCTAssertTrue(last.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    // MARK: - 1. Real turn → signed + chained

    func testRecordsSignedChainedEntryFromRealTurn() async throws {
        let turn = try await MainActor.run { try Self.drivenTurn() }
        // The cascade MUST produce a per-turn sovereign entry — its
        // absence would itself be a regression (SovereignCommit:1621)。
        let entry = try XCTUnwrap(
            turn.sovereignAuditEntry,
            "the cascade must emit a per-turn sovereignAuditEntry")
        XCTAssertEqual(entry.signature, "",
            "the coordinator emits it UNSIGNED — the ledger signs it")
        XCTAssertEqual(entry.schemaVersion,
                       BASSovereignAuditEntry.hardenedSchemaVersion,
                       "per-turn entry uses the 1.2.0 injective form")

        let sink = makeInMemorySink()
        let outcome = await sink.recordTurn(turn)
        XCTAssertTrue(outcome.appended,
            "a well-formed entry must sign + chain: \(outcome.reason ?? "")")
        XCTAssertEqual(outcome.schemaVersion, "1.2.0")
        let head = try XCTUnwrap(outcome.selfHash)
        XCTAssertFalse(head.isEmpty)
        let count = await sink.appendedCount()
        XCTAssertEqual(count, 1)
        let verified = await sink.verifyChain()
        XCTAssertTrue(verified,
            "the keyed ledger must verify its own signature over the chain")
    }

    // MARK: - 2. Chaining across turns

    func testChainLinksAcrossTurns() async throws {
        let sink = makeInMemorySink()
        let t1 = try await MainActor.run {
            try Self.drivenTurn(prompt: "First turn prompt.") }
        let t2 = try await MainActor.run {
            try Self.drivenTurn(prompt: "Second, distinct prompt.") }
        let o1 = await sink.recordTurn(t1)
        let o2 = await sink.recordTurn(t2)
        XCTAssertTrue(o1.appended && o2.appended)
        XCTAssertNotEqual(o1.selfHash, o2.selfHash,
            "each append advances the chain head")
        let count = await sink.appendedCount()
        XCTAssertEqual(count, 2)
        let head = await sink.headHash()
        XCTAssertEqual(head, o2.selfHash)
        let verified = await sink.verifyChain()
        XCTAssertTrue(verified)
    }

    // MARK: - 3. Byte-safety (result untouched)

    func testRecordingDoesNotMutateTheTurnResult() async throws {
        let turn = try await MainActor.run { try Self.drivenTurn() }
        let sink = makeInMemorySink()
        _ = await sink.recordTurn(turn)
        // Value semantics: the caller's entry is unchanged — still
        // signature-empty (we signed a COPY inside the ledger)。
        XCTAssertEqual(turn.sovereignAuditEntry?.signature, "",
            "recording must not sign the host's in-hand entry — " +
            "the ledger persists a signed copy, the turn result is " +
            "a pure value side-channel (red line 7 / ADR-014)")
    }

    // MARK: - 4. Host ledger is the signing authority

    func testInboundSignatureIsClearedAndReSigned() async throws {
        var turn = try await MainActor.run { try Self.drivenTurn() }
        // Simulate an entry that arrived pre-signed by some OTHER
        // authority — the host ledger must still accept it by
        // clearing + re-signing under the host key (not reject it)。
        turn.sovereignAuditEntry?.signature = "Zm9yZ2VkLXNpZ25hdHVyZQ=="
        let sink = makeInMemorySink()
        let outcome = await sink.recordTurn(turn)
        XCTAssertTrue(outcome.appended,
            "an inbound (foreign) signature must be cleared + re-signed, " +
            "not rejected: \(outcome.reason ?? "")")
        let verified = await sink.verifyChain()
        XCTAssertTrue(verified)
    }

    // MARK: - 5. Cross-restart continuity (file key + SQLite)

    func testReferenceHostRehydratesAndAppendsOntoPersistedHead() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("sovereign-sink-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let keyURL = dir.appendingPathComponent("host.key")
        let dbPath = dir.appendingPathComponent("ledger.sqlite").path

        let turn1 = try await MainActor.run { try Self.drivenTurn() }
        let headAfterFirst: String?
        do {
            let sink = try BASSovereignLedgerHostSink.makeReferenceHost(
                keyURL: keyURL, storagePath: dbPath)
            let outcome = await sink.recordTurn(turn1)
            XCTAssertTrue(outcome.appended)
            headAfterFirst = outcome.selfHash
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path),
            "the generated key must persist for reload")

        // Rebuild from the SAME key + db — rehydrate the chain。
        let turn2 = try await MainActor.run {
            try Self.drivenTurn(prompt: "Post-restart turn.") }
        let sink2 = try BASSovereignLedgerHostSink.makeReferenceHost(
            keyURL: keyURL, storagePath: dbPath)
        let rehydratedVerified = await sink2.verifyChain()
        XCTAssertTrue(rehydratedVerified,
            "the persisted chain must verify under the reloaded key")
        let outcome2 = await sink2.recordTurn(turn2)
        XCTAssertTrue(outcome2.appended,
            "a reloaded host must append onto the persisted head")
        XCTAssertNotEqual(outcome2.selfHash, headAfterFirst,
            "the new append chains onto — not over — the persisted head")
        let stillVerified = await sink2.verifyChain()
        XCTAssertTrue(stillVerified)
    }
}
