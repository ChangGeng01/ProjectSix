// MARK: - BASAuditObservationProjectionsKunlunInputs
// chapter 五百十一 / M1421 — V1 monolith fold continues
//
// Typed-surface aggregator for the 4 existing Kunlun trio /
// hexa factories that feed `BASAuditObservationProjections`。
// Folds 4 separate factory outputs into ONE typed parameter
// block so the projections call site can name a single
// `kunlunInputs:` argument instead of 18 individual fields。
//
// ## Why this exists
//
// Today the V1 monolith `runTurn(_:)` body computes 4
// Kunlun factory outputs:
//   1. `BASTurnAuditProjectionsKunlunTrio` (M1288) —
//      ascentLease + axisDeviation + gatePressure
//   2. `BASTurnAuditProjectionsKunlunHexa` (M1316) —
//      yaochiMemoryLayer + tianhengProfile + jadePermitGrade
//      + ascentBranches + restSteps + returnPaths
//   3. `BASTurnAuditProjectionsKunlunTrioTwo` (M1318) —
//      jadeCasket + jadeRefinementTickets + jadeFidelityMap
//   4. `BASTurnAuditProjectionsKunlunHexaTwo` (M1320) —
//      hostJadeRegister + jadeMirrorDraft + kunlunUnnamableSet
//      + returnPathRefs + kunlunAscentView + kunlunFarWestReserve
//
// The audit projections inline construction at coordinator
// line 2035 then UNPACKS each trio back into ~18 individual
// `let *ForAudit = kunlunXForAudit.field` rebindings and
// passes each as a separate named argument。 This block
// closes that unpack loop:
//
//   - Holds all 4 typed factory outputs as fields
//   - Static `compose(...)` factory takes the 4 trio outputs
//     in the same order as the monolith computes them
//   - Audit projections gains a M1422 convenience init that
//     accepts `kunlunInputs:` and unpacks internally — single
//     source-of-truth for the unpack expression
//
// **Byte-equality is GUARANTEED by construction:** the block
// is a transparent re-aggregation of fields the V1 monolith
// already binds today。 No new derive calls;no field
// reordering at audit-emission time。 BASStressSweep Harness
// dual mode (M1290) remains the regression-guard PROOF。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved (block
//     is a packaging surface,not a behavior change)
//   - 红线 7:additive surface only — old fields stay
//   - chapter 一百八十五:typed enum + typed factory
//     throughout
//   - chapter 二百一一:single source-of-truth — the 18
//     Kunlun trio output fields are accessed via ONE typed
//     surface (kunlunInputs) at the projections call site
//   - chapter 三百九二:replay-determinism — Hashable +
//     Sendable so digest comparison sees stable hashing
//   - chapter 四百二十九:typed surface count = 54
//   - ADR-014 OPT-IN:default mode `.v1ByteEqual` unchanged
//   - ADR-016 advances M1420 → M1421
//
// ## Future
//
//   - M1423 ships sibling `BASAuditObservationProjections
//     CthulhuInputs` aggregator covering the 5+ Cthulhu
//     trio outputs (abyssal + thermal + cosmic-scale +
//     ontology fog + ontology shift)
//   - M1422 wires this block into `BASAuditObservation
//     Projections.init(kunlunInputs:...)` convenience
//     factory

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed-surface block packaging the 4 Kunlun trio / hexa
/// factory outputs that the V1 monolith `runTurn(_:)` body
/// feeds into `BASAuditObservationProjections`。
///
/// All fields are immutable references to existing typed
/// trios。 Constructing this block is pure packaging — no
/// derive calls,no transformations,no allocations
/// beyond the 4-pointer struct itself。
public struct BASAuditObservationProjectionsKunlunInputs:
    Codable, Hashable, Sendable
{

    // MARK: - Inputs

    /// M1288 trio:ascentLease + axisDeviation + gatePressure。
    public let trio: BASTurnAuditProjectionsKunlunTrio

    /// M1316 hexa:yaochiMemoryLayer + tianhengProfile +
    /// jadePermitGrade + ascentBranches + restSteps +
    /// returnPaths。
    public let hexa: BASTurnAuditProjectionsKunlunHexa

    /// M1318 trio #2:jadeCasket + jadeRefinementTickets +
    /// jadeFidelityMap。
    public let trioTwo: BASTurnAuditProjectionsKunlunTrioTwo

    /// M1320 hexa #2:hostJadeRegister + jadeMirrorDraft +
    /// kunlunUnnamableSet + returnPathRefs + kunlunAscentView
    /// + kunlunFarWestReserve。
    public let hexaTwo: BASTurnAuditProjectionsKunlunHexaTwo

    // MARK: - Construction

    public init(
        trio: BASTurnAuditProjectionsKunlunTrio,
        hexa: BASTurnAuditProjectionsKunlunHexa,
        trioTwo: BASTurnAuditProjectionsKunlunTrioTwo,
        hexaTwo: BASTurnAuditProjectionsKunlunHexaTwo
    ) {
        self.trio = trio
        self.hexa = hexa
        self.trioTwo = trioTwo
        self.hexaTwo = hexaTwo
    }

    /// Pure packaging factory — same inputs in,same
    /// outputs。 No derive calls。 Used by V1 monolith to
    /// fold 4 separate factory outputs into one typed
    /// surface。
    public static func compose(
        trio: BASTurnAuditProjectionsKunlunTrio,
        hexa: BASTurnAuditProjectionsKunlunHexa,
        trioTwo: BASTurnAuditProjectionsKunlunTrioTwo,
        hexaTwo: BASTurnAuditProjectionsKunlunHexaTwo
    ) -> BASAuditObservationProjectionsKunlunInputs {
        return BASAuditObservationProjectionsKunlunInputs(
            trio: trio,
            hexa: hexa,
            trioTwo: trioTwo,
            hexaTwo: hexaTwo)
    }

    // MARK: - Convenience field accessors
    //
    // Pass-through helpers so call sites that need a single
    // field can reach it without re-typing the trio path.
    // These mirror the names used by `BASAuditObservation
    // Projections` so M1422 splice is a one-line copy。

    public var ascentLease: BASAscentLease { trio.ascentLease }
    public var axisDeviation: BASAxisDeviation {
        trio.axisDeviation
    }
    public var gatePressure: BASGatePressure {
        trio.gatePressure
    }

    public var yaochiMemoryLayer: BASYaochiMemoryLayer {
        hexa.yaochiMemoryLayer
    }
    public var tianhengProfile: BASTianhengProfile {
        hexa.tianhengProfile
    }
    public var jadePermitGrade: BASJadePermitGrade {
        hexa.jadePermitGrade
    }
    public var ascentBranches: [BASAscentBranch] {
        hexa.ascentBranches
    }
    public var restSteps: [BASRestStep] { hexa.restSteps }
    public var returnPaths: [BASReturnPath] {
        hexa.returnPaths
    }

    public var jadeCasket: BASJadeCasketSnapshot {
        trioTwo.jadeCasket
    }
    public var jadeRefinementTickets:
        [BASJadeRefinementTicket]
    {
        trioTwo.jadeRefinementTickets
    }
    public var jadeFidelityMap: BASJadeFidelityMap {
        trioTwo.jadeFidelityMap
    }

    public var hostJadeRegister: BASHostJadeRegister {
        hexaTwo.hostJadeRegister
    }
    public var jadeMirrorDraft: BASJadeMirrorDraft {
        hexaTwo.jadeMirrorDraft
    }
    public var kunlunUnnamableSet: BASKunlunUnnamableSet? {
        hexaTwo.kunlunUnnamableSet
    }
    public var returnPathRefs: [String] {
        hexaTwo.returnPathRefs
    }
    public var kunlunAscentView: BASKunlunAscentView {
        hexaTwo.kunlunAscentView
    }
    public var kunlunFarWestReserve:
        BASKunlunFarWestReserve?
    {
        hexaTwo.kunlunFarWestReserve
    }

    // MARK: - Field count invariant

    /// Total Kunlun projection fields surfaced via this
    /// block — pinned by the M1421 PROOF test
    /// `testKunlunInputsCarriesEighteenFields`。 If a future
    /// trio adds a field,this constant moves AND
    /// `BASAuditObservationProjections` gains a matching
    /// field,or the audit emission silently loses
    /// coverage。
    public static let kunlunFieldCount: Int = 18
}
