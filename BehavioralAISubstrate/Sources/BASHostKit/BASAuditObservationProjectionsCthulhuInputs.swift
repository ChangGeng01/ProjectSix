// MARK: - BASAuditObservationProjectionsCthulhuInputs
// chapter 五百十一 / M1423 — V1 monolith fold continues
//
// Typed-surface aggregator for the 2 existing Cthulhu
// trio/penta factories that feed
// `BASAuditObservationProjections`。 Sibling of the M1421
// `BASAuditObservationProjectionsKunlunInputs` block。
//
// ## Why this exists
//
// The V1 monolith `runTurn(_:)` body computes 2 Cthulhu
// factory outputs:
//   1. `BASTurnAuditProjectionsAbyssalThermalTrio` (M1401)
//      — abyssalRunMode + abyssBudget +
//      memoryTemperatureLayer
//   2. `BASTurnAuditProjectionsCthulhuPenta` (M1322) —
//      abyssalOrganAlias + humanAnchorProfile +
//      sealedMemory + cosmicScaleView + ontologyFog
//
// 8 Cthulhu projection fields total。 This block holds
// both factory outputs as fields so V1 monolith can pass
// one `cthulhuInputs:` arg instead of 8 individual
// `*ForAudit` rebindings。
//
// **Byte-equality is GUARANTEED by construction** — pure
// packaging re-aggregation,no derive calls。 BAS
// StressSweep Harness dual mode (M1290) is the regression
// guard。
//
// ## Field count invariant
//
// `cthulhuFieldCount = 8` is pinned by the M1423 PROOF
// test。 If a future trio adds a field,this constant
// moves AND `BASAuditObservationProjections` gains a
// matching field,or the audit emission silently loses
// coverage。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive surface only
//   - chapter 一百八十五:typed enum + typed factory
//   - chapter 二百一一:single source-of-truth — 8
//     Cthulhu projections accessed via ONE typed surface
//   - chapter 三百九二:replay-determinism via Hashable
//     + Sendable
//   - chapter 四百二十九:typed surface count = 55
//   - ADR-014 OPT-IN:default mode unchanged
//   - ADR-016 advances M1422 → M1423

import Foundation
import BASOrchestration
import BASRuntimeCore
import BASMemory
import BASWorldPrior

/// Typed-surface block packaging the 2 Cthulhu trio/penta
/// factory outputs。 Pure packaging — no derive calls,no
/// transformations beyond the 2-pointer struct itself。
public struct BASAuditObservationProjectionsCthulhuInputs:
    Codable, Hashable, Sendable
{

    // MARK: - Inputs

    /// M1401 trio:abyssalRunMode + abyssBudget +
    /// memoryTemperatureLayer。
    public let abyssalThermalTrio:
        BASTurnAuditProjectionsAbyssalThermalTrio

    /// M1322 penta:abyssalOrganAlias + humanAnchorProfile
    /// + sealedMemory + cosmicScaleView + ontologyFog。
    public let cthulhuPenta:
        BASTurnAuditProjectionsCthulhuPenta

    // MARK: - Construction

    public init(
        abyssalThermalTrio:
            BASTurnAuditProjectionsAbyssalThermalTrio,
        cthulhuPenta:
            BASTurnAuditProjectionsCthulhuPenta
    ) {
        self.abyssalThermalTrio = abyssalThermalTrio
        self.cthulhuPenta = cthulhuPenta
    }

    /// Pure packaging factory — same inputs in,same
    /// outputs。 No derive calls。 Used by V1 monolith to
    /// fold 2 separate factory outputs into one typed
    /// surface。
    public static func compose(
        abyssalThermalTrio:
            BASTurnAuditProjectionsAbyssalThermalTrio,
        cthulhuPenta:
            BASTurnAuditProjectionsCthulhuPenta
    ) -> BASAuditObservationProjectionsCthulhuInputs {
        return BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio: abyssalThermalTrio,
            cthulhuPenta: cthulhuPenta)
    }

    // MARK: - Pass-through accessors

    public var abyssalRunMode: BASAbyssalRunMode {
        abyssalThermalTrio.abyssalRunMode
    }
    public var abyssBudget: BASAbyssBudget {
        abyssalThermalTrio.abyssBudget
    }
    public var memoryTemperatureLayer:
        BASMemoryTemperatureLayer
    {
        abyssalThermalTrio.memoryTemperatureLayer
    }

    public var abyssalOrganAlias: BASAbyssalOrganAlias {
        cthulhuPenta.abyssalOrganAlias
    }
    public var humanAnchorProfile:
        BASHumanAnchorProfile
    {
        cthulhuPenta.humanAnchorProfile
    }
    public var sealedMemory: BASSealedMemory? {
        cthulhuPenta.sealedMemory
    }
    public var cosmicScaleView: BASCosmicScaleView {
        cthulhuPenta.cosmicScaleView
    }
    public var ontologyFog: BASOntologyFog {
        cthulhuPenta.ontologyFog
    }

    // MARK: - Field count invariant

    /// Total Cthulhu projection fields surfaced via this
    /// block — pinned by the M1423 PROOF test
    /// `testCthulhuInputsCarriesEightFields`。
    public static let cthulhuFieldCount: Int = 8
}

// MARK: - chapter 五百十一 / M1423 — Convenience init on
//                                    BASAuditObservation
//                                    Projections
//
// Mirror of the M1422 Kunlun-inputs convenience init —
// accepts a Cthulhu inputs block + remaining non-Cthulhu
// fields。

extension BASAuditObservationProjections {

    /// Convenience init that accepts a Cthulhu inputs
    /// block + remaining non-Cthulhu fields。 Unpacks the
    /// block's 8 trio/penta outputs into the matching
    /// projections fields。
    ///
    /// Byte-equality with the all-fields init is
    /// GUARANTEED by the body — every field copied 1:1
    /// from block accessors or from explicit non-Cthulhu
    /// args。 The M1423 PROOF test
    /// `testCthulhuConvenienceInitEqualsAllFieldsInit`
    /// is the regression guard。
    public init(
        cthulhuInputs:
            BASAuditObservationProjectionsCthulhuInputs,
        candidateObservationBundle:
            BASCandidateObservationBundle? = nil,
        tribunalObservationBundle:
            BASTribunalObservationBundle? = nil,
        abyssalPressure: BASAbyssalPressure? = nil,
        humanAnchorSignal: BASHumanAnchorSignal? = nil,
        sealAggregate:
            BASOldSealSealingProtocol.Aggregate? = nil,
        lifecycleAggregate:
            BASEvolutionLifecycleSession.Aggregate? = nil,
        narrativeDistortion: BASNarrativeDistortion? = nil,
        anomalyTrace: BASAnomalyTrace? = nil,
        abyssalBranches: [BASAbyssalBranch] = [],
        unknownReserve: BASUnknownReserve? = nil,
        forbiddenAggregate:
            BASForbiddenKnowledgeCandidate.Aggregate? = nil,
        ontologyShiftMark: BASOntologyShiftMark? = nil,
        cthulhuAssertionCeilingReasonCodes: [String] = [],
        cthulhuPermitEscalationReasonCodes: [String] = [],
        narrativeDistortionMap:
            BASNarrativeDistortionMap? = nil,
        cthulhuSurfaceAlias:
            BASCthulhuSurfaceAlias? = nil
    ) {
        self.init(
            candidateObservationBundle:
                candidateObservationBundle,
            tribunalObservationBundle:
                tribunalObservationBundle,
            abyssalPressure: abyssalPressure,
            humanAnchorSignal: humanAnchorSignal,
            sealAggregate: sealAggregate,
            lifecycleAggregate: lifecycleAggregate,
            narrativeDistortion: narrativeDistortion,
            anomalyTrace: anomalyTrace,
            abyssalBranches: abyssalBranches,
            unknownReserve: unknownReserve,
            forbiddenAggregate: forbiddenAggregate,
            // 8 Cthulhu fields unpacked from the block
            cosmicScaleView:
                cthulhuInputs.cosmicScaleView,
            ontologyFog: cthulhuInputs.ontologyFog,
            ontologyShiftMark: ontologyShiftMark,
            abyssalRunMode:
                cthulhuInputs.abyssalRunMode,
            abyssBudget: cthulhuInputs.abyssBudget,
            cthulhuAssertionCeilingReasonCodes:
                cthulhuAssertionCeilingReasonCodes,
            cthulhuPermitEscalationReasonCodes:
                cthulhuPermitEscalationReasonCodes,
            memoryTemperatureLayer:
                cthulhuInputs.memoryTemperatureLayer,
            narrativeDistortionMap:
                narrativeDistortionMap,
            sealedMemory: cthulhuInputs.sealedMemory,
            humanAnchorProfile:
                cthulhuInputs.humanAnchorProfile,
            abyssalOrganAlias:
                cthulhuInputs.abyssalOrganAlias,
            cthulhuSurfaceAlias: cthulhuSurfaceAlias)
    }
}
