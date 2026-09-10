// MARK: - BASCorpusFlattenMicroGateTests — iOS 27 P8 (IOS27_PERF_ADOPTION_PLAN)
//
// Micro-gate for the OutputSpan corpus-flatten candidate vs the
// shipping append(contentsOf:) incumbent。 Two claims:
//   1. ELEMENT IDENTITY — same floats, same order, both corpus
//      shapes (the Metal seam consumes the flatten verbatim)。
//   2. MEASURED VERDICT — best-of-3 (ch1037 doctrine) wall-clock at
//      the two realistic corpus shapes (64×384 = selfPopulateCap ×
//      MiniLM dim;1024×384 = a global-recall-scale snapshot)。
//      Verdict line PRINTED for a human;the hot path keeps the
//      incumbent until a reviewed commit flips it (5-axis
//      discipline:clear win flips, TIE/loss DECLINES)。
//
// ADJUDICATED 2026-06-11: **DECLINE — incumbent stands。** Measured
// best-of-3: 64×384 ratio 0.01x, 1024×384 ratio 0.01x (the candidate
// is ~100x SLOWER)。 Root cause is structural, not tuning:OutputSpan
// in this stdlib exposes only per-element `append(_:)` (bounds-checked
// per write;no bulk-copy member),while the incumbent's
// `append(contentsOf:)` is `@_semantics("array.append_contentsOf")`
// bulk memcpy after one reservation — the incumbent is already the
// optimal shape for this copy。 The candidate + gate stay in-tree as
// the evidence record;re-open only if the stdlib ships a bulk
// OutputSpan append (re-run this gate, nothing else needed)。

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASMemory

final class BASCorpusFlattenMicroGateTests: XCTestCase {

    private func makeSnap(
        entries: Int, dim: Int
    ) -> [BASL8RoutedMemoryService.SnapshotEntry] {
        (0..<entries).map { i in
            var seed = UInt64(i &* 2654435761 &+ 1)
            let embedding = (0..<dim).map { _ -> Float in
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Float(seed % 2000) / 1000.0 - 1.0
            }
            return BASL8RoutedMemoryService.SnapshotEntry(
                atomID: "atom-\(i)",
                domain: "gate",
                embedding: embedding,
                atom: BASMemoryAtom(
                    memoryID: "atom-\(i)", summary: "s",
                    contentType: .hot, source: "gate",
                    timestamp: Date(timeIntervalSince1970: 0),
                    confidence: 0.5, conflictFingerprint: "f-\(i)"))
        }
    }

    func testCandidateIsElementIdenticalToIncumbent() {
        for (entries, dim) in [(0, 384), (1, 384), (64, 384), (97, 33)] {
            let snap = makeSnap(entries: entries, dim: dim)
            let incumbent = BASL8RoutedMemoryService.flattenCorpus(
                snap: snap, embeddingDimension: dim)
            let candidate = BASL8RoutedMemoryService
                .flattenCorpusOutputSpan(
                    snap: snap, embeddingDimension: dim)
            XCTAssertEqual(incumbent, candidate,
                "flatten implementations must be element-identical " +
                "(\(entries)×\(dim))")
        }
    }

    func testMicroGateBestOfThreeVerdict() {
        let shapes = [(64, 384), (1024, 384)]
        var lines: [String] = []
        for (entries, dim) in shapes {
            let snap = makeSnap(entries: entries, dim: dim)
            func bestOf3(_ body: () -> [Float]) -> Double {
                var best = Double.greatestFiniteMagnitude
                for _ in 0..<3 {
                    let t0 = DispatchTime.now().uptimeNanoseconds
                    var sink = 0
                    for _ in 0..<50 { sink &+= body().count }
                    let t1 = DispatchTime.now().uptimeNanoseconds
                    XCTAssertEqual(sink, entries * dim * 50)
                    best = min(best, Double(t1 - t0) / 50 / 1e3)
                }
                return best  // µs per flatten
            }
            let incumbentUs = bestOf3 {
                BASL8RoutedMemoryService.flattenCorpus(
                    snap: snap, embeddingDimension: dim)
            }
            let candidateUs = bestOf3 {
                BASL8RoutedMemoryService.flattenCorpusOutputSpan(
                    snap: snap, embeddingDimension: dim)
            }
            let ratio = incumbentUs / max(candidateUs, 0.001)
            lines.append(String(format:
                "%d×%d incumbent=%.1fµs candidate=%.1fµs ratio=%.2fx",
                entries, dim, incumbentUs, candidateUs, ratio))
        }
        // Human-read verdict (5-axis vocabulary): ≥2x STRONG-FLIP,
        // ≥1.2x MODEST, else TIE/LOSS ⇒ DECLINE (incumbent stands)。
        print("ios27-P8 FLATTEN-MICRO-GATE " + lines.joined(separator: " | ")
            + " — flip requires a reviewed commit; TIE/LOSS = DECLINE "
            + "(亏的不要)")
    }
}
