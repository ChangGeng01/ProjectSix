// Device bundle: this suite spawns a subprocess (Process) / the CLI binary — macOS-only.
// #if os(macOS) so the iOS test bundle compiles it away (SwiftPM/macOS still runs it).
#if os(macOS)
import XCTest

/// Grounding increment 1 — end-to-end teeth against the REAL BASJournalCLI binary and a THROWAWAY
/// fixture git repo (the fact source is controlled, not the substrate repo's moving history).
///
/// The anti-3b (non-vacuity) contract, proven here:
///   • ARMED + covered claim  → the SEALED verdictRef gains `grounded:record-match:<sha8>` —
///     a strictly different Ed25519-signed pre-image, visible verbatim in `ledger`;
///   • ARMED + fabricated SHA → `grounded:record-miss:<token>` (the fail-closed catch is LIVE);
///   • OFF (default) — same covered text → the seal is BYTE-IDENTICAL to the ungrounded seal
///     (ADR-014 byte-parity; no git subprocess even runs).
final class BASJournalGroundingIntegrationTests: XCTestCase {

    private struct CLIResult { let stdout: String; let stderr: String; let exit: Int32 }

    private func cliBinaryURL() -> URL? {
        let fm = FileManager.default
        for path in [".build/debug/BASJournalCLI", ".build/release/BASJournalCLI",
                     ".build/arm64-apple-macosx/debug/BASJournalCLI"] {
            let url = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(path)
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func run(_ args: [String], journalDir: URL, ground: Bool, repo: URL?,
                     semantic: Bool = false) throws -> CLIResult {
        guard let binary = cliBinaryURL() else {
            throw XCTSkip("BASJournalCLI binary not found — run `swift build` first.")
        }
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["QINAO_JOURNAL_DIR"] = journalDir.path
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND")
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND_REPO")
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND_SEMANTIC")
        if ground { env["QINAO_JOURNAL_GROUND"] = "1" }
        if semantic { env["QINAO_JOURNAL_GROUND_SEMANTIC"] = "1" }
        if let repo { env["QINAO_JOURNAL_GROUND_REPO"] = repo.path }
        p.environment = env
        let out = Pipe(); p.standardOutput = out
        let err = Pipe(); p.standardError = err
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return CLIResult(stdout: String(decoding: data, as: UTF8.self),
                         stderr: String(decoding: errData, as: UTF8.self),
                         exit: p.terminationStatus)
    }

    /// A throwaway git repo with ONE empty commit — the controlled fact source. Returns (dir, sha40).
    private func makeFixtureRepo() throws -> (URL, String) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-ground-fixture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func git(_ args: [String]) throws -> String {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "-C", dir.path] + args
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw XCTSkip("git unavailable for fixture repo") }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _ = try git(["init", "-q"])
        _ = try git(["-c", "user.email=t@t", "-c", "user.name=t",
                     "commit", "--allow-empty", "-q", "-m", "fix(demo): grounding fixture #77"])
        let sha = try git(["rev-parse", "HEAD"])
        return (dir, sha)
    }

    private func tempJournalDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-ground-journal-\(UUID().uuidString)")
    }

    /// Extract the sealed verdictRef from the CLI's "sealed <id>  <verdictRef>  (Ed25519…" line.
    private func sealedRef(in stdout: String) -> String? {
        for line in stdout.split(separator: "\n") where line.hasPrefix("sealed ") {
            let parts = line.split(separator: "  ").map(String.init)
            if parts.count >= 2 { return parts[1] }
        }
        return nil
    }

    // MARK: - the teeth

    func testArmedCoveredClaimSealsRecordMatchAndLedgerShowsIt() throws {
        let (repo, sha) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sha7 = String(sha.prefix(7)), sha8 = String(sha.prefix(8))
        let add = try run(["add", "shipped the fixture in commit \(sha7)"],
                          journalDir: dir, ground: true, repo: repo)
        XCTAssertEqual(add.exit, 0)
        let ref = try XCTUnwrap(sealedRef(in: add.stdout))
        XCTAssertTrue(ref.hasSuffix("|grounded:record-match:\(sha8)"),
            "armed + covered ⇒ the SEALED ref gains the record-match token; got \(ref)")

        // durable: the grounded token is in the Ed25519 ledger, read back verbatim cross-process
        let ledger = try run(["ledger"], journalDir: dir, ground: false, repo: nil)
        XCTAssertTrue(ledger.stdout.contains("grounded:record-match:\(sha8)"),
            "the grounded token is sealed into the chain, not just printed")
        XCTAssertTrue(ledger.stdout.contains("chain INTACT"))
    }

    func testArmedFabricatedShaSealsRecordMiss() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let add = try run(["add", "shipped the redis cache in commit deadbeef1"],
                          journalDir: dir, ground: true, repo: repo)
        let ref = try XCTUnwrap(sealedRef(in: add.stdout))
        XCTAssertTrue(ref.hasSuffix("|grounded:record-miss:deadbeef1"),
            "a SHA-shaped citation of NO commit seals record-miss (fail-closed, live); got \(ref)")
    }

    /// The anti-3b proof: bytes provably change ON, provably do NOT change OFF.
    func testDefaultOffSealIsByteIdenticalAndArmedSealDiffers() throws {
        let (repo, sha) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let text = "shipped the fixture in commit \(String(sha.prefix(7)))"

        // OFF (default): the sealed ref must carry NO grounded token…
        let dirOff = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirOff) }
        let off = try run(["add", text], journalDir: dirOff, ground: false, repo: repo)
        let offRef = try XCTUnwrap(sealedRef(in: off.stdout))
        XCTAssertFalse(offRef.contains("grounded:"), "OFF must not ground; got \(offRef)")

        // …and be byte-identical to the armed-but-UNCOVERED seal of a no-citation entry's shape:
        // the strongest parity check is same-text OFF vs ON — ON differs ONLY by the grounded suffix.
        let dirOn = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirOn) }
        let on = try run(["add", text], journalDir: dirOn, ground: true, repo: repo)
        let onRef = try XCTUnwrap(sealedRef(in: on.stdout))
        XCTAssertNotEqual(onRef, offRef, "anti-3b: arming must CHANGE the sealed bytes on a covered turn")
        XCTAssertTrue(onRef.hasPrefix(offRef + "|grounded:"),
            "the grounded field is a strict suffix — governance bytes untouched; got \(onRef) vs \(offRef)")

        // armed + UNCOVERED (no citation) ⇒ byte-identical to OFF for that text
        let dirOn2 = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirOn2) }
        let dirOff2 = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirOff2) }
        let plain = "had coffee and reviewed the morning plan"
        let onPlain = try run(["add", plain], journalDir: dirOn2, ground: true, repo: repo)
        let offPlain = try run(["add", plain], journalDir: dirOff2, ground: false, repo: repo)
        XCTAssertEqual(sealedRef(in: onPlain.stdout), sealedRef(in: offPlain.stdout),
            "armed + uncovered abstains ⇒ byte-identical seal (false-abstain bias)")
    }

    // MARK: - grounding increment 2 — the semantic citation ASSISTANT (hint-only, NEVER sealed)

    func testSemanticHintProposesCitationButNeverSeals() throws {
        let (repo, sha) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // a paraphrase of the fixture subject "fix(demo): grounding fixture #77" — NO citation.
        // wait: "#77" IS a marker… use wording without it so the deterministic path abstains.
        let claim = "worked on the demo grounding fixture today"
        let r = try run(["add", claim], journalDir: dir, ground: true, repo: repo, semantic: true)
        if r.stderr.contains("MiniLM model missing") {
            throw XCTSkip("MiniLM unavailable on this host — hint path not exercisable")
        }
        let ref = try XCTUnwrap(sealedRef(in: r.stdout))
        XCTAssertFalse(ref.contains("grounded:"),
            "the hint must NEVER seal — the sealed ref stays ungrounded; got \(ref)")
        XCTAssertTrue(r.stdout.contains("hint: resembles commit \(String(sha.prefix(8)))"),
            "armed semantic ⇒ a printed citation proposal; got stdout: \(r.stdout)")
        XCTAssertTrue(r.stdout.contains("hints are never sealed"),
            "the hint carries its own honesty line")
    }

    func testSemanticHintAbstainsOffTopicAndStaysSilentWhenUnarmed() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        // armed but OFF-TOPIC ⇒ below the gate ⇒ no hint line
        let dirA = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirA) }
        let offTopic = try run(["add", "the weather is nice today"],
                               journalDir: dirA, ground: true, repo: repo, semantic: true)
        if offTopic.stderr.contains("MiniLM model missing") {
            throw XCTSkip("MiniLM unavailable on this host — hint path not exercisable")
        }
        XCTAssertFalse(offTopic.stdout.contains("hint: resembles"),
            "off-topic must abstain (gate); got \(offTopic.stdout)")

        // UNARMED (semantic flag unset) ⇒ no hint machinery at all
        let dirB = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dirB) }
        let unarmed = try run(["add", "worked on the demo grounding fixture today"],
                              journalDir: dirB, ground: true, repo: repo, semantic: false)
        XCTAssertFalse(unarmed.stdout.contains("hint:"),
            "default-off ⇒ no hint line; got \(unarmed.stdout)")
    }
}
#endif
