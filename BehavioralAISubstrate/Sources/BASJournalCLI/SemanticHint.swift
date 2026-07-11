// MARK: - SemanticHint.swift — the semantic citation ASSISTANT (grounding increment 2, hint-only)
//
// The MiniLM rung, shipped as what the calibration EARNED and nothing more. The 2026-07-11 probe
// (n=10 paraphrase claims vs all 3,887 real commit subjects) killed SEALED semantic grounding:
// true-pair and best-distractor cosines OVERLAP (minTrue 0.252 / maxFalseTop 0.614 / rank1 6/10),
// because this corpus is self-similar and MiniLM measures TOPIC similarity while grounding needs
// REFERENTIAL identity — at the (0.45, 0.05) gate, 2 of 5 resolutions would have sealed the WRONG
// commit. So the semantic rung NEVER touches the seal. Instead, when armed
// (QINAO_JOURNAL_GROUND_SEMANTIC=1, default OFF) and the DETERMINISTIC path abstained (no citation
// in the text), it PRINTS a suggestion:
//
//     hint: resembles commit ed66c50e — "fix(cue-precision MED): …" (cos 0.66)
//           cite the SHA to ground it — hints are never sealed
//
// The loop closes through the OPERATOR (propose/dispose): the machine proposes a citation, the
// human verifies by reading the shown subject, and re-citing the SHA routes the claim through the
// DETERMINISTIC increment-1 path, which is what seals. A wrong hint costs one glance; a wrong seal
// would be false grounding in a tamper-evident ledger — that asymmetry is the whole design.

import Foundation
import BASAppleAdapters
import BASHostKit
import BASSovereign

/// Print a citation hint for `text` if armed, the deterministic path abstained, and the gate
/// clears. Never mutates anything but the hint-index cache (a rebuildable side file).
func printSemanticHintIfArmed(text: String, sealedRef: String) async {
    let env = ProcessInfo.processInfo.environment
    guard env["QINAO_JOURNAL_GROUND_SEMANTIC"] == "1" else { return }
    // the deterministic signal already spoke (match OR miss) — a softer hint would only dilute it
    guard !sealedRef.contains("grounded:") else { return }

    guard let provider = BASMiniLMEmbeddingProvider() else {
        FileHandle.standardError.write(Data("hint: unavailable (MiniLM model missing)\n".utf8))
        return
    }
    guard let log = readGitLogForHint(
        repo: env["QINAO_JOURNAL_GROUND_REPO"] ?? FileManager.default.currentDirectoryPath)
    else { return }
    let facts = BASGitFactBank.ingest(gitLog: log)
    guard !facts.isEmpty else { return }

    do {
        let index = try BASSemanticCommitIndex(
            dbPath: journalDir.appendingPathComponent("semantic-index.sqlite").path,
            provider: provider)
        defer { index.close() }
        // Incremental: only new commits embed. A cold cache is a one-off backfill (~5 ms/subject —
        // ~19 s for ~3.9k commits), surfaced honestly instead of a silent hang. The count is the
        // ACTUALLY-missing count (a warm cache prints nothing — the notice must not lie).
        let missing = try index.missingCount(subjectsBySha8: facts.subjectBySha8)
        if missing > 200 {
            FileHandle.standardError.write(Data(
                "hint-index: one-off backfill of \(missing) commit subjects (~\(missing / 200)s)…\n".utf8))
        }
        _ = try await index.refresh(subjectsBySha8: facts.subjectBySha8)
        guard let h = await index.hint(for: text) else { return }
        let subject = facts.subjectBySha8[h.sha8] ?? ""
        print(String(format: "hint: resembles commit %@ — \"%@\" (cos %.2f)",
                     h.sha8, String(subject.prefix(88)), h.cosine))
        print("      cite the SHA to ground it — hints are never sealed")
    } catch {
        FileHandle.standardError.write(Data("hint: index error (\(error)) — skipped\n".utf8))
    }
}

/// Same read as Grounding.swift's — kept separate so the hint path can't perturb the seal path.
private func readGitLogForHint(repo: String) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["git", "-C", repo, "log", "--no-merges", "--format=%H%x09%s"]
    let out = Pipe()
    proc.standardOutput = out
    proc.standardError = Pipe()
    do { try proc.run() } catch { return nil }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    proc.waitUntilExit()
    guard proc.terminationStatus == 0, !data.isEmpty else { return nil }
    return String(decoding: data, as: UTF8.self)
}
