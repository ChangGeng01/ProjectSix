// MARK: - BASTurnAuditProjectionsLateClusterFinalBundle
// chapter 六百八十六 / M2114 第一刀 — Phase O opening:
//                                  Sendable bundle
//                                  consolidating the 3
//                                  Two/Penta cluster
//                                  results currently held
//                                  as separate locals in
//                                  EBrainRuntimeCoordinator
//                                  +RunTurn.swift。
//
// ## Why this bundle ships now (Phase O opening)
//
// EBrainRuntimeCoordinator+RunTurn.swift (1803 LOC at
// M2113) holds 3 ForAudit locals for the *Two/*Penta
// cluster results:
//
//   - kunlunTrioTwoForAudit (line 585):
//     BASTurnAuditProjectionsKunlunTrioTwo result
//   - kunlunHexaTwoForAudit (line 600):
//     BASTurnAuditProjectionsKunlunHexaTwo result
//   - cthulhuPentaForAudit (line 617):
//     BASTurnAuditProjectionsCthulhuPenta result
//
// Plus one derived local:
//   - ontologyFogForAudit = cthulhuPentaForAudit.ontologyFog
//
// Phase O 第一刀 ships the BUNDLE TYPE that can replace
// these locals + the derived field with a single typed
// factory call。 The actual +RunTurn.swift body update
// (replacing the 4 separate locals with 1 bundle call)
// lands at chapter 687 第一刀 / M2118 as the SECOND
// Phase O cut。
//
// This staged approach preserves V1 byte-equality at
// chapter 686 (no behavior change — bundle is shipped
// but unused) and provides a clean rollback point if
// the chapter 687 wiring step fails byte-equality
// regression。
//
// ## Honest Phase O scope
//
// The wild-rolling-meerkat plan envisioned Phase O as
// "V1 monolith body fold + DELETION" across 3 chapters。
// Honest implementation reality:
//
//   - Chapter 686 (this M2114): bundle TYPE shipped,
//     +RunTurn.swift body unchanged
//   - Chapter 687: WIRE-IN — replace 4 locals with
//     bundle factory call (byte-equality preserved)
//   - Chapter 688: V1-only helper method deletion +
//     close-out doctrine
//
// The 1803 → ~80 LOC delta the plan projected is
// aspirational — actual LOC reduction depends on what
// V2 substrate code can absorb the V1 audit-projection
// flow。 Honest LOC delta estimate:1803 → ~1600 (~-200)
// at chapter 686 + 687 boundary,larger reductions at
// chapter 688 if V2-canonical paths can fully replace
// V1 audit emission。
//
// ## Doctrine pins held
//
//   - chapter 一百八十五 — typed cluster final bundle
//     (no magic dictionary or untyped tuple)
//   - chapter 二百一一 — single source-of-truth (one
//     bundle type wraps the 3 cluster results)
//   - chapter 三百九二 — replay-determinism (Codable
//     round-trip across all 3 nested types)
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (bundle is additive at M2114;wire-in lands later)
//   - ADR-014 OPT-IN — purely additive
//   - 红线 7 — audit projection is observation only

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

/// Sendable bundle consolidating the 3 *Two/*Penta
/// cluster results carried as separate locals in
/// `EBrainRuntimeCoordinator+RunTurn.swift`。 Phase O
/// opening artifact — wire-in lands at chapter 687。
public struct BASTurnAuditProjectionsLateClusterFinalBundle:
    Equatable, Hashable, Sendable, Codable
{
    /// Kunlun trio #2 audit projection result (M1318)。
    public let kunlunTrioTwo:
        BASTurnAuditProjectionsKunlunTrioTwo

    /// Kunlun hexa #2 audit projection result (M1320)。
    public let kunlunHexaTwo:
        BASTurnAuditProjectionsKunlunHexaTwo

    /// Cthulhu penta audit projection result (M1322)。
    public let cthulhuPenta:
        BASTurnAuditProjectionsCthulhuPenta

    public init(
        kunlunTrioTwo:
            BASTurnAuditProjectionsKunlunTrioTwo,
        kunlunHexaTwo:
            BASTurnAuditProjectionsKunlunHexaTwo,
        cthulhuPenta:
            BASTurnAuditProjectionsCthulhuPenta
    ) {
        self.kunlunTrioTwo = kunlunTrioTwo
        self.kunlunHexaTwo = kunlunHexaTwo
        self.cthulhuPenta = cthulhuPenta
    }

    // MARK: - Derived accessors mirroring +RunTurn.swift
    // local-binding patterns

    /// Mirrors `ontologyFogForAudit = cthulhuPentaForAudit
    /// .ontologyFog` at +RunTurn.swift line 636。
    public var ontologyFog: BASOntologyFog {
        return cthulhuPenta.ontologyFog
    }

    /// Convenience accessor:bundled view as a tuple
    /// for callers that want both the 3 source clusters
    /// + the derived field in one read。
    public var tupleView: (
        trioTwo: BASTurnAuditProjectionsKunlunTrioTwo,
        hexaTwo: BASTurnAuditProjectionsKunlunHexaTwo,
        cthulhuPenta: BASTurnAuditProjectionsCthulhuPenta,
        ontologyFog: BASOntologyFog
    ) {
        return (
            kunlunTrioTwo,
            kunlunHexaTwo,
            cthulhuPenta,
            ontologyFog)
    }

    // MARK: - Compose factory (chapter 六百八十七 / M2118
    //         第一刀 wire-in candidate)
    //
    /// Convenience static factory that invokes the 3
    /// sub-cluster compute() methods + assembles the
    /// final bundle in a single call。 Mirrors the
    /// concatenation of:
    ///
    ///   BASTurnAuditProjectionsKunlunTrioTwo.compute(...)
    ///   BASTurnAuditProjectionsKunlunHexaTwo.compute(...)
    ///   BASTurnAuditProjectionsCthulhuPenta.compute(...)
    ///
    /// currently at +RunTurn.swift lines 585 + 600 + 617。
    /// The chapter 687 第二刀 (M2119) wire-in replaces
    /// the 3 separate compute calls + 1 derived field
    /// in +RunTurn.swift body with a single .compose()
    /// invocation。 Byte-equality preserved because the
    /// sub-compute args are passed verbatim。
    public static func compose(
        // Inputs threaded through to trioTwo.compute
        trioTwoRunMode: BASEBrainRunMode,
        trioTwoRiskLevel: BASBrainRiskLevel,
        trioTwoCandidates: [BASCandidatePath],
        trioTwoOrganRefMorph: String,
        trioTwoTurnID: String,
        trioTwoSessionID: String,
        // Inputs threaded through to hexaTwo.compute
        hexaTwoHostID: String,
        hexaTwoSessionID: String,
        hexaTwoTurnID: String,
        hexaTwoUnknownRefs: [String],
        hexaTwoAssertionCeiling:
            BASUnknownAssertionCeiling,
        hexaTwoRiskLevel: BASBrainRiskLevel,
        hexaTwoCandidates: [BASCandidatePath],
        // Inputs threaded through to cthulhuPenta.compute
        pentaRoutedBudget: BASBudgetFrame,
        pentaRunMode: BASEBrainRunMode,
        pentaHostID: String,
        pentaRiskLevel: BASBrainRiskLevel,
        pentaMemoryTemperatureLayer:
            BASMemoryTemperatureLayer,
        pentaCandidates: [BASCandidatePath],
        pentaUnknownRefs: [String],
        pentaAssertionCeilingRaw: String,
        pentaTurnID: String
    ) -> BASTurnAuditProjectionsLateClusterFinalBundle {
        let trio = BASTurnAuditProjectionsKunlunTrioTwo
            .compute(
                runMode: trioTwoRunMode,
                riskLevel: trioTwoRiskLevel,
                candidates: trioTwoCandidates,
                organRefMorph: trioTwoOrganRefMorph,
                turnID: trioTwoTurnID,
                sessionID: trioTwoSessionID)
        let hexa = BASTurnAuditProjectionsKunlunHexaTwo
            .compute(
                hostID: hexaTwoHostID,
                sessionID: hexaTwoSessionID,
                turnID: hexaTwoTurnID,
                unknownRefs: hexaTwoUnknownRefs,
                assertionCeiling:
                    hexaTwoAssertionCeiling,
                riskLevel: hexaTwoRiskLevel,
                candidates: hexaTwoCandidates)
        let penta = BASTurnAuditProjectionsCthulhuPenta
            .compute(
                routedBudget: pentaRoutedBudget,
                runMode: pentaRunMode,
                hostID: pentaHostID,
                riskLevel: pentaRiskLevel,
                memoryTemperatureLayer:
                    pentaMemoryTemperatureLayer,
                candidates: pentaCandidates,
                unknownRefs: pentaUnknownRefs,
                assertionCeilingRaw:
                    pentaAssertionCeilingRaw,
                turnID: pentaTurnID)
        return BASTurnAuditProjectionsLateClusterFinalBundle(
            kunlunTrioTwo: trio,
            kunlunHexaTwo: hexa,
            cthulhuPenta: penta)
    }
}
