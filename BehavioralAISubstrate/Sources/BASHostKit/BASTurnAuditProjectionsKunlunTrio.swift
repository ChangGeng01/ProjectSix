// MARK: - BASTurnAuditProjectionsKunlunTrio
// chapter 四百七十八 / M1288 — V1 fold PILOT
//
// FIRST V1 monolith fold extraction in the substrate。
// Closes 3 of the 36 ForAudit shadow-local declarations
// in EBrainRuntimeCoordinator.runTurn(_:) — the
// `ascentLeaseForAudit` + `axisDeviationForAudit` +
// `gatePressureForAudit` trio at lines 1240-1255。
//
// ## Why this exists (system entropy framing)
//
// Chapter 477 deep-review scored "最激进 (V1 monolith)"
// at 0/10 → 1/10 because the 2,540 LOC monolith remained
// genuinely untouched。 The chapter 477 plan committed to
// a tiny pilot fold (3 projections) before the bulk fold
// in chapters 492-493, to validate that:
//
//   1. A typed factory bundle can extract pure-derive
//      projections without changing byte-output
//   2. BASStressSweepHarness dual-mode digest comparison
//      catches any byte-equality drift the fold introduces
//   3. The mechanical extraction pattern scales — 3
//      projections today,18+18 in cluster A+B later
//
// `BASTurnAuditProjectionsKunlunTrio` is that pilot
// extraction:
//
//   - Holds the 3 typed projections (`BASAscentLease`,
//     `BASAxisDeviation`, `BASGatePressure`) as fields
//   - Static `compute(...)` factory takes the exact
//     inputs the original declarations consumed
//     (routedBudget + riskLevel + permit + turnID +
//     sessionID + kunlunAxisID) and dispatches the 3
//     derive calls in the SAME ORDER as the
//     coordinator
//   - Coordinator replaces 3 separate `let *ForAudit =
//     ...` declarations with one `let trio =
//     BASTurnAuditProjectionsKunlunTrio.compute(...)`
//     call + 3 shadow re-bindings (`let
//     ascentLeaseForAudit = trio.ascentLease` etc.) so
//     EVERY downstream reader site is unchanged
//
// Byte-equality is GUARANTEED by construction:the
// compute order + inputs + outputs are identical to the
// monolith。 Stress-sweep dual mode (M1290) is the
// regression-guard PROOF。
//
// ## What this ships (M1288)
//
//   - `BASTurnAuditProjectionsKunlunTrio` struct with 3
//     typed projection fields
//   - `BASTurnAuditProjectionsKunlunTrio.compute(...)`
//     static factory dispatching the same 3 derive
//     calls in the same order as monolith lines
//     1240-1255
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — V1 byte-equality preserved
//     (factory's compute order matches monolith)
//   - chapter 一百八十五 — typed factory inputs +
//     typed projection field shape
//   - chapter 二百一一 — single source-of-truth (the
//     3 projections now live in one bundle)
//   - chapter 三百九二 — same inputs → same outputs;
//     stress-sweep dual mode (M1290) is the regression
//     guard
//   - ADR-014 OPT-IN — additive only。 No host caller
//     surface changes;coordinator internals shift but
//     public `runTurn(_:)` signature + return type
//     unchanged
//   - 红线 7 — projections are observation;commitment
//     authority unchanged
//   - chapter 四百七十七 plannedFutureCuts honored (V1
//     fold scoping)

import Foundation
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// Typed bundle holding the 3 Kunlun audit projections
/// extracted from `EBrainRuntimeCoordinator.runTurn(_:)`
/// at chapter 478。 Replaces 3 separate shadow-local
/// `let *ForAudit` declarations with a single typed
/// factory call。
public struct BASTurnAuditProjectionsKunlunTrio:
    Codable, Hashable, Sendable
{

    /// L6 ascent-lease watcher projection。 Pure-derive
    /// from `routedBudget` + `turnID`。
    public let ascentLease: BASAscentLease

    /// L6 axis-deviation watcher projection。 Pure-derive
    /// from `riskLevel` + `turnID` + `sessionID` +
    /// `kunlunAxisID`。
    public let axisDeviation: BASAxisDeviation

    /// L6 gate-pressure watcher projection。 Pure-derive
    /// from `riskLevel` + `permit` + `turnID` +
    /// `sessionID`。
    public let gatePressure: BASGatePressure

    public init(
        ascentLease: BASAscentLease,
        axisDeviation: BASAxisDeviation,
        gatePressure: BASGatePressure
    ) {
        self.ascentLease = ascentLease
        self.axisDeviation = axisDeviation
        self.gatePressure = gatePressure
    }

    // MARK: - Static factory

    /// Compute all 3 typed projections in the SAME ORDER
    /// the coordinator monolith did (lines 1240-1255 at
    /// chapter 477 baseline)。 Byte-equal by construction
    /// when consumed via shadow-rebinding。
    ///
    /// Parameters mirror the variables in scope at the
    /// coordinator's compute point:
    ///
    ///   - `routedBudget` — coordinator-local
    ///     BASBudgetFrame after powerClockService
    ///     normalization
    ///   - `riskLevel` — `boundRiskCard.riskLevel`
    ///     value at the projection-compute point
    ///   - `permit` — `boundActionPermit` value at the
    ///     projection-compute point (post-M385/M406,
    ///     pre-M449 escalation)
    ///   - `turnID` — `derivedTurnID` (M353 turn
    ///     identifier)
    ///   - `sessionID` — `derivedSessionID` (M353
    ///     session identifier)
    ///   - `kunlunAxisID` — `kunlunAxisForGate.axisID`
    ///     value at the projection-compute point
    public static func compute(
        routedBudget: BASBudgetFrame,
        riskLevel: BASBrainRiskLevel,
        permit: BASActionPermit,
        turnID: String,
        sessionID: String,
        kunlunAxisID: String
    ) -> BASTurnAuditProjectionsKunlunTrio {
        // Order matches coordinator lines 1240-1255。
        // Do NOT reorder — chapter 三百九二 replay-
        // determinism + chapter 四百七十七 byte-equality
        // pin both depend on identical compute sequence。
        let ascentLease = BASKunlunLayerProjections
            .AscentLease
            .derive(
                from: routedBudget,
                turnID: turnID)
        let axisDeviation = BASKunlunLayerProjections
            .AxisDeviation
            .derive(
                from: riskLevel,
                turnID: turnID,
                situationRef: sessionID,
                centerlineRef: kunlunAxisID)
        let gatePressure = BASKunlunLayerProjections
            .GatePressure
            .derive(
                from: riskLevel,
                permit: permit,
                turnID: turnID,
                situationRef: sessionID)
        return BASTurnAuditProjectionsKunlunTrio(
            ascentLease: ascentLease,
            axisDeviation: axisDeviation,
            gatePressure: gatePressure)
    }
}
