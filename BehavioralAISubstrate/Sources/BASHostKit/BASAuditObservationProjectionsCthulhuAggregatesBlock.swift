// MARK: - BASAuditObservationProjectionsCthulhuAggregatesBlock
// chapter 五百十七 / M1445 — 5th typed input block for
//                            audit projections
//
// Aggregates the 7 L1-L7 Cthulhu-doctrine aggregate
// fields that feed `BASAuditObservationProjections`。
// 5th sibling of the chapter 511-516 typed input block
// series:
//   - M1421 KunlunInputs (18 trio/hexa fields)
//   - M1423 CthulhuInputs (8 trio/penta fields)
//   - M1433 ObservationBundles (11 cognitive bundles)
//   - M1441 KunlunProtocolBlock (9 protocol fields)
//   - M1445 (this file) CthulhuAggregatesBlock (7
//     L1-L7 aggregate fields)
//
// ## Why this exists
//
// Post-M1443 V1 monolith fold,the residual ~13 named
// args at the projections call site include a 7-field
// cluster of Cthulhu doctrine aggregates spanning
// layers L1-L7:
//
//   1. abyssalPressure (L1 pressure aggregate)
//   2. humanAnchorSignal (L5 anchor signal)
//   3. sealAggregate (L8/L9 seal aggregate)
//   4. lifecycleAggregate (L13 evolution lifecycle)
//   5. narrativeDistortion (L7 narrative distortion)
//   6. anomalyTrace (L1/L3 anomaly trace)
//   7. abyssalBranches (L1/L7 abyssal branches)
//
// These 7 fields are derived from the Cthulhu doctrine
// chain (abyssal pressure → narrative distortion →
// anomaly trace → abyssal branches + seal aggregate +
// lifecycle aggregate + human anchor)。 Packaging them
// into ONE typed input block reduces the V1 call-site
// arg count by 7。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 7
//     Cthulhu aggregate fields accessed via ONE typed
//     surface
//   - chapter 三百九二:replay-determinism via Equatable
//     + Sendable
//   - chapter 四百二十九:typed-surface count 62 → 63
//   - ADR-014 OPT-IN:default behavior unchanged
//   - ADR-016 advances M1444 → M1445

import Foundation
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// Typed-surface block packaging the 7 L1-L7 Cthulhu-
/// doctrine aggregate fields that feed audit projections。
/// 6 optional fields + 1 array (abyssalBranches has
/// default [])。
public struct BASAuditObservationProjectionsCthulhuAggregatesBlock:
    Codable, Equatable, Sendable
{

    // MARK: - 7 L1-L7 Cthulhu aggregate fields

    /// L1 abyssal pressure aggregate。
    public let abyssalPressure: BASAbyssalPressure?

    /// L5 human anchor signal。
    public let humanAnchorSignal: BASHumanAnchorSignal?

    /// L8/L9 seal aggregate from old-seal sealing
    /// protocol。
    public let sealAggregate:
        BASOldSealSealingProtocol.Aggregate?

    /// L13 evolution lifecycle aggregate。
    public let lifecycleAggregate:
        BASEvolutionLifecycleSession.Aggregate?

    /// L7 narrative distortion record。
    public let narrativeDistortion: BASNarrativeDistortion?

    /// L1/L3 anomaly trace。
    public let anomalyTrace: BASAnomalyTrace?

    /// L1/L7 abyssal branches (non-optional,defaults
    /// to empty)。
    public let abyssalBranches: [BASAbyssalBranch]

    // MARK: - Construction

    public init(
        abyssalPressure: BASAbyssalPressure? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        sealAggregate:
            BASOldSealSealingProtocol.Aggregate? = nil,
        lifecycleAggregate:
            BASEvolutionLifecycleSession.Aggregate? = nil,
        narrativeDistortion:
            BASNarrativeDistortion? = nil,
        anomalyTrace: BASAnomalyTrace? = nil,
        abyssalBranches: [BASAbyssalBranch] = []
    ) {
        self.abyssalPressure = abyssalPressure
        self.humanAnchorSignal = humanAnchorSignal
        self.sealAggregate = sealAggregate
        self.lifecycleAggregate = lifecycleAggregate
        self.narrativeDistortion = narrativeDistortion
        self.anomalyTrace = anomalyTrace
        self.abyssalBranches = abyssalBranches
    }

    // MARK: - Coverage queries

    /// Count of optional fields that are non-nil + 1
    /// if abyssalBranches has any。 0-7。
    public var populatedFieldCount: Int {
        var n = 0
        if abyssalPressure != nil { n += 1 }
        if humanAnchorSignal != nil { n += 1 }
        if sealAggregate != nil { n += 1 }
        if lifecycleAggregate != nil { n += 1 }
        if narrativeDistortion != nil { n += 1 }
        if anomalyTrace != nil { n += 1 }
        if !abyssalBranches.isEmpty { n += 1 }
        return n
    }

    /// `true` when all 7 fields populated。
    public var hasFullCthulhuCoverage: Bool {
        populatedFieldCount == 7
    }

    /// `true` when ZERO fields populated — host emitted
    /// projection without any Cthulhu aggregate data。
    public var hasNoCthulhuCoverage: Bool {
        populatedFieldCount == 0
    }

    /// All-nil empty singleton for tests + minimal-
    /// projection hosts。
    public static let empty =
        BASAuditObservationProjectionsCthulhuAggregatesBlock()

    /// Field count invariant — 7 L1-L7 aggregate fields。
    public static let aggregateFieldCount: Int = 7
}
