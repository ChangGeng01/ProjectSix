// MARK: - Grounding.swift — git-self-grounding of a journal claim (grounding increment 1)
//
// Fires the built-but-dormant grounding doctrine against the panel's seed fact source: "the git
// log IS the fact source." When armed (QINAO_JOURNAL_GROUND=1), an add whose text CITES a commit
// (a commit-qualified SHA token) or a marker (#N / H\d+ / M\d+ / ch\d+) is resolved by
// BASGitFactBank's pure Set-membership against the operator's real git history, and the result is
// folded into the seal's verdictRef:
//
//     …|abstain                                        (today / OFF / uncovered — byte-identical)
//     …|abstain|grounded:record-match:b5a309f5          (the cited commit EXISTS in the record)
//     …|abstain|grounded:record-miss:deadbeef1          (SHA-shaped citation of NO commit — the
//                                                        fabricated/misremembered-citation catch)
//     …|abstain|grounded:unavailable                    (armed but git unreadable — honest, never
//                                                        a fabricated match)
//
// ── MIRROR, not oracle ────────────────────────────────────────────────────────────────────────
// record-match means ONLY "the commit you cited exists in the git record" — record-CONSISTENCY,
// never "your decision was right" (which is why the token is not "agrees"). The governance
// `abstain` beside it is left standing: grounding ADDS a mirror field, it never upgrades the
// verdict to a green light. The 4B hard lesson holds structurally: the git record adjudicates via
// pure Set-membership; no model is ever asked "is this true".
//
// ── Default-OFF byte-parity (ADR-014 / 红线) ─────────────────────────────────────────────────
// QINAO_JOURNAL_GROUND unset/0 ⇒ groundClaim returns nil before ANY work (no git subprocess), so
// the sealed verdictRef is byte-identical to increment 2b/3c. Even armed, an uncovered entry
// (no citation) returns nil ⇒ byte-identical.

import Foundation
import BASSovereign

/// Ground `text` against the git record. nil ⇒ caller seals the unchanged verdictRef.
func groundClaim(_ text: String) -> String? {
    let env = ProcessInfo.processInfo.environment
    guard env["QINAO_JOURNAL_GROUND"] == "1" else { return nil }

    guard let log = readGitLog(
        repo: env["QINAO_JOURNAL_GROUND_REPO"] ?? FileManager.default.currentDirectoryPath)
    else { return "grounded:unavailable" }

    let facts = BASGitFactBank.ingest(gitLog: log)
    guard !facts.isEmpty else { return "grounded:unavailable" }
    guard let r = BASGitFactBank.resolve(claim: text, facts: facts) else { return nil }
    switch r.truth {
    case .agrees:      return "grounded:record-match:\(r.sha8 ?? r.token)"
    case .contradicts: return "grounded:record-miss:\(r.token)"
    case .unknown:     return nil
    }
}

/// `git -C <repo> log --no-merges --format=%H%x09%s`, or nil on any failure (not a repo / git
/// missing / non-zero exit) — the caller degrades to the honest `grounded:unavailable`.
private func readGitLog(repo: String) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["git", "-C", repo, "log", "--no-merges", "--format=%H%x09%s"]
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = Pipe()   // silence git's stderr; failure is signaled by exit status
    do { try proc.run() } catch { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0, !data.isEmpty else { return nil }
    return String(decoding: data, as: UTF8.self)
}
