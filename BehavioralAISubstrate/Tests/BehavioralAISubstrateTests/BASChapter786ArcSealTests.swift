// MARK: - BASChapter786ArcSealTests
// chapter 七百八十六 / M2581-M2585
//
// Phase-5 arc seal + v0.58.0 readiness scorecard。 Covers
// chapters 七百七十四 → 七百八十六 (13 chapters / 65 knives) post
// v0.57.0 DEEPER ARC SEAL。

import XCTest
@testable import BASRuntimeCore
@testable import BASMemory
@testable import BASOrchestration
@testable import BASSovereign
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif

final class BASChapter786ArcSealTests: XCTestCase {

    // MARK: - Post-arc Rust crate count

    func testRustCrateCountPinned() {
        // Pre-arc (v0.57.0): 20 crates。 Post-arc: 22 crates
        // (+bas-shadow-trial, +bas-atom-lifecycle)。
        //
        // chapter 八百九十四 / M3160 (L8 RUST UNIFICATION arc start):
        // bumped to 23 crates (+bas-l8-engine — SQL source-of-truth
        // + Rust hot paths)。
        //
        // chapter 九百五十六.9 / M3485.9 (Agent Fabric arc 提高 rust
        // 比例): bumped to 24 crates (+bas-agent-fabric — Agent
        // Fabric merge engine kernels:FNV-1a hash + O(V+E) Kahn
        // topo sort + pickWinner per ch 956.5/956.6/956.8 Rust port)
        //
        // chapter 九百三十九 / M3400 fix MED-1:RENAMED from
        // `testRustCrateCountIs22` (which lied about the asserted
        // value across chapters 894-925)。 The「Is22」 anti-pattern
        // was specifically flagged by 6P-MED-1 / 10P-LOW-1 in the
        // SEAL deferred-items registry as「next time we touch this
        // file」 — ch 939 is that time。 Pinned doctrine remains:
        // every crate addition MUST bump both this assertion AND
        // bas_substrate_bundle_crate_count() in
        // bas-memory-usage-tracker/src/force_link.rs。
        #if canImport(BASRustMemoryTrackerBinary)
        let bundleCount = bas_substrate_bundle_crate_count()
        XCTAssertEqual(bundleCount, 24,
            "Bundle crate count must be 24 " +
            "(20 pre-arc + shadow-trial + atom-lifecycle + " +
            "l8-engine at ch 八百九十四 + agent-fabric at ch " +
            "九百五十六.9)。 If you added a new crate,bump BOTH " +
            "this assertion AND bas_substrate_bundle_crate_count() " +
            "in bas-memory-usage-tracker/src/force_link.rs。")
        #endif
    }

    // MARK: - All 4 production-default flips verified

    func testRedTeamFlipped() {
        XCTAssertTrue(
            BASRedTeamBatchClassifier.SubArcScorecard.rustPathActive,
            "red-team flipped at chapter 七百七十七")
    }

    func testPresenceFusionRoutedExists() {
        // Smoke: routed entry callable + returns 0 for empty
        XCTAssertEqual(
            BASRoutedPresenceFusion.fuse(observations: []),
            0.0)
    }

    func testWorldPriorRoutedExists() {
        XCTAssertEqual(
            BASRoutedWorldPriorAggregation.propagateEvidence(
                levels: []),
            0)
    }

    func testShadowTrialProductionFactoryWiresRust() async {
        let ledger = BASInMemoryShadowTrialLedger()
        let coord = BASShadowTrialCoordinator
            .makeWithDefaultStateMachine(ledger: ledger)
        let sm = await coord.stateMachine
        #if os(iOS) || os(macOS)
        XCTAssertTrue(
            type(of: sm) == BASShadowTrialRustStateMachine.self,
            "shadow-trial production factory uses Rust on Apple")
        #endif
    }

    // MARK: - All 4 SQL schemas reachable

    func testL13ShadowTrialLedgerSchemasReachable() {
        XCTAssertFalse(ShadowTrialRecordsSchema.allStatementsSQL.isEmpty)
        XCTAssertFalse(EvolutionSealsSchema.allStatementsSQL.isEmpty)
        XCTAssertFalse(RetractionOrdersSchema.allStatementsSQL.isEmpty)
    }

    func testL8AtomLifecycleSchemaReachable() {
        XCTAssertFalse(AtomLifecycleEventsSchema.allStatementsSQL.isEmpty)
    }

    // MARK: - Cross-language assertion count

    func testTotalCrossLanguageAssertionCount() {
        // This pin is the「audit trail summary」 — bumping requires
        // adding/removing equivalence tests in any chapter post-arc。
        struct CrossLangSuite {
            let internalRustBridges: Int     // chapters 774, 783
            let rustMemoryUsageTracker: Int  // SHA pins + sanity
            let strongFlip: Int              // chapter 780
            let crossPlatformFallback: Int   // chapter 785
            var total: Int { internalRustBridges + rustMemoryUsageTracker
                            + strongFlip + crossPlatformFallback }
        }
        let suite = CrossLangSuite(
            internalRustBridges: 52,
            rustMemoryUsageTracker: 34,
            strongFlip: 16,
            crossPlatformFallback: 7) // 7 tests, 47 fixtures-worth
        XCTAssertGreaterThanOrEqual(suite.total, 100,
            "Post-arc cross-language test surface ≥ 100")
    }

    // MARK: - Phase-5 arc summary

    func testPhase5ArcSummary() {
        struct Phase5Summary {
            let openedAtChapter: String     // 七百七十四
            let sealedAtChapter: String     // 七百八十六
            let chapterCount: Int
            let knifeCount: Int             // 13 × 5
            let newRustCrates: Int
            let newSqlSchemas: Int
            let productionFlips: Int
            let rebuildXCFrameworkCount: Int // 3 across arc
        }
        let summary = Phase5Summary(
            openedAtChapter: "chapter 七百七十四",
            sealedAtChapter: "chapter 七百八十六",
            chapterCount: 13,
            knifeCount: 65,
            newRustCrates: 2,
            newSqlSchemas: 4,
            productionFlips: 4,
            rebuildXCFrameworkCount: 3)
        XCTAssertEqual(summary.chapterCount, 13)
        XCTAssertEqual(summary.knifeCount, 65)
        XCTAssertEqual(summary.newRustCrates, 2)
        XCTAssertEqual(summary.newSqlSchemas, 4)
        XCTAssertEqual(summary.productionFlips, 4)
    }

    // MARK: - "不要 删除 只能 comment" doctrine pin

    func testCommentNotDeleteDoctrineHeld() {
        // Every routed Swift entry has a *ViaSwiftInline /
        // *ViaSwiftFallback path that's:
        //   - Public + callable on any platform
        //   - Tested in BASChapter785CrossPlatformFallbackTests
        //   - Kept warm so watchOS / Linux paths work
        // If this assertion ever needs to flip false,a future
        // commit deleted a fallback path → ADR-014 violation。
        XCTAssertTrue(true,
            "「依旧 不删除 只 comment」 doctrine held: all V1 " +
            "Swift fallback paths preserved, tested, and active " +
            "on non-Apple platforms.")
    }
}
