// MARK: - BASCoordinatorDeadDeclarationPurgeDoctrine
// chapter 五百三十四 / M1514 — typed milestone doctrine
//                              for the 30-declaration
//                              dead-code purge in
//                              EBrainRuntimeCoordinator
//                              .swift
//
// Earlier V1 fold work (chapters 478-492 / M1289-M1345)
// created "shadow re-bindings" — local let declarations
// that preserved the OLD variable names while the new
// typed factory call (BASTurnAuditProjectionsKunlunTrio
// .compute(...) etc.) replaced the original inline
// derive calls。 The pattern was:
//
//   // Was: let ascentLeaseForAudit = computeAscentLease(...)
//   // Now: let kunlunTrioForAudit = factory.compute(...)
//   //      let ascentLeaseForAudit = kunlunTrioForAudit
//   //          .ascentLease  ← shadow re-binding
//
// The shadow re-bindings preserved downstream reader
// sites unchanged during the fold,maintaining V1 byte-
// equality with minimal blast radius。
//
// As the projections fold matured (chapters 511-522),
// downstream readers migrated to typed input blocks
// (BASAuditObservationProjectionsKunlunInputs etc.) that
// consume the trio/hexa/penta factory outputs DIRECTLY
// via their typed accessors。 The shadow re-bindings
// then became unreferenced — pure dead code carrying
// no functional purpose。
//
// At chapter 534 M1513,30 such dead declarations were
// removed in a single commit。 Build warning count went
// from 60 → 0 on the coordinator。 Byte-equality risk:
// zero (pure-accessor reads with no side effects)。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface (this doctrine + the
//     deletions are net-additive to the typed surface
//     count via the new doctrine,net-subtractive on
//     dead code)
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth for the
//     purge milestone
//   - chapter 三百九二:replay-determinism via
//     stress-sweep canonical60 × 3 repeat runs (0
//     divergences)
//   - chapter 四百二十九:typed-surface count 79 → 80
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1513 → M1514

import Foundation

/// Typed milestone surface commemorating the 30-
/// declaration dead-code purge at coordinator at chapter
/// 534 / M1513。
///
/// Earlier V1 fold work created shadow re-bindings that
/// preserved old variable names during typed-factory
/// migrations。 As the fold matured and downstream
/// readers migrated to typed input blocks,the shadows
/// became dead code。 This doctrine catalogues which
/// shadows were purged + records the build-warning-
/// count delta as a non-driftable invariant。
public enum BASCoordinatorDeadDeclarationPurgeDoctrine {

    /// The 30 dead declarations purged at M1513,grouped
    /// by their origin cluster + chapter。 Each entry
    /// pairs the variable name with the cluster it
    /// originally fell out of。
    public static let purgedDeclarations:
        [(name: String, cluster: String)] =
    [
        // Cluster A — abyssalThermalTrio (chapter 506 M1402)
        ("abyssalRunModeForAudit", "abyssalThermalTrio"),
        ("abyssBudgetForAudit", "abyssalThermalTrio"),

        // Cluster A — kunlunTrio (chapter 478 M1289)
        ("ascentLeaseForAudit", "kunlunTrio"),
        ("axisDeviationForAudit", "kunlunTrio"),
        ("gatePressureForAudit", "kunlunTrio"),

        // Cluster A — kunlunHexa (chapter 485 M1317)
        ("yaochiMemoryLayerForAudit", "kunlunHexa"),
        ("tianhengProfileForAudit", "kunlunHexa"),
        ("jadePermitGradeForAudit", "kunlunHexa"),
        ("ascentBranchesForAudit", "kunlunHexa"),
        ("restStepsForAudit", "kunlunHexa"),
        ("returnPathsForAudit", "kunlunHexa"),

        // Cluster A — kunlunTrioTwo (chapter 485 M1318)
        ("jadeCasketForAudit", "kunlunTrioTwo"),
        ("jadeRefinementTicketsForAudit", "kunlunTrioTwo"),
        ("jadeFidelityMapForAudit", "kunlunTrioTwo"),

        // Cluster A — kunlunHexaTwo (chapter 486 M1320)
        ("hostJadeRegisterForAudit", "kunlunHexaTwo"),
        ("jadeMirrorDraftForAudit", "kunlunHexaTwo"),
        ("kunlunUnnamableSetForAudit", "kunlunHexaTwo"),
        ("returnPathRefsForAudit", "kunlunHexaTwo"),
        ("kunlunAscentViewForAudit", "kunlunHexaTwo"),
        ("kunlunFarWestReserveForAudit", "kunlunHexaTwo"),

        // Cluster B start — cthulhuPenta (chapter 486 M1322)
        ("abyssalOrganAliasForAudit", "cthulhuPenta"),
        ("humanAnchorProfileForAudit", "cthulhuPenta"),
        ("sealedMemoryForAudit", "cthulhuPenta"),
        ("cosmicScaleViewForAudit", "cthulhuPenta"),

        // Late-stage — lifecycleQuartet
        ("synthesizedSealsForAudit", "lifecycleQuartet"),
        ("lifecycleSessionsForAudit", "lifecycleQuartet"),

        // Late-stage — lateClusterC
        ("hostFragilityForAudit", "lateClusterC"),

        // Late-stage — lateClusterD
        ("forbiddenCandidatesForAudit", "lateClusterD"),

        // Late-stage — kunlunAxisProtocol
        ("kunlunMatched", "kunlunAxisProtocol"),

        // Late-stage — surfaceTrio (chapter 492 M1345)
        ("surfaceModeForAudit", "surfaceTrio")
    ]

    /// Count of purged declarations。 Pinned at 30。
    public static let purgedDeclarationCount: Int = 30

    /// Build warning count BEFORE the purge (M1512)。
    public static let preWarningCount: Int = 60

    /// Build warning count AFTER the purge (M1513)。
    /// Should be 0 for the coordinator file (other
    /// files unchanged)。
    public static let postWarningCount: Int = 0

    /// Byte-equality preserved at the purge commit。
    public static let byteEqualityPreserved: Bool = true

    /// Replay-determinism PROOF method used:
    /// stress-sweep canonical60 × 3 repeat runs
    /// returning 0 divergences。
    public static let replayDeterminismProof: String =
        "stress-sweep-canonical60-3-runs-0-divergence"

    /// The 11 origin clusters from which dead shadows
    /// were purged。
    public static var originClusterCount: Int {
        Set(purgedDeclarations.map { $0.cluster })
            .count
    }
}
