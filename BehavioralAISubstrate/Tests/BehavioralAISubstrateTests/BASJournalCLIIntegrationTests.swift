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

    private var cliBinaryURL: URL?

    override func setUpWithError() throws {
        try super.setUpWithError()
        cliBinaryURL = BASJournalCLIBinaryLocator.binaryURL(
            testBundleURL: Bundle(for: Self.self).bundleURL,
            workingDirectory: URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath,
                isDirectory: true))
        try XCTSkipIf(
            cliBinaryURL == nil,
            "BASJournalCLI binary not found — run `swift build` first.")
    }

    private struct CLIResult { let stdout: String; let stderr: String; let exit: Int32 }

    private func run(_ args: [String], journalDir: URL) throws -> CLIResult {
        let binary = try XCTUnwrap(
            cliBinaryURL,
            "setUpWithError must resolve BASJournalCLI before running assertions")
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

    func testCLIBinaryDiscoveryFindsSameBuildSibling() {
        let expected = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
            .appendingPathComponent("BASJournalCLI")

        XCTAssertEqual(cliBinaryURL, expected)
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

        // Increment 4: content lives in a secure_delete-ON SQLite store. After forget, the raw
        // plaintext must be gone from EVERY content.sqlite* file — including the -wal, which the
        // WAL-truncate step exists to scrub (plain secure_delete only zeroes the main DB). This is
        // the real teeth: without the checkpoint(TRUNCATE), the secret would survive in the -wal.
        let plaintextGone = !contentDBContains(dir: dir, needle: secret)
        XCTAssertTrue(plaintextGone,
            "forgotten entry's plaintext must be secure-deleted from all content.sqlite* files")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("content").appendingPathComponent("\(idPrefix)").path),
            "no legacy content file should survive")
    }

    /// True iff the raw `needle` bytes appear in ANY content.sqlite* file (main DB / WAL / SHM).
    private func contentDBContains(dir: URL, needle: String) -> Bool {
        let needleData = Data(needle.utf8)
        for suffix in ["content.sqlite", "content.sqlite-wal", "content.sqlite-shm"] {
            let url = dir.appendingPathComponent(suffix)
            guard let data = try? Data(contentsOf: url) else { continue }
            if data.range(of: needleData) != nil { return true }
        }
        return false
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
        XCTAssertTrue(ledger.stdout.contains("admit|gov2:"),
            "the add must appear as an admit seal carrying the governance verdict: \(ledger.stdout)")

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
        XCTAssertTrue(ledger.stdout.contains("admit|gov2:")
            && ledger.stdout.contains("forget:tombstoned"),
            "the ledger must record BOTH the add (governance verdict) and the forget seals: \(ledger.stdout)")
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

    /// Increment 4: a legacy increment-1 content/<uuid>.txt file is migrated into the secure
    /// SQLite store on first store-open (any command), then the plaintext file is retired — a
    /// MOVE (content preserved), verified before the source is removed.
    func testLegacyContentFileIsMigratedAndRetired() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default

        let contentDir = dir.appendingPathComponent("content")
        try fm.createDirectory(at: contentDir, withIntermediateDirectories: true)
        let legacyText = "legacy-increment1-entry-\(Int.random(in: 1000...9999))"
        let legacyID = UUID().uuidString
        let legacyFile = contentDir.appendingPathComponent("\(legacyID).txt")
        try Data(legacyText.utf8).write(to: legacyFile)

        // Any command opens the content store, which runs the one-time migration.
        let r = try run(["count"], journalDir: dir)
        XCTAssertEqual(r.exit, 0)

        XCTAssertFalse(fm.fileExists(atPath: legacyFile.path),
            "the legacy plaintext file must be retired after migration")
        XCTAssertTrue(contentDBContains(dir: dir, needle: legacyText),
            "the migrated content must now live in the secure SQLite store")
    }

    /// Increment 4 (review HIGH fix): migration is NON-CLOBBERING. If the store already holds an
    /// atom's content, a legacy file for the same atom (e.g. one a concurrent process is
    /// mid-zeroing) must NOT overwrite the correct row — it is retired without a re-import.
    func testMigrationDoesNotClobberExistingStoreContent() throws {
        guard let sqlite3 = sqlite3BinaryURL() else { throw XCTSkip("sqlite3 CLI unavailable") }
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default

        let real = "REAL-content-must-survive-\(Int.random(in: 1000...9999))"
        _ = try run(["add", real], journalDir: dir)

        // Read the atom_id the store keyed THIS content under (add also seeds 3 rows, so filter
        // by our distinctive text to get exactly the real entry's id).
        let p = Process(); p.executableURL = sqlite3
        p.arguments = [dir.appendingPathComponent("content.sqlite").path,
            "SELECT atom_id FROM content WHERE text LIKE 'REAL-content%';"]
        let out = Pipe(); p.standardOutput = out; try p.run(); p.waitUntilExit()
        let atomID = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        XCTAssertFalse(atomID.isEmpty, "should resolve exactly one atom id for the real content")
        XCTAssertNotNil(UUID(uuidString: atomID), "atom id must be a single UUID: '\(atomID)'")

        // Plant a legacy file for the SAME atom with different (clobbering) content.
        let contentDir = dir.appendingPathComponent("content")
        try fm.createDirectory(at: contentDir, withIntermediateDirectories: true)
        let legacyFile = contentDir.appendingPathComponent("\(atomID).txt")
        try Data("CLOBBER-attempt-should-be-ignored".utf8).write(to: legacyFile)

        // Trigger migration.
        _ = try run(["count"], journalDir: dir)

        // The store keeps the REAL content; the clobber attempt never landed; the file is retired.
        let recall = try run(["recall", "REAL-content"], journalDir: dir)
        XCTAssertTrue(recall.stdout.contains(real),
            "the store's real content must survive migration of a same-atom legacy file: \(recall.stdout)")
        XCTAssertFalse(recall.stdout.contains("CLOBBER-attempt"),
            "the legacy file must NOT overwrite the store row")
        XCTAssertFalse(fm.fileExists(atPath: legacyFile.path), "the legacy file must be retired")
    }

    // MARK: - Increment 2b: the L1–L14 governance verdict

    /// Extract the sealed verdictRef from an `add`'s stdout ("sealed <id>  <verdictRef>  (Ed25519…)").
    private func sealedVerdict(in addStdout: String) -> String? {
        for line in addStdout.split(separator: "\n") where line.contains("sealed ") && line.contains("gov2") {
            // token between the id and the "  (Ed25519" suffix
            guard let range = line.range(of: "  (Ed25519") else { continue }
            let head = line[..<range.lowerBound]
            // drop "sealed <8-char-id>  "
            let parts = head.split(separator: " ", omittingEmptySubsequences: true)
            if let idx = parts.firstIndex(of: "sealed"), idx + 2 < parts.count {
                return parts[(idx + 2)...].joined(separator: " ")
            }
        }
        return nil
    }

    /// add now routes the entry through the L1–L14 spine (runTurn) and seals the REAL governance
    /// verdict — not the old hardcoded "admit:governed" assertion. Proves the spine ran (gov2:) and
    /// the chain still verifies with the richer verdictRef.
    func testAddSealsGovernanceVerdictFromSpine() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let added = try run(["add", "DROP sampling-spec draft: 0.88x"], journalDir: dir)
        XCTAssertEqual(added.exit, 0, added.stdout + added.stderr)
        let vref = try XCTUnwrap(sealedVerdict(in: added.stdout),
            "add must seal a gov2 governance verdict from the spine: \(added.stdout)")
        XCTAssertTrue(vref.hasPrefix("admit|gov2:"),
            "verdictRef must be the spine's governance verdict, not the hardcoded assertion: \(vref)")
        XCTAssertTrue(vref.contains("permit:") && vref.contains("risk:"),
            "verdictRef must carry the permit + risk band: \(vref)")
        XCTAssertNotEqual(vref, "admit:governed", "the old hardcoded assertion must be gone")

        // The richer verdictRef must not break increment-2's chain verification.
        XCTAssertEqual(try run(["ledger"], journalDir: dir).exit, 0,
            "the hardened 1.2.0 chain must verify with the governance verdictRef")
    }

    /// The verdict is DETERMINISTIC: the same entry text in two fresh journals seals an identical
    /// verdictRef (the device state is pinned to a constant so the verdict is a function of text
    /// + fixed metadata only — a signed field must not drift across runs).
    func testGovernanceVerdictIsDeterministic() throws {
        func verdict(for text: String) throws -> String {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            return try XCTUnwrap(sealedVerdict(in: try run(["add", text], journalDir: dir).stdout))
        }
        XCTAssertEqual(try verdict(for: "same decision text here"),
                       try verdict(for: "same decision text here"),
                       "identical text must seal an identical (deterministic) verdictRef")
    }

    /// The verdict is not a constant rubber-stamp: a manipulation-cued entry ESCALATES the risk
    /// band above a benign one (the honest, differentiated signal — mirror, not oracle).
    func testGovernanceVerdictEscalatesOnRiskCues() throws {
        func verdict(for text: String) throws -> String {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            return try XCTUnwrap(sealedVerdict(in: try run(["add", text], journalDir: dir).stdout))
        }
        let benign = try verdict(for: "note: refactored the parser today")
        let risky = try verdict(for: "you must do this immediately now, everyone says you always should")
        XCTAssertTrue(benign.contains("risk:low"), "a benign entry should read risk:low: \(benign)")
        XCTAssertFalse(risky.contains("risk:low"),
            "a manipulation-cued entry must escalate above risk:low: \(risky)")
        XCTAssertNotEqual(benign, risky, "the spine must differentiate risky from benign input")
    }

    // MARK: - Increment 3c: opt-in deliberation

    /// `--deliberate` runs the extra deliberation passes and seals under the `gov2d:` namespace
    /// (baseline `add` stays `gov2:`), so the sealed record shows which mode produced the verdict.
    /// The chain still verifies with the deliberated verdictRef.
    func testDeliberateSealsGov2dNamespace() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let base = try XCTUnwrap(sealedVerdict(in:
            try run(["add", "a plain note"], journalDir: dir).stdout))
        XCTAssertTrue(base.hasPrefix("admit|gov2:"), "baseline add must seal gov2: — \(base)")

        let delibDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: delibDir) }
        let out = try run(["add", "--deliberate", "a plain note"], journalDir: delibDir)
        let delib = try XCTUnwrap(out.stdout.split(separator: "\n")
            .first(where: { $0.contains("sealed ") && $0.contains("gov2d") })
            .flatMap { line -> String? in
                guard let r = line.range(of: "  (Ed25519") else { return nil }
                let parts = line[..<r.lowerBound].split(separator: " ")
                guard let i = parts.firstIndex(of: "sealed"), i + 2 < parts.count else { return nil }
                return parts[(i + 2)...].joined(separator: " ")
            }, "add --deliberate must seal a gov2d: verdict: \(out.stdout)")
        XCTAssertTrue(delib.hasPrefix("admit|gov2d:"), "deliberated add must seal gov2d: — \(delib)")
        XCTAssertEqual(try run(["ledger"], journalDir: delibDir).exit, 0, "chain must verify with gov2d:")
    }

    /// Deliberation is DETERMINISTIC — a signed field must not drift across runs.
    func testDeliberateIsDeterministic() throws {
        func delibVerdict(_ text: String) throws -> String {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            return try XCTUnwrap(sealedVerdictAny(in:
                try run(["add", "--deliberate", text], journalDir: dir).stdout))
        }
        XCTAssertEqual(try delibVerdict("same deliberated text"), try delibVerdict("same deliberated text"),
            "deliberation must be deterministic")
    }

    /// ANTI-THEATER TEETH: 3c must GENUINELY change the verdict (not just the namespace) for at
    /// least one entry — otherwise it is the vacuous no-op 3b was correctly refused for. The
    /// measured example re-rates "maybe delete the whole thing, not sure it matters" from risk:high
    /// (baseline) to risk:medium (deliberated). If the substrate ever changes such that this entry
    /// no longer differs, revisit whether deliberation still delivers a real effect for the journal.
    func testDeliberateGenuinelyChangesVerdictBeyondNamespace() throws {
        let entry = "maybe delete the whole thing, not sure it matters"
        func core(_ dir: URL, _ args: [String]) throws -> String {
            let v = try XCTUnwrap(sealedVerdictAny(in: try run(args + [entry], journalDir: dir).stdout))
            // Strip the gov2/gov2d namespace so we compare the ACTUAL disposition, not the label.
            return v.replacingOccurrences(of: "gov2d:", with: "|")
                    .replacingOccurrences(of: "gov2:", with: "|")
        }
        let d1 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("qj-\(UUID().uuidString)")
        let d2 = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("qj-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: d1); try? FileManager.default.removeItem(at: d2) }
        let baseline = try core(d1, ["add"])
        let deliberated = try core(d2, ["add", "--deliberate"])
        XCTAssertNotEqual(baseline, deliberated,
            "deliberation must genuinely change the verdict (not just the gov2→gov2d label): "
            + "base=\(baseline) delib=\(deliberated)")
    }

    /// CONTENT-INTEGRITY (review MEDIUM): a `--deliberate` that appears INSIDE the entry text must
    /// NOT be stripped — the tamper-evident ledger must seal exactly what the operator typed. Only
    /// a LEADING `--deliberate` is the flag.
    func testDeliberateInsideTextIsNotStrippedFromSealedContent() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let text = "remember to pass --deliberate to the eval harness"

        // The real corruption trigger: the text arrives as SEPARATE argv tokens (the CLI joins
        // `rest`), so "--deliberate" is a standalone token mid-stream — the old order-independent
        // filter would strip it. Passing the words individually reproduces that.
        let added = try run(
            ["add", "remember", "to", "pass", "--deliberate", "to", "the", "eval", "harness"],
            journalDir: dir)
        XCTAssertTrue(added.stdout.contains(text),
            "the literal '--deliberate' inside the text must be preserved: \(added.stdout)")
        // It is content, NOT the flag → baseline gov2: (deliberation NOT enabled).
        let vref = try XCTUnwrap(sealedVerdictAny(in: added.stdout))
        XCTAssertTrue(vref.hasPrefix("admit|gov2:"),
            "a text-internal --deliberate must not enable deliberation (should be gov2:): \(vref)")
        // Recall returns the intact text (content + sealed digest are byte-faithful).
        let recalled = try run(["recall", "eval harness"], journalDir: dir)
        XCTAssertTrue(recalled.stdout.contains(text),
            "recall must return the byte-faithful content: \(recalled.stdout)")
    }

    /// Extract the sealed verdictRef from an add's stdout regardless of gov2/gov2d namespace.
    private func sealedVerdictAny(in addStdout: String) -> String? {
        for line in addStdout.split(separator: "\n")
        where line.contains("sealed ") && (line.contains("gov2:") || line.contains("gov2d:")) {
            guard let r = line.range(of: "  (Ed25519") else { continue }
            let parts = line[..<r.lowerBound].split(separator: " ", omittingEmptySubsequences: true)
            if let i = parts.firstIndex(of: "sealed"), i + 2 < parts.count {
                return parts[(i + 2)...].joined(separator: " ")
            }
        }
        return nil
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

    // MARK: - Increment 5: fire the multi-agent deliberation fabric (audit blind-spot ③ / H8 loaded gun)

    /// `council "<decision>"` convenes the previously-DORMANT multi-agent state fabric: the 4-of-9
    /// mandatory seats emit deltas, the merge engine arbitrates, and each accepted delta is written
    /// to the single-writer-per-domain graph — firing the just-hardened H8 path (registerWriterBatch
    /// via wireRosterToGraph + per-delta writeObject) and the H17 merge applier. NOT a tautology:
    /// the fire is fail-closed (refuses to seal unless every accepted delta applied to a DISTINCT
    /// domain), and the anti-vacuity proof is the DURABLE cross-process seal — this test verifies the
    /// council seal exists in the Ed25519 chain from a SECOND process (`ledger`) and the chain is intact.
    func testCouncilFiresFabricAndSeals() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        let out = try run(["council", "should I migrate the store to SQLite this sprint?"], journalDir: dir)
        XCTAssertEqual(out.exit, 0, "council must fire + seal: \(out.stderr)")
        // A GENUINE multi-seat fire: all 4 mandatory deltas accepted + applied to 4 distinct domains.
        XCTAssertTrue(out.stdout.contains("4/4 deltas accepted + applied"),
            "the fabric must genuinely fire all 4 mandatory seats: \(out.stdout)")
        XCTAssertTrue(out.stdout.contains("4 distinct domains written"),
            "4 distinct single-writer domains must be written (anti-vacuity): \(out.stdout)")
        XCTAssertTrue(out.stdout.contains("4-of-9 mandatory-seat"),
            "must honestly label the 4-of-9 scope, not claim a full 9-seat council: \(out.stdout)")
        // Mirror-not-oracle: the surface mode is framed as a disposition, never a correctness verdict.
        XCTAssertTrue(out.stdout.contains("NOT a verdict on whether the decision is right"),
            "must frame the disposition honestly (mirror-not-oracle): \(out.stdout)")
        XCTAssertTrue(out.stdout.contains("sealed ") && out.stdout.contains("council|4of9|"),
            "the deliberation must be sealed with the honest fabricRef: \(out.stdout)")

        // DURABLE, cross-process proof (the real anti-vacuity check): a SECOND process verifies the
        // council seal is in the signed chain and the chain is intact.
        let verify = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(verify.exit, 0, "ledger must verify intact")
        XCTAssertTrue(verify.stdout.contains("chain INTACT"), "chain must verify: \(verify.stdout)")
        XCTAssertTrue(verify.stdout.contains("council|4of9|") && verify.stdout.contains("surface:"),
            "the sealed council deliberation must persist cross-process: \(verify.stdout)")
    }

    /// The sealed fabricRef must be a REPRODUCIBLE function of the decision text (the clock is pinned,
    /// the candidate ID is a content hash) — the same decision in two independent journals seals the
    /// identical council verdictRef. Mirrors the increment-2b governance-verdict determinism test;
    /// a non-deterministic fabricRef would muddy the tamper-evident record.
    func testCouncilDeliberationIsDeterministic() throws {
        func fabricRef(for decision: String) throws -> String {
            let dir = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: dir) }
            let out = try run(["council", decision], journalDir: dir)
            XCTAssertEqual(out.exit, 0, out.stderr)
            // Extract the "council|4of9|…" token from the sealed line.
            let line = out.stdout.split(separator: "\n").first { $0.contains("council|4of9|") } ?? ""
            let token = line.split(separator: " ").first { $0.hasPrefix("council|4of9|") } ?? ""
            return String(token)
        }
        let a = try fabricRef(for: "adopt the new caching layer")
        let b = try fabricRef(for: "adopt the new caching layer")
        XCTAssertFalse(a.isEmpty, "a fabricRef must be produced")
        XCTAssertEqual(a, b, "same decision ⇒ identical sealed fabricRef (pinned clock, content-hash candidate)")
    }

    /// Increment 5 is additive: `council` and `add` seal into ONE chain and interoperate. `add`'s
    /// governance seal is unchanged by the new command (ADR-014 — the add path is untouched), and a
    /// mixed council+add chain still verifies intact from a fresh process.
    func testCouncilAndAddCoexistInOneIntactChain() throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("qinao-journal-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertEqual(try run(["council", "review the incident postmortem"], journalDir: dir).exit, 0)
        let added = try run(["add", "decided: adopt weekly postmortems"], journalDir: dir)
        XCTAssertEqual(added.exit, 0)
        // add still seals its increment-2b governance verdict, unperturbed by the council increment.
        XCTAssertTrue(added.stdout.contains("gov2:") || added.stdout.contains("admit"),
            "add's governance seal must be unchanged by the council increment: \(added.stdout)")

        let verify = try run(["ledger"], journalDir: dir)
        XCTAssertEqual(verify.exit, 0)
        XCTAssertTrue(verify.stdout.contains("chain INTACT"),
            "a mixed council+add chain must verify intact: \(verify.stdout)")
        XCTAssertTrue(verify.stdout.contains("council|4of9|"),
            "the council seal must coexist with the add seal in one chain: \(verify.stdout)")
    }
}
#endif
