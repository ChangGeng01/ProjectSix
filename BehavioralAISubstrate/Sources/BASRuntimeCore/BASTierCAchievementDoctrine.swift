// MARK: - BASTierCAchievementDoctrine
// chapter 五百八 / M1411 — typed milestone pinning Tier C
// ADR-019 implementation state
//
// Records HONESTLY what shipped at chapters 507-508:
//   - 4 of 4 candidate Tier C primitives shipped as
//     code (M1406 + M1407 + M1409 + M1410)
//   - 0 of 4 existing types yet migrated to use the
//     new primitives (migration is follow-up arc)
//
// HONEST DOCTRINE NOTE — chapter 五百八:
// =============================================================
// This doctrine separates "primitive shipped" from
// "migration complete":
//
//   - primitivesShipped = 4 (all 4 typed generic
//     primitives now exist)
//   - migrationsCompleted = 0 (no existing types yet
//     migrated)
//
// Total Tier C completion = primitives + migrations =
// 4/8 (~50%)。 The 4 typed primitives are the
// FOUNDATION;migrations consume them in follow-up arc。
//
// Renames captured honestly:
//   - "BASRiskCard" → "BASRiskObservationCard" (BASPolicy
//     collision)
//   - "BASArbitrationFrame" → "BASArbitrationObservation
//     Frame" (BASOrchestration collision)

import Foundation

/// Typed per-primitive shipment record。
public struct BASTierCPrimitiveRecord:
    Equatable, Hashable, Codable, Sendable
{
    public let proposalName: String
    public let actualShippedName: String
    public let mNumber: Int
    public let chapterTag: String
    public let renameReason: String?

    public init(
        proposalName: String,
        actualShippedName: String,
        mNumber: Int,
        chapterTag: String,
        renameReason: String? = nil
    ) {
        self.proposalName = proposalName
        self.actualShippedName = actualShippedName
        self.mNumber = mNumber
        self.chapterTag = chapterTag
        self.renameReason = renameReason
    }

    /// `true` when the actual shipped name differs from
    /// the proposal name (typically due to name
    /// collision with existing concrete types)。
    public var wasRenamed: Bool {
        proposalName != actualShippedName
    }
}

/// Doctrine namespace declaring Tier C ADR-019
/// implementation state at chapter 508 close-out。
public enum BASTierCAchievementDoctrine {

    /// Chapter range covering Tier C implementation。
    public static let chapterRange:
        ClosedRange<Int> = 507...508

    /// M-number range covering Tier C implementation。
    public static let mNumberRange:
        ClosedRange<Int> = 1405...1412

    /// Per-primitive shipment records HONESTLY capturing
    /// renames + chapter/M-number provenance。
    public static let primitives:
        [BASTierCPrimitiveRecord] = [

        BASTierCPrimitiveRecord(
            proposalName: "BASInspectionFrame<Body>",
            actualShippedName:
                "BASInspectionFrame<Body>",
            mNumber: 1406,
            chapterTag: "chapter 五百七"),

        BASTierCPrimitiveRecord(
            proposalName: "BASRiskCard<Kind, Body>",
            actualShippedName:
                "BASRiskObservationCard<Kind, Body>",
            mNumber: 1407,
            chapterTag: "chapter 五百七",
            renameReason:
                "name collision with existing concrete" +
                " BASPolicy.BASRiskCard (L11 risk-plane" +
                " struct)"),

        BASTierCPrimitiveRecord(
            proposalName: "BASArbitrationFrame<Body>",
            actualShippedName:
                "BASArbitrationObservationFrame<Body>",
            mNumber: 1409,
            chapterTag: "chapter 五百八",
            renameReason:
                "name collision with existing concrete" +
                " BASOrchestration.BASArbitrationFrame" +
                " (L10-tribunal struct)"),

        BASTierCPrimitiveRecord(
            proposalName:
                "BASGovernanceCard<Authority, Decision>",
            actualShippedName:
                "BASGovernanceCard<Authority, Decision>",
            mNumber: 1410,
            chapterTag: "chapter 五百八")
    ]

    /// Count of typed primitives shipped (target = 4)。
    public static var primitivesShipped: Int {
        primitives.count
    }

    /// HONEST count of existing types migrated to use
    /// the new primitives。 At chapter 509 close-out:
    /// 0 (typed primitives + adapters are pure-additive
    /// — no existing types are modified)。 Migrations
    /// are follow-up arc work。
    public static let migrationsCompleted: Int = 0

    /// chapter 五百九 / M1415 — typed adapters shipped
    /// (pure-function read-only converters from existing
    /// types to the Tier C primitives)。 Adapters provide
    /// the migration PATH without breaking existing
    /// callers。 At chapter 509:2 (BASRiskObservation
    /// CardAdapter + BASInspectionBundleFrameAdapter)。
    public static let typedAdaptersShipped: Int = 2

    /// Target migration count (4 existing types
    /// originally identified in the ADR-019 proposal)。
    public static let migrationTarget: Int = 4

    /// Combined Tier C completion (primitives +
    /// adapters + migrations) / (target × 3)。 At
    /// chapter 509: 4 + 2 + 0 = 6 of 12 = 50%。
    /// Three-layer accounting captures the progression
    /// from typed surface → typed adapter → actual
    /// migration honestly。
    public static var combinedCompletionRatio: Double {
        let total = primitivesShipped
            + typedAdaptersShipped
            + migrationsCompleted
        let target = migrationTarget * 3
        return Double(total) / Double(target)
    }

    /// Count of primitives that needed renaming due to
    /// name collisions。 Captured for honest doctrine
    /// audit。
    public static var renamedPrimitiveCount: Int {
        primitives.filter(\.wasRenamed).count
    }

    /// Honest summary string suitable for audit
    /// emission。
    public static var honestSummary: String {
        let pct = Int(
            combinedCompletionRatio * 100)
        return
            "Tier C ADR-019 implementation:" +
            " \(primitivesShipped)/4 typed primitives" +
            " shipped + \(typedAdaptersShipped)/4 typed" +
            " adapters + \(migrationsCompleted)/4 existing" +
            " type migrations = \(pct)% combined" +
            " completion。 \(renamedPrimitiveCount)" +
            " primitives renamed honestly due to existing-" +
            "name collisions。 Adapters provide the" +
            " migration PATH without breaking existing" +
            " callers — actual migration is follow-up" +
            " arc work。"
    }
}
