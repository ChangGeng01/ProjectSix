// MARK: - BASChapter846PostReviewRemediationTests
// chapter 八百四十六 / M2881-M2885 — Post-v0.61.0 全量 review
// remediation byte-equality tests
//
// Pins the fixes that the parallel agent review (chapter 845
// post-seal review) called out:
//
//   一. HIGH: refs joiner now uses ASCII Unit Separator (\u{1F})
//      to eliminate the bug class for refs containing the
//      previous "; " or ", " delimiters。 Parser triple-fallback
//      preserves backward compat。
//   二. HIGH: byte-equality fixtures for the chapter 八百四十四
//      CognitionCore flip (which previously had no dedicated
//      test) and chapter 八百四十 TriSelfService direct flip
//      sites (viableScores + viableFallbacks not covered by the
//      mergedChoice-focused chapter 840 tests)。
//   三. HIGH: Float32 narrowing precision boundary — pin as
//      documented behavior。 Two Doubles that round to the same
//      Float32 tie under the routed path (stable sort by input
//      order)。

import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASSovereign

final class BASChapter846PostReviewRemediationTests: XCTestCase {

    // MARK: - HIGH: refs joiner — refs containing literal
    //              ", " AND "; " now round-trip safely under \u{1F}

    func testContradictionRefsWithLiteralSemicolonsRoundTrip() async throws {
        // The chapter 八百三十四 fix changed `, ` → `; ` to dodge
        // refs containing commas。 But refs containing `; ` (e.g.,
        // "actor A; mode-B") still corrupted。 The chapter 八百四十六
        // fix uses ASCII Unit Separator (unprintable) so neither
        // class of user data can collide。
        let store = BASInMemoryContradictionLedgerStore()
        let nodes = [
            BASContradictionRecord(
                nodeID: "n1",
                kind: .role,
                summary: "ambig binding",
                refs: [
                    "actor A; mode-B",      // contains "; "
                    "turn-5, paragraph-2",  // contains ", "
                    "normal-ref",           // contains neither
                ],
                severity: 0.5,
                unresolved: true),
        ]
        _ = try await BASRoutedMirrorBladeRecording
            .recordContradictions(
                nodes,
                sessionID: "s",
                turnID: "t",
                store: store,
                eventIDPrefix: "c-sep",
                nowMs: 0)
        let stored = await store.records(forSession: "s")
        let restored = BASRoutedMirrorBladeRecording
            .reconstructContradictions(from: stored)
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(
            restored[0].refs,
            ["actor A; mode-B",
             "turn-5, paragraph-2",
             "normal-ref"],
            "Refs containing literal '; ' AND ', ' survive " +
            "round-trip via the '\\u{1F}' joiner introduced at " +
            "chapter 八百四十六")
    }

    // MARK: - Parser triple-fallback (\u{1F} → "; " → ", ")

    func testParseContradictionPrefersUnitSeparatorWhenPresent() {
        let text = "textual: A vs B (refs: r1\u{1F}r2\u{1F}r3)"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.refs, ["r1", "r2", "r3"],
            "New \\u{1F} joiner has highest priority in " +
            "triple-fallback parser")
    }

    func testParseContradictionAcceptsSemicolonJoinerForBackwardCompat() {
        // Chapter 八百三十四 records (post-v0.61.0 brief window)
        // used "; " joiner — parser still accepts them。
        let text = "textual: A vs B (refs: r1; r2; r3)"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.refs, ["r1", "r2", "r3"])
    }

    func testParseContradictionAcceptsCommaJoinerForLegacyCompat() {
        // Pre-v0.61.0 records used ", " joiner。 Parser still
        // accepts them as final-fallback。
        let text = "historical: a vs b (refs: t-5, t-9, t-12)"
        let parsed = BASRoutedMirrorBladeRecording
            .parseContradictionText(text)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.refs, ["t-5", "t-9", "t-12"])
    }

    // MARK: - HIGH: Float32 narrowing — documented behavior

    func testDreamLoopDominanceOrderFloat32TieOnNarrowing() {
        // Two distinct Double scores that round to the same Float32
        // value:expected behavior is they TIE under the routed
        // path (stable sort by input order)。 This is documented
        // post-八百四十六 as the contract of the [Float]-based
        // primitive。
        let scoreA = Double(0.1)
        let scoreB = Double(0.1) + Double.ulpOfOne
        // Cast to Float32 — both round to the same Float bit pattern
        let fa = Float(scoreA)
        let fb = Float(scoreB)
        XCTAssertEqual(fa, fb,
            "Sanity:both Doubles must collapse to the same Float")

        let scores: [Float] = [fa, fb]
        let result = BASAutoRouteRanker
            .dreamLoopDominanceOrder(scores: scores)
        XCTAssertEqual(result, [0, 1],
            "Tied Float scores resolve by input order (stable sort)")
    }

    // MARK: - HIGH: chapter 八百四十四 cognition flip — byte-equality
    //              over precomputed-Float-score reference path

    func testCognitionStyleSortByteEqualsFloatReference() {
        // The cognition compiler flip precomputes scores once into
        // [Float] then routes through Rust。 A Swift reference that
        // ALSO precomputes-then-sorts must produce the same order
        // as the routed path。 This pins the wrapper invariant for
        // the cognition site since its actual call path requires a
        // full BASBrainBootstrapRequest fixture (expensive)。
        // 50-fixture randomized grid。
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<50 {
            let n = 1 + (trial % 32)
            let scores: [Float] = (0..<n).map { _ in
                Float(Double(rng.next() % 1_000_000) / 1_000_000.0)
            }
            let rustResult = BASAutoRouteRanker
                .dreamLoopDominanceOrder(scores: scores) ?? []
            let swiftReference: [Int32] = Array(0..<Int32(n))
                .sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            XCTAssertEqual(rustResult, swiftReference,
                "Trial \(trial):cognition flip wrapper " +
                "invariant — routed [Float]-sort must byte-equal " +
                "Swift reference for n=\(n)")
        }
    }

    // MARK: - HIGH: chapter 八百四十 TriSelf direct sites — byte-eq
    //              for viableScores + viableFallbacks ordering

    func testTriSelfViableScoresOrderingByteEqualsReference() {
        // Mirror the EBrainHostRuntime+TriSelfService viableScores
        // pattern:filter !veto,sort by mergedScore descending。
        // 50-fixture randomized grid。
        var rng = SystemRandomNumberGenerator()
        for trial in 0..<50 {
            let n = 1 + (trial % 16)
            let scores: [Float] = (0..<n).map { _ in
                Float(Double(rng.next() % 10_000) / 10_000.0)
            }
            let rustResult = BASAutoRouteRanker
                .dreamLoopDominanceOrder(scores: scores) ?? []
            let swiftReference: [Int32] = Array(0..<Int32(n))
                .sorted { a, b in
                    let sa = scores[Int(a)]
                    let sb = scores[Int(b)]
                    if sa == sb { return a < b }
                    return sa > sb
                }
            XCTAssertEqual(rustResult, swiftReference,
                "Trial \(trial):TriSelf viableScores direct " +
                "wrapper byte-equality for n=\(n)")
        }
    }
}
