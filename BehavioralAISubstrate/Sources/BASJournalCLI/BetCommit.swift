// MARK: - BetCommit.swift — the ship-moment loop (increment R, retention design panel BUILD_REVISED)
//
// `bet-commit [<sha-prefix>] -q "<falsifiable question>"` turns a JUST-SHIPPED commit (default
// HEAD) into a grounded, sealed, open bet in one command. The retention theory it encodes: the
// journal went cold for 3 days WHILE `review` existed — prospective memory is falsified — but
// committing never had a zero day, so the loop anchors to the ship moment. The machine automates
// exactly what git already records (subject + sha, fetched and verified here); the operator types
// exactly what git canNOT record (the falsifiable expectation) — which is why -q is MANDATORY:
// a default "was this right?" bet is unresolvable-vague and trains `review` to be spam (the
// adversary's kill of the lazy-question variant).
//
// Born grounded: this command verifies the sha against the record itself (git log -1), so its
// seal carries `grounded:record-match:<sha8>` BY ITS OWN CONTRACT — no env flag dance for a
// citation the command constructed from the repo. Plain add/bet stay byte-identical (pinned).
// Fail-before-admit: an unknown/ambiguous sha or a missing -q writes NOTHING (no atom, no seal).

import Foundation

func cmdBetCommit(_ rest: [String], deliberate: Bool) async throws {
    // parse: [<sha-prefix>] -q "<question>" (the same -q convention as `bet`)
    var shaPrefix: String?
    var question: String?
    var i = 0
    while i < rest.count {
        if rest[i] == "-q", i + 1 < rest.count {
            question = rest[i + 1]; i += 2
        } else if shaPrefix == nil, !rest[i].hasPrefix("-") {
            shaPrefix = rest[i]; i += 1
        } else {
            i += 1
        }
    }

    let repo = ProcessInfo.processInfo.environment["QINAO_JOURNAL_GROUND_REPO"]
        ?? FileManager.default.currentDirectoryPath
    guard let (sha8, subject) = resolveCommit(repo: repo, ref: shaPrefix ?? "HEAD") else {
        FileHandle.standardError.write(Data(
            ("bet-commit: cannot resolve \"\(shaPrefix ?? "HEAD")\" in \(repo) — nothing logged, "
             + "nothing sealed. (unknown/ambiguous sha, or not a git repo)\n").utf8))
        exit(1)
    }

    guard let question, !question.trimmingCharacters(in: .whitespaces).isEmpty else {
        // The refusal teaches: show what WAS resolved + what a falsifiable question looks like.
        print("bet-commit: \(sha8) — \"\(subject)\"")
        print("a bet needs YOUR falsifiable expectation (-q) — that is the one thing git cannot record.")
        print("exemplars:")
        print("  bet-commit \(sha8) -q \"no revert or follow-up fix reopens this within a week\"")
        print("  bet-commit \(sha8) -q \"the flake rate drops to zero in the next 5 full sweeps\"")
        exit(1)
    }

    let text = "\(subject) (commit \(sha8))"
    try await cmdBet(text, question: question, deliberate: deliberate,
                     groundedOverride: "grounded:record-match:\(sha8)")
}

/// `git -C <repo> log -1 --format=%H%x09%s <ref>` → (sha8, subject), or nil on ANY failure
/// (unknown sha / ambiguous prefix / not a repo) — the caller fails BEFORE touching any store.
private func resolveCommit(repo: String, ref: String) -> (sha8: String, subject: String)? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["git", "-C", repo, "log", "-1", "--format=%H%x09%s", ref]
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = Pipe()
    do { try proc.run() } catch { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0 else { return nil }
    let line = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let tab = line.firstIndex(of: "\t") else { return nil }
    let sha = String(line[..<tab])
    guard sha.count == 40 else { return nil }
    return (String(sha.prefix(8)), String(line[line.index(after: tab)...]))
}
