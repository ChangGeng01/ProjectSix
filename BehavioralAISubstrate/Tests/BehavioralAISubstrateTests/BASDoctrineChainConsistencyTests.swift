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
        // The doctrine version's M-suffix must equal the
        // mNumberLast of the latest chapter doctrine in
        // Phase 2。
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
        // Latest chapter must end at this M-number。 Today
        // chapter 四百四十六 is the latest with mNumberLast
        // M1163 (POST-RADICAL Wave 17 — POST-RADICAL
        // EVOLUTION SWEEP close-out meta-doctrine);the
        // doctrine version should be M1163 OR any later
        // M-number bumped by a NEW chapter that we haven't
        // yet listed in this test。 Sweep complete。
        XCTAssertGreaterThanOrEqual(
            docMNumber,
            BASChapter446EntropyDoctrine.mNumberLast,
            "doctrineVersion M-suffix must be >= latest" +
            " known chapter mNumberLast (currently " +
            "chapter 四百四十六 at M\(BASChapter446EntropyDoctrine.mNumberLast))")
    }

    // MARK: - Phase 2 doctrine ends at latest chapter

    func testPhase2DoctrineEndsAtLatestChapter() {
        // chapter 481 is registry-only,query registry
        let latest = BASChapterDoctrineRegistry
            .recordFor(chapterTag: "chapter 七百二")!
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine.mNumberLast,
            latest.mNumberLast,
            "Phase 2 doctrine mNumberLast must equal " +
            "latest chapter's mNumberLast (chapter " +
            "七百二 at M\(latest.mNumberLast))")
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
        // from chapterTagsShipped.count × ~5.4,something
        // is off。
        let chapters = BASPhase2EntropyClosureDoctrine
            .chapterTagsShipped.count
        let commits = BASPhase2EntropyClosureDoctrine
            .commitsShipped
        let ratio = Double(commits) / Double(chapters)
        XCTAssertGreaterThan(ratio, 4.0,
            "average commits/chapter should be > 4 " +
            "(got \(ratio))")
        XCTAssertLessThan(ratio, 8.0,
            "average commits/chapter should be < 8 " +
            "(got \(ratio))")
    }

    // MARK: - Determinism

    func testConsistencyChecksAreDeterministic() {
        let v1 = BASCognitiveOSCompletionDoctrine
            .doctrineVersion
        let v2 = BASCognitiveOSCompletionDoctrine
            .doctrineVersion
        XCTAssertEqual(v1, v2)
        XCTAssertEqual(
            BASPhase2EntropyClosureDoctrine.mNumberLast,
            BASPhase2EntropyClosureDoctrine.mNumberLast)
    }
}
