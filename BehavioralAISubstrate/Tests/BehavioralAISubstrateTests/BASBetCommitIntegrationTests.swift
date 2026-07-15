// Device bundle: this suite spawns a subprocess (Process) / the CLI binary — macOS-only.
// #if os(macOS) so the iOS test bundle compiles it away (SwiftPM/macOS still runs it).
#if os(macOS)
import XCTest

/// Increment R — the "ship-moment loop" (retention design panel BUILD_REVISED, wf_20a775a9):
/// `bet-commit [<sha-prefix>] -q "<falsifiable question>"` turns a just-shipped commit into a
/// grounded, sealed, open bet; a print-only PRESSURE TAIL surfaces the oldest open bet after every
/// bet; `review` gains a resolvability JOIN against today's commits. The adversary's revisions are
/// load-bearing and pinned here: -q is MANDATORY (no lazy default-question bets — t1), an unknown
/// sha writes NOTHING (t3), and the seal is born grounded by the command's own verification (t2).
final class BASBetCommitIntegrationTests: XCTestCase {

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

    private func run(_ args: [String], journalDir: URL, repo: URL?) throws -> CLIResult {
        guard let binary = cliBinaryURL() else {
            throw XCTSkip("BASJournalCLI binary not found — run `swift build` first.")
        }
        let p = Process()
        p.executableURL = binary
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["QINAO_JOURNAL_DIR"] = journalDir.path
        // deliberately UNARMED: bet-commit's born-grounded seal must not depend on the env flags
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND")
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND_SEMANTIC")
        env.removeValue(forKey: "QINAO_JOURNAL_GROUND_REPO")
        if let repo { env["QINAO_JOURNAL_GROUND_REPO"] = repo.path }
        p.environment = env
        let out = Pipe(); p.standardOutput = out
        let err = Pipe(); p.standardError = err
        try p.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return CLIResult(stdout: String(decoding: outData, as: UTF8.self),
                         stderr: String(decoding: errData, as: UTF8.self),
                         exit: p.terminationStatus)
    }

    private func makeFixtureRepo(subject: String = "fix(demo): ship-moment fixture #77") throws -> (URL, String) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-betcommit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        func git(_ args: [String]) throws -> String {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            p.arguments = ["git", "-C", dir.path] + args
            let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
            try p.run()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { throw XCTSkip("git unavailable") }
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _ = try git(["init", "-q"])
        _ = try git(["-c", "user.email=t@t", "-c", "user.name=t",
                     "commit", "--allow-empty", "-q", "-m", subject])
        return (dir, try git(["rev-parse", "HEAD"]))
    }

    private func tempJournalDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("qinao-betcommit-journal-\(UUID().uuidString)")
    }

    private func sealedEntryCount(journalDir: URL) throws -> Int {
        let r = try run(["ledger"], journalDir: journalDir, repo: nil)
        // "ledger: N sealed entries · chain INTACT …"
        for line in r.stdout.split(separator: "\n") where line.contains("sealed entries") {
            if let n = line.split(separator: " ").compactMap({ Int($0) }).first { return n }
        }
        return -1
    }

    // t1 — mandatory -q: no question ⇒ exit 1, exemplars printed, ZERO writes
    func testBetCommitWithoutQuestionRefusesAndWritesNothing() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["count"], journalDir: dir, repo: nil)   // seed the journal dir
        let before = try sealedEntryCount(journalDir: dir)

        let r = try run(["bet-commit"], journalDir: dir, repo: repo)
        XCTAssertEqual(r.exit, 1, "no -q ⇒ refuse (an unresolvable bet poisons review)")
        XCTAssertTrue((r.stdout + r.stderr).contains("-q"),
            "the refusal must teach: show the resolved subject + exemplar falsifiable questions")
        XCTAssertEqual(try sealedEntryCount(journalDir: dir), before,
            "refusal writes NOTHING — no atom, no seal")
    }

    // t2 — the happy path: born grounded, opened, indexed
    func testBetCommitOpensGroundedBetOnHead() throws {
        let (repo, sha) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sha8 = String(sha.prefix(8))

        let r = try run(["bet-commit", "-q", "will this fixture survive the week?"],
                        journalDir: dir, repo: repo)
        XCTAssertEqual(r.exit, 0, "stderr: \(r.stderr)")
        XCTAssertTrue(r.stdout.contains("bet opened"), "a real trial opens; got \(r.stdout)")
        XCTAssertTrue(r.stdout.contains("grounded:record-match:\(sha8)"),
            "the seal is BORN grounded — the command verified the sha against the record itself")
        XCTAssertTrue(r.stdout.contains("(commit \(sha8))"),
            "the entry text carries the commit-qualified citation")

        let review = try run(["review"], journalDir: dir, repo: repo)
        XCTAssertTrue(review.stdout.contains("will this fixture survive the week?"),
            "the bet appears in the morning review")
    }

    // t3 — unknown sha: exit 1, nothing logged or sealed
    func testBetCommitUnknownShaWritesNothing() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        _ = try run(["count"], journalDir: dir, repo: nil)
        let before = try sealedEntryCount(journalDir: dir)

        let r = try run(["bet-commit", "deadbeef42", "-q", "did it hold?"],
                        journalDir: dir, repo: repo)
        XCTAssertEqual(r.exit, 1, "an unverifiable citation must fail BEFORE any store touch")
        XCTAssertEqual(try sealedEntryCount(journalDir: dir), before, "zero writes on failure")
    }

    // t4 — review's resolvability join: marker-bearing bet fires, marker-less stays silent
    func testReviewJoinFiresForCitedBetAndAbstainsForMarkerless() throws {
        let (repo, sha) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sha8 = String(sha.prefix(8))

        // a cited bet (bet-commit → text carries "(commit <sha8>)"; the fixture commit is TODAY)
        _ = try run(["bet-commit", "-q", "does the fixture hold?"], journalDir: dir, repo: repo)
        // a marker-less bet
        _ = try run(["bet", "pure gut call, no citation", "-q", "was it right?"],
                    journalDir: dir, repo: repo)

        let review = try run(["review"], journalDir: dir, repo: repo)
        XCTAssertTrue(review.stdout.contains("possibly resolvable today"),
            "a bet citing a commit made TODAY must fire the join; got \(review.stdout)")
        XCTAssertTrue(review.stdout.contains(sha8), "the join names the matching commit")
        // silent abstain for the marker-less bet: exactly ONE join line
        let joinLines = review.stdout.split(separator: "\n").filter { $0.contains("possibly resolvable") }
        XCTAssertEqual(joinLines.count, 1, "marker-less bets never fuzzy-match (silent abstain)")
    }

    // t5 — the pressure tail: the NEXT bet surfaces the pre-existing oldest open bet
    func testPressureTailSurfacesOldestOpenBet() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = try run(["bet", "the oldest unresolved question", "-q", "was I right?"],
                            journalDir: dir, repo: repo)
        // the first bet has no prior open bets — no tail
        XCTAssertFalse(first.stdout.contains("open bet"),
            "no pre-existing open bets ⇒ no tail; got \(first.stdout)")

        let second = try run(["bet-commit", "-q", "does the fixture hold?"],
                             journalDir: dir, repo: repo)
        XCTAssertTrue(second.stdout.contains("open bet"),
            "the tail surfaces the pressure; got \(second.stdout)")
        XCTAssertTrue(second.stdout.contains("the oldest unresolved question"),
            "the tail names the OLDEST open bet (the withdrawal prompt)")
    }

    // t6 — byte-parity pin: a plain unarmed bet seals NO grounded token
    func testPlainBetSealStaysUngrounded() throws {
        let (repo, _) = try makeFixtureRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let dir = tempJournalDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let r = try run(["bet", "a plain decision", "-q", "was it right?"],
                        journalDir: dir, repo: repo)
        XCTAssertEqual(r.exit, 0)
        XCTAssertFalse(r.stdout.contains("grounded:"),
            "plain bet (unarmed) stays byte-identical — born-grounded is bet-commit's OWN contract")
    }
}
#endif
