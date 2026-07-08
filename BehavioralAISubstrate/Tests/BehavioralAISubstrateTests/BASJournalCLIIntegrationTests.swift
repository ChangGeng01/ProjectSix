// MARK: - BASJournalCLIIntegrationTests
//
// End-to-end verification of "The Ledger" (#20 first daily workload). Spawns the real
// BASJournalCLI binary against a THROWAWAY journal dir (QINAO_JOURNAL_DIR) and asserts the
// sovereignty loop: add → recall (paginated full-history read) → forget (tombstone +
// secure-deleted content) → recall-no-longer-returns-it. NOT tautological — it drives the
// live event-sourced memory + deletion-doctrine path the workload exists to fire.

#if os(macOS)
import XCTest
import Foundation

final class BASJournalCLIIntegrationTests: XCTestCase {

    private func cliBinaryURL() -> URL? {
        let candidates = [
            ".build/debug/BASJournalCLI",
            ".build/release/BASJournalCLI",
            ".build/arm64-apple-macosx/debug/BASJournalCLI",
            ".build/x86_64-apple-macosx/debug/BASJournalCLI",
        ]
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        for path in candidates {
            let url = URL(fileURLWithPath: cwd).appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private struct CLIResult { let stdout: String; let stderr: String; let exit: Int32 }

    private func run(_ args: [String], journalDir: URL) throws -> CLIResult {
        guard let binary = cliBinaryURL() else {
            throw XCTSkip("BASJournalCLI binary not found — run `swift build` first.")
        }
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["QINAO_JOURNAL_DIR"] = journalDir.path
        p.environment = env
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        // Drain both pipes before waitUntilExit so a chatty child can't dead-lock on a full
        // pipe buffer (outputs here are tiny, but read-then-wait is the correct discipline).
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return CLIResult(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exit: p.terminationStatus)
    }

    /// Locate the system sqlite3 CLI (used only to tamper the ledger in the tamper-detection
    /// test). Skips the test if unavailable rather than failing spuriously.
    private func sqlite3BinaryURL() -> URL? {
        for path in ["/usr/bin/sqlite3", "/opt/homebrew/bin/sqlite3", "/usr/local/bin/sqlite3"] {
            if FileManager.default.fileExists(atPath: path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    @discardableResult
    private func sqlite3Exec(_ db: URL, _ sql: String) throws -> Bool {
        guard let bin = sqlite3BinaryURL() else { return false }
        let p = Process()
        p.executableURL = bin
        p.arguments = [db.path, sql]
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    func testSovereigntyLoopAddRecallForget() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        // First touch seeds 3 marathon threads.
        let seeded = try run(["count"], journalDir: dir)
        XCTAssertEqual(seeded.exit, 0)
        XCTAssertTrue(seeded.stdout.contains("3 entries"), "first run seeds 3: \(seeded.stdout)")

        // add a distinctive entry (a fresh process — proves cross-process persistence).
        let secret = "H14-pagination-fail-closed-\(Int.random(in: 1000...9999))"
        let added = try run(["add", secret], journalDir: dir)
        XCTAssertEqual(added.exit, 0)
        XCTAssertTrue(added.stdout.contains("logged"), added.stdout)

        // recall must return the entry's CONTENT across processes (content sidecar, since
        // the event log persists digest-only) — a filtered recall finds exactly it.
        let recalled = try run(["recall", "fail-closed"], journalDir: dir)
        XCTAssertTrue(recalled.stdout.contains(secret),
            "recall must return real content cross-process (got: \(recalled.stdout))")

        // Grab the id prefix, forget it, and prove it's gone from BOTH projection + content.
        let idPrefix = recalled.stdout.split(separator: "\n").first
            .map { String($0.prefix(8)) } ?? ""
        XCTAssertFalse(idPrefix.isEmpty)
        let forgot = try run(["forget", idPrefix], journalDir: dir)
        XCTAssertTrue(forgot.stdout.contains("verified gone"),
            "forget must verify the entry is gone (deletion doctrine): \(forgot.stdout)")

        let afterForget = try run(["recall", "fail-closed"], journalDir: dir)
        XCTAssertFalse(afterForget.stdout.contains(secret),
            "forgotten entry must NOT resurface in recall (H11 tombstone): \(afterForget.stdout)")

        // The secure-deleted content file must be physically gone from disk.
        let contentDir = dir.appendingPathComponent("content")
        let survivors = (try? FileManager.default.contentsOfDirectory(atPath: contentDir.path)) ?? []
        XCTAssertFalse(survivors.contains { $0.hasPrefix(idPrefix) },
            "forgotten entry's content file must be secure-deleted from disk")
    }

    // MARK: - Increment 2: the Ed25519 sovereign audit ledger

    /// add → the action is sealed into the Ed25519 hash chain, and `ledger` verifies it intact.
    /// This fires M87 (Ed25519 signing), M91 (SQLite cross-process persistence), and the real
    /// chain-integrity walk — not a tautology: the seal is signed on one process and verified
    /// on another reading the same on-disk chain.
    func testAddSealsIntoLedgerAndVerifies() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        // A fresh add (seeds 3 unsealed sample threads, then seals THIS action).
        let added = try run(["add", "increment-2 ledger seal probe"], journalDir: dir)
        XCTAssertEqual(added.exit, 0)
        XCTAssertTrue(added.stdout.contains("sealed"),
            "add must report an Ed25519 seal: \(added.stdout)")

        // A separate process re-opens the ledger.sqlite and verifies the whole chain.
        let ledger = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(ledger.exit, 0, "healthy chain must verify: \(ledger.stdout)\(ledger.stderr)")
        XCTAssertTrue(ledger.stdout.contains("chain INTACT"),
            "ledger must report the chain intact: \(ledger.stdout)")
        XCTAssertTrue(ledger.stdout.contains("admit:governed"),
            "the add must appear as an admit seal: \(ledger.stdout)")

        // The persisted ledger file actually exists on disk (cross-boot record).
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("ledger.sqlite").path),
            "the sovereign ledger must persist to disk")
    }

    /// forget → an append-only tombstone seal is added; the content is gone but the RECORD of
    /// the deletion survives (a deleted sovereign entry is provably deleted, not silently gone).
    func testForgetSealsTombstoneIntoLedger() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let secret = "ledger-forget-seal-\(Int.random(in: 1000...9999))"
        _ = try run(["add", secret], journalDir: dir)

        let recalled = try run(["recall", "forget-seal"], journalDir: dir)
        let idPrefix = recalled.stdout.split(separator: "\n").first
            .map { String($0.prefix(8)) } ?? ""
        XCTAssertFalse(idPrefix.isEmpty)

        let forgot = try run(["forget", idPrefix], journalDir: dir)
        XCTAssertEqual(forgot.exit, 0)
        XCTAssertTrue(forgot.stdout.contains("forget:tombstoned"),
            "forget must report a tombstone seal: \(forgot.stdout)")

        let ledger = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(ledger.exit, 0)
        XCTAssertTrue(ledger.stdout.contains("admit:governed")
            && ledger.stdout.contains("forget:tombstoned"),
            "the ledger must record BOTH the add and the forget seals: \(ledger.stdout)")
    }

    /// TAMPER TEST (the teeth): corrupt a signature in ledger.sqlite out-of-band, then verify
    /// the `ledger` command FAILS CLOSED (exit 1). Proves the tamper-evidence is real — if the
    /// chain verification were decorative, this would still exit 0 and the test would catch it.
    func testLedgerTamperIsDetectedFailClosed() throws {
        guard sqlite3BinaryURL() != nil else {
            throw XCTSkip("sqlite3 CLI not available — cannot tamper the ledger out-of-band.")
        }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["add", "tamper-detection probe"], journalDir: dir)

        // Sanity: the healthy chain verifies before we tamper.
        let healthy = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(healthy.exit, 0, "pre-tamper chain must be intact: \(healthy.stdout)")

        // Corrupt every entry's signature to a valid-base64-but-wrong value (decodes cleanly,
        // but is NOT a valid Ed25519 signature) so the signature check — not a decode error —
        // is what rejects it.
        let db = dir.appendingPathComponent("ledger.sqlite")
        let tampered = try sqlite3Exec(db, "UPDATE audit_entries SET signature='dGFtcGVy';")
        XCTAssertTrue(tampered, "sqlite3 tamper UPDATE must succeed")

        let after = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(after.exit, 1,
            "a tampered ledger MUST fail closed (exit 1), got exit \(after.exit): "
            + "\(after.stdout)\(after.stderr)")
        XCTAssertTrue(after.stderr.contains("INTEGRITY BROKEN"),
            "the failure must name the integrity break: \(after.stderr)")
    }

    /// TAIL-TRUNCATION TEST (the second set of teeth). A signature UPDATE is the EASY tamper —
    /// the priorHash+signature walk catches it. The dangerous tamper is DELETING tail rows: the
    /// surviving prefix is internally perfect (every link + signature verifies), so the naive
    /// chain walk reports "intact". This asserts the CLI catches truncation via the segment
    /// high-water cross-check — both a partial truncation and truncation-to-completely-empty.
    /// Without the fix, `ledger` would exit 0 here and this test would fail, exposing the hole.
    func testLedgerTailTruncationIsDetectedFailClosed() throws {
        guard sqlite3BinaryURL() != nil else {
            throw XCTSkip("sqlite3 CLI not available — cannot truncate the ledger out-of-band.")
        }
        // Case A: partial truncation (2 seals → delete the last).
        let dirA = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dirA) }
        _ = try run(["add", "truncation probe one"], journalDir: dirA)
        _ = try run(["add", "truncation probe two"], journalDir: dirA)
        XCTAssertEqual(try run(["ledger"], journalDir: dirA).exit, 0, "pre-truncation must be intact")

        let dbA = dirA.appendingPathComponent("ledger.sqlite")
        XCTAssertTrue(try sqlite3Exec(dbA,
            "DELETE FROM audit_entries WHERE insertion_order="
            + "(SELECT MAX(insertion_order) FROM audit_entries);"))
        let afterA = try run(["ledger"], journalDir: dirA)
        XCTAssertEqual(afterA.exit, 1,
            "partial tail truncation MUST fail closed (exit 1): \(afterA.stdout)\(afterA.stderr)")
        XCTAssertTrue(afterA.stderr.contains("TRUNCATION"),
            "the failure must name truncation: \(afterA.stderr)")

        // Case B: truncation to COMPLETELY EMPTY (1 seal → delete it). This is the case the
        // substrate's own empty-guard skips; the CLI's high-water check must still catch it.
        let dirB = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dirB) }
        _ = try run(["add", "single entry to erase"], journalDir: dirB)
        let dbB = dirB.appendingPathComponent("ledger.sqlite")
        XCTAssertTrue(try sqlite3Exec(dbB, "DELETE FROM audit_entries;"))
        let afterB = try run(["ledger"], journalDir: dirB)
        XCTAssertEqual(afterB.exit, 1,
            "truncation-to-empty MUST fail closed, not read as a cold start: "
            + "\(afterB.stdout)\(afterB.stderr)")
    }

    // MARK: - Increment 3: the "was I right?" ShadowTrial loop

    /// Extract the first `trial-XXXXXX` id printed by `review` (from "trial-" to whitespace).
    private func firstTrialID(in review: String) -> String? {
        for line in review.split(separator: "\n") {
            guard let r = line.range(of: "trial-") else { continue }
            return String(line[r.lowerBound...].prefix { !$0.isWhitespace })
        }
        return nil
    }

    /// bet opens a shadow trial; a SEPARATE process lists it via `review` (cross-boot — the
    /// coordinator is memory-only, so this exercises the CLI-owned open-trials index) and the
    /// trial event is sealed onto the SAME Ed25519 chain as the journal seals.
    func testBetOpensTrialAndReviewListsItCrossProcess() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let bet = try run(["bet", "DROP sampling-spec draft", "-q", "did latency regress?"],
            journalDir: dir)
        XCTAssertEqual(bet.exit, 0, bet.stdout + bet.stderr)
        XCTAssertTrue(bet.stdout.contains("bet opened"), "bet must open a trial: \(bet.stdout)")

        // Fresh process reads the open bet back.
        let review = try run(["review"], journalDir: dir)
        XCTAssertTrue(review.stdout.contains("DROP sampling-spec draft"),
            "review must re-surface the open bet cross-process: \(review.stdout)")
        XCTAssertTrue(review.stdout.contains("did latency regress?"),
            "review must show the open question: \(review.stdout)")

        // The trial event sealed onto the same chain; chain still verifies.
        let ledger = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(ledger.exit, 0, "chain must stay intact with trial events: \(ledger.stderr)")
        XCTAssertTrue(ledger.stdout.contains("shadow_trial"),
            "the trial-opened event must be on the sovereign ledger: \(ledger.stdout)")
    }

    /// `wrong` finalizes via the real public finalize(.failed): the promotion verdict is
    /// FAIL-CLOSED (denied) and the outcome is recalled by `verdict` cross-process. The bet then
    /// no longer shows as open.
    func testWrongFinalizesFailClosedAndVerdictRecalls() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["bet", "DROP sampling-spec", "-q", "did latency regress?"], journalDir: dir)
        let tid = firstTrialID(in: try run(["review"], journalDir: dir).stdout)
        let trialID = try XCTUnwrap(tid, "review must print a trial id")

        let wrong = try run(["wrong", trialID, "latency was flat"], journalDir: dir)
        XCTAssertEqual(wrong.exit, 0, wrong.stdout + wrong.stderr)
        XCTAssertTrue(wrong.stdout.contains("WRONG") && wrong.stdout.contains("failed"),
            "wrong must finalize the trial as failed: \(wrong.stdout)")
        XCTAssertTrue(wrong.stdout.contains("DENIED"),
            "a failed trial's promotion verdict must be fail-closed DENIED: \(wrong.stdout)")

        // verdict recalls the recorded outcome + fail-closed reasons cross-process.
        let verdict = try run(["verdict", trialID], journalDir: dir)
        XCTAssertTrue(verdict.stdout.contains("failed"), verdict.stdout)
        XCTAssertTrue(verdict.stdout.contains("latency was flat"),
            "verdict must show the recorded reason: \(verdict.stdout)")

        // No longer open.
        let review2 = try run(["review"], journalDir: dir)
        XCTAssertTrue(review2.stdout.contains("no open bets"),
            "resolved bet must not remain open: \(review2.stdout)")

        // Chain (now carrying seal-denied + retraction events) still verifies.
        XCTAssertEqual(try run(["ledger"], journalDir: dir).exit, 0)
    }

    /// `right` finalizes via finalize(.passed): the promotion verdict is ALLOWED (a genuinely
    /// passed trial + approved seal — the H9 fail-closed gate's positive-evidence path).
    func testRightFinalizesAllowedVerdict() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["bet", "KEEP fused-MTP take-5", "-q", "held 1.20x?"], journalDir: dir)
        let trialID = try XCTUnwrap(firstTrialID(in: try run(["review"], journalDir: dir).stdout))

        let right = try run(["right", trialID], journalDir: dir)
        XCTAssertEqual(right.exit, 0, right.stdout + right.stderr)
        XCTAssertTrue(right.stdout.contains("RIGHT") && right.stdout.contains("passed"),
            "right must finalize the trial as passed: \(right.stdout)")
        XCTAssertTrue(right.stdout.contains("ALLOWED"),
            "a passed trial + approved seal must ALLOW promotion: \(right.stdout)")

        let verdict = try run(["verdict", trialID], journalDir: dir)
        XCTAssertTrue(verdict.stdout.contains("passed") && verdict.stdout.contains("ALLOWED"),
            verdict.stdout)
        XCTAssertEqual(try run(["ledger"], journalDir: dir).exit, 0)
    }

    /// IDEMPOTENCY (the HIGH review finding): if a resolve's ledger finalize succeeds but the
    /// sidecar write-back fails, the row is left stale-open. A retry must NOT re-finalize (which
    /// would double-seal the append-only chain) — it must consult the authoritative ledger, see
    /// the trial is already terminal, and reconcile. We simulate the torn state by forcing the
    /// sidecar row back to 'pending' out-of-band, then asserting the retry adds ZERO ledger rows.
    func testResolveIsIdempotentAgainstTornSidecar() throws {
        guard sqlite3BinaryURL() != nil else { throw XCTSkip("sqlite3 CLI unavailable") }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["bet", "DROP sampling-spec", "-q", "regressed?"], journalDir: dir)
        let trialID = try XCTUnwrap(firstTrialID(in: try run(["review"], journalDir: dir).stdout))
        _ = try run(["wrong", trialID, "latency flat"], journalDir: dir)

        let ledgerDB = dir.appendingPathComponent("ledger.sqlite")
        let indexDB = dir.appendingPathComponent("trials_index.sqlite")

        func ledgerRowCount() throws -> Int {
            let p = Process(); p.executableURL = sqlite3BinaryURL()
            p.arguments = [ledgerDB.path, "SELECT COUNT(*) FROM audit_entries;"]
            let out = Pipe(); p.standardOutput = out; try p.run(); p.waitUntilExit()
            let s = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
        }

        let before = try ledgerRowCount()
        XCTAssertGreaterThan(before, 0)

        // Simulate the torn state: finalize sealed the terminal event, but the sidecar close
        // "failed" — force the row back to pending.
        XCTAssertTrue(try sqlite3Exec(indexDB,
            "UPDATE trial_index SET state='pending', outcome=NULL;"))

        // Retry: must reconcile, not double-seal.
        let retry = try run(["wrong", trialID, "retry"], journalDir: dir)
        XCTAssertEqual(retry.exit, 0)
        XCTAssertTrue(retry.stdout.contains("already resolved") && retry.stdout.contains("reconciled"),
            "retry must reconcile from the ledger, not re-finalize: \(retry.stdout)")

        let after = try ledgerRowCount()
        XCTAssertEqual(after, before,
            "a reconciled retry MUST NOT append duplicate terminal events (\(before) → \(after))")
        XCTAssertEqual(try run(["ledger"], journalDir: dir).exit, 0, "chain must remain intact")
    }
}
#endif
