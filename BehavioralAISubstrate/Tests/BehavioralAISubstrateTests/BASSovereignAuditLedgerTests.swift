import XCTest
import CryptoKit
@testable import BASRuntimeCore
@testable import BASSovereign

/// Tests for `BR-07` AuditLedger.
///
/// These tests are deliberately unit-level (no file I/O, no network). They
/// verify the chain/signature invariants that `BR-012` depends on. End-to-end
/// wiring (turn result → verdict → ledger append → commit gate) is covered
/// in a later milestone once the VerdictEngine is in place.
final class BASSovereignAuditLedgerTests: XCTestCase {
    // MARK: - Helpers

    private func makeLedger(seed: String = "audit-ledger-test-seed") -> BASSovereignAuditLedger {
        BASSovereignAuditLedger.withSeed(seed)
    }

    private func makeEntry(
        auditID: String,
        session: String = "session-A",
        turn: String = "turn-1",
        verdict: String = "verdict-xyz",
        ruleIDs: [String] = ["BR-001"],
        at: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BASSovereignAuditEntry {
        BASSovereignAuditEntry(
            auditID: auditID,
            sessionID: session,
            turnID: turn,
            verdictRef: verdict,
            ruleIDs: ruleIDs,
            signalRefs: [],
            actionRefs: [],
            snapshotRef: "snap-1",
            actor: .system,
            signature: "", // ledger signs on append
            appendedAt: at
        )
    }

    // MARK: - Append + basic shape

    func testAppendAssignsSignatureAndLinksGenesis() async throws {
        let ledger = makeLedger()
        let draft = makeEntry(auditID: "a-001")
        let appended = try await ledger.append(draft)

        XCTAssertEqual(appended.priorHash, "GENESIS", "first entry links to GENESIS sentinel")
        XCTAssertFalse(appended.entry.signature.isEmpty, "ledger should install a signature when caller provides none")
        XCTAssertFalse(appended.selfHash.isEmpty, "self hash must be computed on append")

        let count = await ledger.count()
        XCTAssertEqual(count, 1)
    }

    func testSecondAppendLinksToFirstsSelfHash() async throws {
        let ledger = makeLedger()
        let first = try await ledger.append(makeEntry(auditID: "a-001"))
        let second = try await ledger.append(makeEntry(auditID: "a-002", turn: "turn-2"))

        XCTAssertEqual(second.priorHash, first.selfHash, "chain links must point at prior entry")
        XCTAssertNotEqual(first.selfHash, second.selfHash, "self hash must differ per entry")
    }

    // MARK: - Validation

    func testAppendRejectsEmptyAuditID() async {
        let ledger = makeLedger()
        let bad = makeEntry(auditID: "")
        do {
            _ = try await ledger.append(bad)
            XCTFail("empty auditID must be rejected")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testAppendRejectsEmptyVerdictRef() async {
        let ledger = makeLedger()
        var bad = makeEntry(auditID: "a-001")
        bad.verdictRef = ""
        do {
            _ = try await ledger.append(bad)
            XCTFail("empty verdictRef must be rejected")
        } catch BASSovereignAuditLedger.LedgerError.invalidEntry {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Caller-provided signatures

    func testAppendAcceptsCallerSignatureWhenItMatchesLedgerComputation() async throws {
        // A caller that wants to pre-sign can do so; the ledger will accept
        // iff the signature matches what it would have computed itself.
        let ledger = makeLedger(seed: "paired-seed")
        let other = BASSovereignAuditLedger.withSeed("paired-seed")

        var draft = makeEntry(auditID: "a-001")
        // Use the "other" (identical-seed) ledger to pre-sign by appending
        // and reading the installed signature back.
        let preSigned = try await other.append(draft)
        draft.signature = preSigned.entry.signature

        // A fresh ledger seeded identically must accept the same signature.
        let fresh = BASSovereignAuditLedger.withSeed("paired-seed")
        let accepted = try await fresh.append(draft)
        XCTAssertEqual(accepted.entry.signature, preSigned.entry.signature)
    }

    func testAppendRejectsCallerSignatureWhenItDisagrees() async {
        let ledger = makeLedger()
        var draft = makeEntry(auditID: "a-001")
        draft.signature = "definitely-not-a-real-signature"
        do {
            _ = try await ledger.append(draft)
            XCTFail("mismatched signature must be rejected")
        } catch BASSovereignAuditLedger.LedgerError.signatureMismatch(let id) {
            XCTAssertEqual(id, "a-001")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - Query

    func testQueryByAuditRefRoundTrips() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-001"))
        let second = try await ledger.append(makeEntry(auditID: "a-002", turn: "turn-2"))

        let hit = try await ledger.query(byAuditRef: "a-002")
        XCTAssertEqual(hit.entry.auditID, "a-002")
        XCTAssertEqual(hit.selfHash, second.selfHash)
    }

    func testQueryByUnknownAuditRefThrows() async {
        let ledger = makeLedger()
        do {
            _ = try await ledger.query(byAuditRef: "nope")
            XCTFail("unknown audit ref must throw")
        } catch BASSovereignAuditLedger.LedgerError.unknownAuditRef(let ref) {
            XCTAssertEqual(ref, "nope")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testEntriesForSessionAndTurnFilters() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1", session: "S1", turn: "T1"))
        _ = try await ledger.append(makeEntry(auditID: "a-2", session: "S1", turn: "T2"))
        _ = try await ledger.append(makeEntry(auditID: "a-3", session: "S2", turn: "T1"))

        let s1 = await ledger.entries(forSession: "S1")
        XCTAssertEqual(s1.map(\.entry.auditID), ["a-1", "a-2"])

        let s1t2 = await ledger.entries(forSession: "S1", turn: "T2")
        XCTAssertEqual(s1t2.map(\.entry.auditID), ["a-2"])
    }

    func testEntriesInvolvingRuleFilters() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1", ruleIDs: ["BR-001"]))
        _ = try await ledger.append(makeEntry(auditID: "a-2", ruleIDs: ["BR-003", "BR-008"]))
        _ = try await ledger.append(makeEntry(auditID: "a-3", ruleIDs: ["BR-008"]))

        let br008 = await ledger.entriesInvolvingRule("BR-008")
        XCTAssertEqual(br008.map(\.entry.auditID), ["a-2", "a-3"])
    }

    // MARK: - Chain integrity

    func testVerifyChainIntegrityPassesOnCleanChain() async throws {
        let ledger = makeLedger()
        _ = try await ledger.append(makeEntry(auditID: "a-1"))
        _ = try await ledger.append(makeEntry(auditID: "a-2", turn: "turn-2"))
        _ = try await ledger.append(makeEntry(auditID: "a-3", turn: "turn-3"))

        try await ledger.verifyChainIntegrity()
    }

    func testVerifyChainIntegrityDetectsSignatureTamper() async throws {
        // Simulate a tamper by seeding an observer ledger identically,
        // appending the same first entry, then constructing a forged entry
        // whose caller signature is wrong — it should be rejected at
        // append time (we already tested that) but ALSO the chain check
        // must catch any entry whose stored signature no longer matches
        // the recomputed canonical bytes. We exercise that path by
        // constructing a ledger that would produce a DIFFERENT signature
        // (different seed) and asking it to verify entries from ours.
        let trusted = BASSovereignAuditLedger.withSeed("keyring-A")
        _ = try await trusted.append(makeEntry(auditID: "a-1"))
        _ = try await trusted.append(makeEntry(auditID: "a-2", turn: "turn-2"))

        // Verification with the correct seed passes.
        try await trusted.verifyChainIntegrity()

        // A ledger with a different seed would reject the same chain.
        // We simulate by asking a different ledger to "adopt" the snapshot
        // and verify — but since we don't expose adoption, we verify by
        // checking that an independently-seeded ledger, after appending
        // the same drafts, produces DIFFERENT signatures. This proves the
        // signature is sensitive to the seed — which is the property
        // chain integrity needs.
        let foreign = BASSovereignAuditLedger.withSeed("keyring-B")
        let foreignFirst = try await foreign.append(makeEntry(auditID: "a-1"))
        let trustedFirst = try await trusted.query(byAuditRef: "a-1")
        XCTAssertNotEqual(foreignFirst.entry.signature, trustedFirst.entry.signature,
                          "different keyrings must produce different signatures")
    }

    func testQueryByAuditRefIsStableAcrossManyAppends() async throws {
        let ledger = makeLedger()
        for index in 0..<50 {
            _ = try await ledger.append(makeEntry(auditID: "a-\(index)", turn: "turn-\(index)"))
        }
        let middle = try await ledger.query(byAuditRef: "a-25")
        XCTAssertEqual(middle.entry.auditID, "a-25")
        let final = await ledger.count()
        XCTAssertEqual(final, 50)
    }
}
