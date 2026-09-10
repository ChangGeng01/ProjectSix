// Device bundle: this suite spawns a subprocess (Process) / the CLI binary — macOS-only.
// #if os(macOS) so the iOS test bundle compiles it away (SwiftPM/macOS still runs it).
#if os(macOS)
import XCTest
import BASAppleAdapters
import BASMemory

/// Grounding increment 2 (semantic prose rung) — the DECISIVE pre-design calibration probe.
/// Question: does MiniLM discriminate a PARAPHRASED prose claim against 3,887 terse commit
/// subjects well enough for an abstain-biased CRAG gate (threshold + margin) to exist?
/// If cos(claim, true subject) does not reliably beat every distractor, the rung is a NO-GO
/// and the honest answer is "does not discriminate — do not ship".
///
/// Env-gated (QINAO_GROUND_CALIBRATE=1) — a one-off measured experiment, not a suite test.
/// It also measures the full-corpus embed cost (the cache-backfill number the design needs).
final class BASGroundingSemanticCalibrationProbe: XCTestCase {

    /// (paraphrased claim — deliberately DIFFERENT wording, no SHA) → the true commit sha prefix.
    private let pairs: [(claim: String, sha: String)] = [
        ("fixed the manipulation cue words falsely matching inside benign words like knowledge", "ed66c50e5"),
        ("shipped the comma join fix so the audit ledger no longer quarantines itself", "4da45f26d"),
        ("made vector search results deterministic when scores tie", "fbce1fc72"),
        ("capped the inference latency tracker so its memory stops growing forever", "182bc9e96"),
        ("fixed lifecycle events coming back in the wrong order from sqlite", "2db9c6090"),
        ("made the cross device version merge order independent", "4203902b0"),
        ("gated the sovereign ledger in the endurance app behind an env flag", "cd9c5595e"),
        ("added git grounding to the journal so cited commits are checked against history", "4eaccc83f"),
        ("removed the unused package manifest dependencies", "b219c1079"),
        ("strengthened the vacuous probability distribution test into a real assertion", "70e3652b5"),
    ]

    func testCalibrationSweep() async throws {
        guard ProcessInfo.processInfo.environment["QINAO_GROUND_CALIBRATE"] == "1" else {
            throw XCTSkip("calibration probe — run with QINAO_GROUND_CALIBRATE=1")
        }
        guard let provider = BASMiniLMEmbeddingProvider() else {
            throw XCTSkip("MiniLM unavailable on this host")
        }

        // Real corpus: every commit subject in this repo.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git", "log", "--no-merges", "--format=%H%x09%s"]
        let out = Pipe(); p.standardOutput = out
        try p.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        var sha40s: [String] = [], subjects: [String] = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let tab = line.firstIndex(of: "\t") else { continue }
            sha40s.append(String(line[..<tab]))
            subjects.append(String(line[line.index(after: tab)...]))
        }
        print("CAL corpus: \(subjects.count) commit subjects")

        // Embed the full corpus (this IS the backfill-cost measurement).
        let t0 = Date()
        var vecs: [[Float]] = []
        vecs.reserveCapacity(subjects.count)
        for s in subjects { vecs.append(await provider.embed(s).normalized.vector) }
        let embedSec = Date().timeIntervalSince(t0)
        print(String(format: "CAL embed cost: %.1fs total, %.1fms/subject", embedSec,
                     embedSec * 1000 / Double(max(1, subjects.count))))

        func dot(_ a: [Float], _ b: [Float]) -> Float {
            var s: Float = 0; for i in 0..<min(a.count, b.count) { s += a[i] * b[i] }; return s
        }

        var minTrue: Float = 1, maxFalseTop: Float = -1, worstMargin: Float = 1
        var rank1 = 0
        for (claim, sha) in pairs {
            guard let trueIdx = sha40s.firstIndex(where: { $0.hasPrefix(sha) }) else {
                print("CAL MISSING commit \(sha) — skipped"); continue
            }
            let q = await provider.embed(claim).normalized.vector
            var scored: [(Int, Float)] = []
            for (i, v) in vecs.enumerated() { scored.append((i, dot(q, v))) }
            scored.sort { $0.1 > $1.1 }
            let trueCos = dot(q, vecs[trueIdx])
            let rankOfTrue = scored.firstIndex { $0.0 == trueIdx }! + 1
            let bestDistractor = scored.first { $0.0 != trueIdx }!
            let margin = trueCos - bestDistractor.1
            if rankOfTrue == 1 { rank1 += 1 }
            minTrue = min(minTrue, trueCos)
            maxFalseTop = max(maxFalseTop, bestDistractor.1)
            worstMargin = min(worstMargin, margin)
            print(String(format: "CAL pair sha=%@ trueCos=%.3f rank=%d margin=%+.3f bestDistractor=%.3f «%@»",
                         sha, trueCos, rankOfTrue, margin, bestDistractor.1,
                         String(subjects[bestDistractor.0].prefix(70))))
        }
        print(String(format: "CAL SUMMARY rank1=%d/%d minTrueCos=%.3f maxFalseTopCos=%.3f worstMargin=%+.3f",
                     rank1, pairs.count, minTrue, maxFalseTop, worstMargin))
        // Also: the abstain check — a plain non-ship note must stay below any usable threshold.
        for offTopic in ["had coffee and reviewed the morning plan",
                         "call mom about the weekend trip",
                         "the weather is nice today"] {
            let q = await provider.embed(offTopic).normalized.vector
            let top = vecs.map { dot(q, $0) }.max() ?? -1
            print(String(format: "CAL off-topic top cosine: %.3f  «%@»", top, offTopic))
        }
    }
}
#endif
