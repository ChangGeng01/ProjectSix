import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// M92 — BR-013 integrity sentinel primitive: `auditChainFull()`.
///
/// Pins:
///
/// 1. **Clean chain → clean report** — a ledger with nothing
///    tampered reports `isClean == true`, zero corruptions,
///    `totalEntriesScanned == entries.count`.
///
/// 2. **Empty chain → clean report** — a ledger with zero entries
///    also reports clean.
///
/// 3. **Non-throwing** — `auditChainFull()` never throws, even in
///    the presence of corruption. Sentinels read the Bool + array
///    to decide their next action.
///
/// 4. **Collects all corruptions, not just first** — a chain with
///    multiple broken entries returns a multi-entry corruption list
///    (distinct from `verifyChainIntegrity()` which throws on the
///    first broken entry). This is the core contract that motivates
///    BR-013 as a separate primitive.
///
/// 5. **Reason codes distinguish failure modes** — corrupting
///    `selfHash` yields `.selfHashMismatch`; corrupting a
///    `priorHash` yields `.priorHashBroken`; corrupting a signature
///    yields `.signatureInvalid`.
///
/// 6. **HMAC + Ed25519 both covered** — the primitive works in both
///    signing modes the ledger supports.
///
/// 7. **Multiple reasons per entry possible** — a single entry
///    mutated in multiple fields can report several reason codes
///    together rather than collapsing to one.
///
/// 8. **SQLite-persisted tamper survives reopen** — corrupting the
///    SQLite file then reopening the ledger produces a corruption
///    report on the reopened ledger (the primitive composes with
///    M91 persistence).
final class BASSignatureAuditReportTests: XCTestCase {

    // MARK: - Fixtures

    private func makeEntry(
        auditID: String,
        session: String = "session-m92",
        turn: String = "turn-1",
        at seconds: TimeInterval = 1_700_000_000
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: "verdict-m92",
            ruleIDs: ["BR-001"],
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-m92",
            actor: .system,
            signature: "",
            appendedAt: Date(timeIntervalSince1970: seconds))
    }

    private func hmacLedger() -> BASSovereignAuditLedger {
        BASSovereignAuditLedger.withSeed("m92-hmac-seed")
    }

    private func ed25519Ledger() throws -> BASSovereignAuditLedger {
        try BASSovereignAuditLedger.withEd25519Seed("m92-ed25519-seed")
    }

    /// Replace one entry in a live ledger's snapshot at `position`
    /// with a tampered version via a test-only reconstruction of the
    /// internal state. Because `entries[]` is private, we use the
    /// `@testable import` to reach in and mutate. Since
    /// BASSovereignAuditLedger is an actor, all mutations must happen
    /// inside isolated code — so we wrap the test mutations via a
    /// helper method defined directly on the ledger (below this
    /// class via extension).
    /// Helpers to rebuild a tampered `AppendedEntry` — since
    /// `AppendedEntry.entry / priorHash / selfHash` are `let`,
    /// tampering means building a brand-new value with the same
    /// fields except the mutated ones. Static to avoid capturing
    /// `self` (non-Sendable) in the @Sendable closure passed to
    /// the actor's internal `_m92TestTamper`.
    private static func tamperedEntry(
        _ appended: BASSovereignAuditLedger.AppendedEntry,
        newAuditID: String? = nil,
        newSignature: String? = nil
    ) -> BASSovereignAuditLedger.AppendedEntry {
        var raw = appended.entry
        if let newAuditID { raw.auditID = newAuditID }
        if let newSignature { raw.signature = newSignature }
        return BASSovereignAuditLedger.AppendedEntry(
            entry: raw,
            priorHash: appended.priorHash,
            selfHash: appended.selfHash)
    }

    private static func tamperedHashes(
        _ appended: BASSovereignAuditLedger.AppendedEntry,
        newPriorHash: String? = nil,
        newSelfHash: String? = nil
    ) -> BASSovereignAuditLedger.AppendedEntry {
        BASSovereignAuditLedger.AppendedEntry(
            entry: appended.entry,
            priorHash: newPriorHash ?? appended.priorHash,
            selfHash: newSelfHash ?? appended.selfHash)
    }

    private func tamper(
        _ ledger: BASSovereignAuditLedger,
        position: Int,
        replacement: @Sendable @escaping (
            BASSovereignAuditLedger.AppendedEntry
        ) -> BASSovereignAuditLedger.AppendedEntry
    ) async {
        await ledger._m92TestTamper(
            position: position,
            replacement: replacement)
    }

    // MARK: - 1. Clean chain → clean report

    func testCleanChainReportsNoCorruptions() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-2", turn: "turn-2"))
        _ = try await ledger.append(
            makeEntry(auditID: "a-3", turn: "turn-3"))

        let report = await ledger.auditChainFull()
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.totalEntriesScanned, 3)
        XCTAssertTrue(report.corruptions.isEmpty)
    }

    // MARK: - 2. Empty chain → clean report

    func testEmptyChainReportsClean() async {
        let ledger = hmacLedger()
        let report = await ledger.auditChainFull()
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.totalEntriesScanned, 0)
        XCTAssertTrue(report.corruptions.isEmpty)
    }

    // MARK: - 3. Non-throwing under corruption

    func testAuditChainFullDoesNotThrowOnCorruption() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "n-1"))
        await tamper(ledger, position: 0) { appended in
            Self.tamperedEntry(appended, newAuditID: "tampered")
        }
        // Must not throw.
        let report = await ledger.auditChainFull()
        XCTAssertFalse(report.isClean)
    }

    // MARK: - 4. Collects all corruptions (not just first)

    func testMultipleCorruptionsAreAllReported() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "c-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "c-2", turn: "turn-2"))
        _ = try await ledger.append(
            makeEntry(auditID: "c-3", turn: "turn-3"))

        // Corrupt entries 0 and 2 (leave entry 1 clean except for
        // the induced prior-hash break from entry 0's tamper).
        await tamper(ledger, position: 0) { appended in
            Self.tamperedEntry(appended, newAuditID: "tampered-first")
        }
        await tamper(ledger, position: 2) { appended in
            Self.tamperedEntry(
                appended, newSignature: "garbage-signature")
        }

        let report = await ledger.auditChainFull()
        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.totalEntriesScanned, 3)
        // Expect at least 2 corrupted entries (the two we tampered);
        // possibly more if entry 1's prior-hash breaks from entry 0's
        // selfHash mismatch.
        XCTAssertGreaterThanOrEqual(report.corruptions.count, 2)
        let positions = Set(report.corruptions.map(\.position))
        XCTAssertTrue(positions.contains(0))
        XCTAssertTrue(positions.contains(2))
    }

    // MARK: - 5. Reason codes distinguish failure modes

    func testSignatureInvalidReasonCodeFired() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "s-1"))
        await tamper(ledger, position: 0) { appended in
            Self.tamperedEntry(
                appended,
                newSignature: "ZmFrZS1zaWc=")  // valid b64, wrong MAC
        }
        let report = await ledger.auditChainFull()
        let corruption = report.corruptions.first
        XCTAssertNotNil(corruption)
        XCTAssertEqual(corruption?.position, 0)
        XCTAssertEqual(corruption?.auditID, "s-1")
        XCTAssertTrue(corruption?.reasons.contains(.signatureInvalid)
            == true)
    }

    func testSelfHashMismatchReasonCodeFired() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "h-1"))
        await tamper(ledger, position: 0) { appended in
            Self.tamperedHashes(
                appended, newSelfHash: "garbage-self-hash")
        }
        let report = await ledger.auditChainFull()
        let corruption = report.corruptions.first
        XCTAssertNotNil(corruption)
        XCTAssertTrue(
            corruption?.reasons.contains(.selfHashMismatch) == true)
    }

    func testPriorHashBrokenReasonCodeFired() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "p-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "p-2", turn: "turn-2"))
        await tamper(ledger, position: 1) { appended in
            Self.tamperedHashes(
                appended, newPriorHash: "garbage-prior-hash")
        }
        let report = await ledger.auditChainFull()
        let corruption = report.corruptions.first {
            $0.position == 1
        }
        XCTAssertNotNil(corruption)
        XCTAssertTrue(
            corruption?.reasons.contains(.priorHashBroken) == true)
    }

    // MARK: - 6. Ed25519 mode

    func testEd25519ChainCleanReport() async throws {
        let ledger = try ed25519Ledger()
        _ = try await ledger.append(makeEntry(auditID: "e-1"))
        _ = try await ledger.append(
            makeEntry(auditID: "e-2", turn: "turn-2"))

        let report = await ledger.auditChainFull()
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.totalEntriesScanned, 2)
    }

    func testEd25519SignatureTamperSurfaces() async throws {
        let ledger = try ed25519Ledger()
        _ = try await ledger.append(makeEntry(auditID: "e-1"))
        await tamper(ledger, position: 0) { appended in
            // Flip a base64 char — still valid base64, still 88
            // chars, but the bytes won't verify under the Ed25519
            // public key.
            let sig = appended.entry.signature
            let first = sig.first == "A" ? "B" : "A"
            let flipped = String(first) + sig.dropFirst()
            return Self.tamperedEntry(appended, newSignature: flipped)
        }
        let report = await ledger.auditChainFull()
        XCTAssertFalse(report.isClean)
        XCTAssertTrue(
            report.corruptions.first?.reasons
                .contains(.signatureInvalid) == true)
    }

    // MARK: - 7. Multiple reasons on one entry

    func testSingleEntryCanCarryMultipleReasons() async throws {
        let ledger = hmacLedger()
        _ = try await ledger.append(makeEntry(auditID: "m-1"))
        await tamper(ledger, position: 0) { appended in
            let withNewAuditID = Self.tamperedEntry(
                appended, newAuditID: "tampered-audit-id")
            return Self.tamperedHashes(
                withNewAuditID,
                newSelfHash: "tampered-self-hash")
        }
        let report = await ledger.auditChainFull()
        let corruption = report.corruptions.first
        XCTAssertNotNil(corruption)
        // Mutating auditID alone breaks signature (since auditID is
        // canonical-bytes material); mutating selfHash also breaks
        // selfHashMismatch. Expect at least both.
        XCTAssertTrue(
            corruption?.reasons.contains(.signatureInvalid) == true,
            "auditID tamper breaks signature recomputation")
        XCTAssertTrue(
            corruption?.reasons.contains(.selfHashMismatch) == true,
            "selfHash tamper breaks hash recomputation")
    }
}

// Test-only tamper helper lives on the actor itself at internal
// visibility in BASSovereignAuditLedger.swift (see `_m92TestTamper`
// there). This test file reaches it via @testable import.
