// MARK: - BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
// chapter 五百四十三 / M1550 — typed milestone doctrine
//                              tracking explicit Codable
//                              round-trip PROOF test
//                              coverage across the 9
//                              BASEBrainTurnResult
//                              cluster bundles
//
// Background:chapter 541 M1543 shipped compile-time
// Codable conformance checks for ALL 9 bundles。 The
// next layer of PROOF — explicit ENCODE-DECODE-COMPARE
// round-trip tests — has been rolling out incrementally:
//
//   - Chapter 542 / M1545:3 bundles via `.empty` defaults
//     (Evolution + Sovereign + AuditProjectionForward)
//   - Chapter 543 / M1549:adds 2 more via required-field
//     fixtures (Host + ForensicMetadata)
//   - Future arcs:remaining 4 (CognitiveFrames +
//     RiskChoice + Misc + DeviceLifecycle)
//
// This doctrine catalogues the current coverage state
// as a typed surface that anti-drift PROOF tests can
// pin。 Future drift (e.g. a 6th bundle gains round-trip
// coverage but the doctrine isn't updated) breaks the
// PROOF loudly。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     round-trip coverage state
//   - chapter 三百九二:replay-determinism via Codable
//     + sortedKeys JSON
//   - chapter 四百二十九:typed-surface count 88 → 89
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1549 → M1550

import Foundation

/// Coverage status for a single cluster bundle's
/// Codable round-trip PROOF test。
public enum BASEBrainTurnResultClusterBundleCodableRoundTripCoverageStatus:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    /// Compile-time Codable conformance checked
    /// (chapter 541 M1543) but no explicit round-trip
    /// test。
    case compileTimeOnly

    /// Explicit ENCODE-DECODE-COMPARE round-trip test
    /// shipped。
    case explicitRoundTripCovered
}

/// Typed entry pairing a cluster bundle's identity with
/// its current coverage status + the chapter where the
/// explicit coverage was shipped (if any)。
public struct BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry:
    Codable, Sendable, Equatable, Hashable
{
    public let bundleTypeName: String
    public let status:
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageStatus
    public let explicitCoverageMNumber: Int?

    public init(
        bundleTypeName: String,
        status:
            BASEBrainTurnResultClusterBundleCodableRoundTripCoverageStatus,
        explicitCoverageMNumber: Int?
    ) {
        self.bundleTypeName = bundleTypeName
        self.status = status
        self.explicitCoverageMNumber =
            explicitCoverageMNumber
    }
}

/// Typed namespace tracking explicit Codable round-trip
/// PROOF test coverage across the 9 cluster bundles。
public enum BASEBrainTurnResultClusterBundleCodableRoundTripCoverageDoctrine
{

    /// 9-entry coverage table — one per cluster bundle。
    /// Updated as coverage rolls out。
    public static let entries:
        [BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry] =
    [
        // Chapter 542 / M1545 — `.empty` defaults
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultEvolutionBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1545),
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultSovereignBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1545),
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultAuditProjectionForwardBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1545),

        // Chapter 543 / M1549 — required-field fixtures
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultHostBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1549),
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultForensicMetadataBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1549),

        // Chapter 544 / M1553 — Misc fixture added
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultMiscBundle",
            status: .explicitRoundTripCovered,
            explicitCoverageMNumber: 1553),

        // Pending (deeper fixture builders required)
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultCognitiveFramesBundle",
            status: .compileTimeOnly,
            explicitCoverageMNumber: nil),
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultRiskChoiceBundle",
            status: .compileTimeOnly,
            explicitCoverageMNumber: nil),
        BASEBrainTurnResultClusterBundleCodableRoundTripCoverageEntry(
            bundleTypeName:
                "BASEBrainTurnResultDeviceLifecycleBundle",
            status: .compileTimeOnly,
            explicitCoverageMNumber: nil)
    ]

    /// Total cluster bundles in the catalogue。 Pinned at
    /// 9 to match the fold arc invariant。
    public static let totalBundleCount: Int = 9

    /// Count of bundles with explicit round-trip
    /// coverage shipped。 Computed sum。
    public static var explicitlyCoveredCount: Int {
        entries.filter {
            $0.status == .explicitRoundTripCovered
        }.count
    }

    /// Count of bundles with only compile-time
    /// conformance (no explicit round-trip yet)。
    public static var compileTimeOnlyCount: Int {
        entries.filter {
            $0.status == .compileTimeOnly
        }.count
    }

    /// Coverage ratio (explicitly-covered / total)。 At
    /// M1550 == 5/9 ≈ 0.556。
    public static var coverageRatio: Double {
        return Double(explicitlyCoveredCount)
            / Double(totalBundleCount)
    }

    /// Confirms the catalogue's total matches the fold
    /// arc invariant + sum of per-status counts equals
    /// total。
    public static var catalogueIsConsistent: Bool {
        return entries.count == totalBundleCount
            && explicitlyCoveredCount
                + compileTimeOnlyCount
                == totalBundleCount
    }
}
