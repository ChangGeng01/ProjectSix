// MARK: - BASChapter527ParallelRunReconciliationDoctrine
// chapter 五百二十七 / M1487 — typed milestone documenting
//                              parallel-run reconciliation
//
// At chapter 526,two parallel autonomous /loop instances
// interleaved their work and produced a build-broken
// state:
//
//   - Run A committed BASEBrainTurnResultAuditProjection
//     ForwardBundle + 3-bundle init using audit-
//     projection-forward (commits b9329d99,baafe3fc,
//     0d3bb6e6)
//   - Run B (mine) committed BASEBrainTurnResultHost
//     Bundle + 3-bundle init using host (commits
//     b6c9d982,81745b97)
//   - Run A's M1483 V1 splice referenced BOTH
//     hostBundle AND auditProjectionForwardBundle but
//     no 4-bundle init existed to accept both
//   - Build was momentarily broken until M1485
//     reconciled
//
// chapter 527 ships:
//   - M1485 4-bundle convenience init closing the call-
//     site contract
//   - M1486 PROOF tests pinning 30-field invariant
//   - M1487 (this file) typed milestone documenting the
//     parallel-run lesson
//   - M1488 close-out + doctrine sync
//
// ## Lesson learned
//
// When two autonomous /loop instances run against the
// same branch,interleaved commits can create temporary
// build-broken states even if each instance's commits
// individually compile。 Mitigations:
//
//   1. Re-read file state before editing (don't trust
//      cached state across long pauses)
//   2. Build-verify before close-out chapters
//   3. Stress-sweep regression guard catches semantic
//      drift but NOT temporary build failures
//   4. Anti-drift hash refresh at close-out catches
//      cross-doctrine state mismatches
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved (full
//     test suite passes post-reconciliation)
//   - 红线 7:additive surface only — 4-bundle init is
//     purely additive
//   - chapter 一百八十五:typed milestone for the lesson
//   - chapter 二百一一:single source-of-truth for
//     parallel-run reconciliation pattern
//   - chapter 三百九二:replay-determinism preserved
//   - chapter 四百二十九:typed-surface count 72 → 73
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1486 → M1487

import Foundation

/// Typed milestone record documenting the chapter 527
/// parallel-run reconciliation lesson。 Pure value-type
/// doctrine — no side effects,no IO。
public struct BASChapter527ParallelRunReconciliationDoctrine:
    Equatable, Hashable, Sendable, Codable
{

    // MARK: - Reconciliation pins

    /// Chapter tag where the parallel-run drift
    /// occurred。
    public let driftChapterTag: String

    /// First M-number of the reconciling chapter (527
    /// 第一刀)。
    public let reconciliationStartMNumber: Int

    /// Last M-number of the reconciling chapter (527
    /// 第四刀)。
    public let reconciliationEndMNumber: Int

    /// Count of bundles unified by the M1485 4-bundle
    /// init (4)。
    public let bundleCountUnified: Int

    /// Total field count across the 4 unified bundles
    /// (30)。
    public let totalFieldCount: Int

    /// Number of distinct commit prefixes from the two
    /// parallel runs that needed reconciliation。
    public let parallelRunCommitCount: Int

    /// Test suite invariant:full suite passes post-
    /// reconciliation。
    public let postReconciliationFullSuitePasses: Bool

    // MARK: - Mitigation tags

    /// Mitigation strategies validated by chapter 527。
    public let validatedMitigations: [String]

    // MARK: - Construction

    public init(
        driftChapterTag: String,
        reconciliationStartMNumber: Int,
        reconciliationEndMNumber: Int,
        bundleCountUnified: Int,
        totalFieldCount: Int,
        parallelRunCommitCount: Int,
        postReconciliationFullSuitePasses: Bool,
        validatedMitigations: [String]
    ) {
        self.driftChapterTag = driftChapterTag
        self.reconciliationStartMNumber =
            reconciliationStartMNumber
        self.reconciliationEndMNumber =
            reconciliationEndMNumber
        self.bundleCountUnified = bundleCountUnified
        self.totalFieldCount = totalFieldCount
        self.parallelRunCommitCount =
            parallelRunCommitCount
        self.postReconciliationFullSuitePasses =
            postReconciliationFullSuitePasses
        self.validatedMitigations =
            validatedMitigations
    }

    // MARK: - Chapter-527-ship singleton

    /// Frozen ship-time record。
    public static let chapter527ShipRecord =
        BASChapter527ParallelRunReconciliationDoctrine(
            driftChapterTag: "chapter 五百二十六",
            reconciliationStartMNumber: 1485,
            reconciliationEndMNumber: 1488,
            bundleCountUnified: 4,
            totalFieldCount: 30,
            parallelRunCommitCount: 6,
            postReconciliationFullSuitePasses: true,
            validatedMitigations: [
                "re-read-file-state-before-edit",
                "build-verify-before-close-out",
                "stress-sweep-regression-guard",
                "anti-drift-hash-refresh-at-close-out",
                "4-bundle-init-as-call-site-contract",
            ])
}
