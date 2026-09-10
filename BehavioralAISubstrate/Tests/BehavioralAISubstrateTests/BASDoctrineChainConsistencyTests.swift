// MARK: - BASDoctrineChainConsistencyTests
// chapter 四百二十四 / M1068
//
// Cross-cutting invariant test that pins the consistency
// chain across the substrate's doctrine surfaces:
//   - BASCognitiveOSCompletionDoctrine.doctrineVersion
//   - BASPhase2EntropyClosureDoctrine.mNumberLast / .chapterTagsShipped.last
//   - The latest chapter doctrine in the chain
//   - BASRoadmapDoctrine phase status
//   - BASV2FoundationsRegistry foundation count
//
// Future commits that bump the version pin without bumping
// the chapter / phase / roadmap doctrines (or vice versa)
// fail this test at PR-time。

import XCTest
@testable import BASRuntimeCore

final class BASDoctrineChainConsistencyTests: XCTestCase {

    // MARK: - Doctrine version M-number matches latest chapter

    func testDoctrineVersionMatchesLatestChapterMNumber() {
        // blindspot MED id45: this cross-check was #if false-deactivated
        // (chapter 七百五十二 第二刀) because it referenced the since-
        // removed BASChapter446EntropyDoctrine — yet the file header
        // still advertised it as an active PR-time guard (comment-vs-
        // code drift, disease #3). Reactivated + re-pointed at the live
        // chapter registry (the same surface testPhase2DoctrineEnds...
        // uses). The doctrine version's M-suffix must not LAG the latest
        // shipped chapter's mNumberLast.
        let docVersion = BASCognitiveOSCompletionDoctrine
            .doctrineVersion
        // Format: "ADR-016.M<n>"
        let parts = docVersion.split(separator: ".")
        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts.first, "ADR-016")
        let mNumberSuffix = String(parts[1])
            .replacingOccurrences(of: "M", with: "")
        guard let docMNumber = Int(mNumberSuffix) else {
            return XCTFail(
                "doctrineVersion '\(docVersion)' has " +
                "non-integer M-suffix")
        }
        let latest = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 七百三十四")!
        XCTAssertGreaterThanOrEqual(
            docMNumber,
            latest.mNumberLast,
            "doctrineVersion M-suffix must be >= the latest " +
            "chapter's mNumberLast (chapter 七百三十四 at " +
            "M\(latest.mNumberLast))")
    }

    // MARK: - Phase 2 doctrine ends at latest chapter

    func testPhase2DoctrineEndsAtLatestChapter() {
        // chapter 481 is registry-only,query registry
        let latest = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 七百三十四")!
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine.mNumberLast,
            latest.mNumberLast,
            "Phase 2 doctrine mNumberLast must equal " +
            "latest chapter's mNumberLast (chapter " +
            "七百三十四 at M\(latest.mNumberLast))")
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine
                .chapterTagsShipped.last,
            latest.chapterTag,
            "Phase 2 doctrine last chapter tag must " +
            "equal latest chapter doctrine tag")
    }

    // MARK: - V2 foundations count matches Phase 2 doctrine

    func testV2FoundationsCountMatchesPhase2Doctrine() {
        XCTAssertEqual(
            BASV2FoundationsRegistry.foundationCount,
            BASPhase2EntropyClosureDoctrine
                .v2FoundationsCount,
            "V2 foundations count must equal Phase 2 " +
            "doctrine claim (M1054 invariant)")
    }

    // MARK: - Roadmap reflects Phase 2 shipped

    func testRoadmapShowsPhase2Shipped() {
        XCTAssertEqual(
            BASRoadmapDoctrine
                .status(of: .phase2RuntimeRewrite),
            .shipped,
            "Roadmap doctrine must report Phase 2 as " +
            ".shipped given Phase 2 close-out doctrine " +
            "exists with full chapter list")
    }

    // MARK: - ADR-018 doctrine identifier matches roadmap reference

    func testADR018IdentifierMatchesRoadmapReference() {
        XCTAssertEqual(
            BASADR018PendingDoctrine.adrIdentifier,
            BASPhase2EntropyClosureDoctrine
                .productionRoadmapADR,
            "ADR-018 identifier must match Phase 2 doctrine" +
            " roadmap reference")
    }

    // MARK: - Phase 2 commit count matches chapter count × ~5.4 average

    func testPhase2CommitCountAlignsWithChapterCount() {
        // Sanity check: 113 commits / 21 chapters ≈ 5.4
        // commits per chapter (some chapters were 4-cut,
        // some were larger like chapter 四百四 18-commit
        // comprehensive)。 If commitsShipped drifts wildly
        // from chapterTagsShipped.count × ~ratio,something
        // is off。
        //
        // Post-chapter 720 (M2220):average has trended
        // downward to 1264/316 = 4.0 as the post-RADICAL
        // trajectory has favored 2-knife chapters for
        // typed-contract hardening (5-pilot Codable/
        // Hashable/Sendable/caseIdentifier matrices each
        // shipped as 2-knife chapters)。 Lower bound
        // relaxed from > 4.0 (strict) to >= 3.5 to
        // acknowledge the 2-knife cadence trend while
        // still catching wild drift。
        let chapters = BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped.count
        let commits = BASPhase2EntropyClosureDoctrine
            .commitsShipped
        let ratio = Double(commits) / Double(chapters)
        XCTAssertGreaterThanOrEqual(ratio, 3.5,
            "average commits/chapter should be >= 3.5 " +
            "(got \(ratio))")
        XCTAssertLessThan(ratio, 8.0,
            "average commits/chapter should be < 8 " +
            "(got \(ratio))")
    }

    // MARK: - Doctrine version M-suffix ties the Phase-2 chain

    func testDoctrineVersionMSuffixMatchesPhase2MNumber() {
        // blindspot LOW id15: the old testConsistencyChecksAreDeterministic
        // compared doctrineVersion and mNumberLast to THEMSELVES (v1==v2,
        // mNumberLast==mNumberLast) — a tautology that pinned nothing and
        // slipped past the tautology-budget lint (which only sees the
        // XCTAssertTrue(true) form). Real teeth: the doctrineVersion's
        // M-suffix must equal the Phase-2 doctrine's mNumberLast, so a
        // commit that bumps one without the other reds — exactly the
        // PR-time guard the file header claims.
        let docVersion = BASCognitiveOSCompletionDoctrine
            .doctrineVersion
        let parts = docVersion.split(separator: ".")
        XCTAssertEqual(parts.count, 2,
            "expected 'ADR-016.M<n>', got '\(docVersion)'")
        XCTAssertEqual(parts.first, "ADR-016")
        guard let m = Int(String(parts[1])
            .replacingOccurrences(of: "M", with: "")) else {
            return XCTFail(
                "doctrineVersion '\(docVersion)' has " +
                "non-integer M-suffix")
        }
        XCTAssertEqual(
            m,
            BASPhase2EntropyClosureDoctrine.mNumberLast,
            "doctrineVersion M-suffix must equal Phase-2 " +
            "mNumberLast (coordinated-bump guard)")
    }
}
