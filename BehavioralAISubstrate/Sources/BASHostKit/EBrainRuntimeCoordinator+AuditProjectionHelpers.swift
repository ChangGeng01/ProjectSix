// MARK: - EBrainRuntimeCoordinator+AuditProjectionHelpers
// chapter 六百 / M1777 — V1 monolith continuation:
//                       extracts the 3 audit-projection
//                       static helpers + their supporting
//                       constants from the V1 monolith
//                       into a sibling extension file
//
// ## What moves
//
// Three pure static helpers (called via `Self.xxx` from
// `runTurn` in the V1 monolith) + 1 supporting reveal-
// conditions array + 1 status-classifier + 4 public
// per-turn reconciliation constants:
//
//   - deriveYaochiAuditProjection(...)
//   - deriveHeavenGateAuditProjection(...)
//   - deriveLayerReconciliationReport(...)
//   - yaochiAuditRevealConditions
//   - coverageStatus(observations:core:)
//   - layerReconciliationExpectedLayers (public)
//   - layerReconciliationExpectedLayerIDs (public)
//   - fullCoverageExpectedLayerIDs (public)
//   - layerReconciliationBudgetCeiling (public)
//
// = 367 LOC moved out of EBrainRuntimeCoordinator.swift。
// V1 monolith shrinks 2472 → ~2105 LOC。
//
// ## Visibility transitions
//
//   - 3 derive helpers:`fileprivate static` →
//     `internal static` (callers in main coordinator
//     file need cross-file access)
//   - yaochiAuditRevealConditions:stays `fileprivate
//     static` — only consumed by the co-located
//     deriveYaochiAuditProjection within THIS file
//   - coverageStatus:stays `internal static` (was
//     already internal-by-default;
//     EBrainRuntimeCoordinator+SovereignCommit.swift
//     already calls `Self.coverageStatus(...)`)
//   - 4 public constants:stay `public static let`
//     (cross-package callers unchanged)
//
// ## Byte-equality
//
// Pure code MOVE — no logic change。 V1 byte-equality
// preserved by construction (same function bodies,
// same constants,same static dispatch through `Self`)。
// BASStressSweepCanonical60Driver regression guard
// verifies no per-turn behavioral change。
//
// ## Doctrine pins
//
//   - 不变量 #1/#2/#3:V1 byte-equality preserved
//   - 红线 7:additive — no behavior change (pure move)
//   - chapter 一百八十五:typed enum + typed factory
//     preserved
//   - chapter 二百一一:single source-of-truth (still
//     reachable through `Self` from the V1 monolith)
//   - chapter 三百九二:replay-determinism unchanged
//   - chapter 478 / chapter 489-493 V1 fold precedent
//     (this is the same line of work — Phase I
//     continuation)
//   - ADR-014 OPT-IN preserved
//   - ADR-016 advances M1776 → M1777

import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASWorldPrior

extension BASEBrainRuntimeCoordinator {

    /// M425 (chapter 一百一) — extracted Yaochi audit projection
    /// helper. Pre-extraction this 38-line block lived inline in
    /// `runTurn`; the extraction is part of the "shrink runTurn"
    /// refactor down-payment per chapter 九十八 deep-review M418-3.
    /// Pure function: same inputs always produce same outputs;
    /// no side effects. M408 doctrine pin (Yaochi sanctum 默认
    /// 不参与普通检索) still holds — the derive synthesizes an
    /// audit-only projection.
    ///
    /// chapter 六百 M1777:visibility broadened `fileprivate` →
    /// `internal` for cross-file `Self.deriveYaochiAuditProjection`
    /// call from the V1 monolith。
    internal static func deriveYaochiAuditProjection(
        sessionID: String,
        candidateID: String,
        hostID: String,
        hasQuarantines: Bool,
        humanAnchorTone: BASHumanAnchorTone,
        permitMode: BASActionPermitMode
    ) -> (entry: BASYaochiSanctumEntry,
          access: BASKunlunYaochiProtocol.AccessDecision)
    {
        let sanctumClass: BASYaochiSanctumClass =
            hasQuarantines ? .sensitive : .boundary
        let entry = BASYaochiSanctumEntry(
            entryID: "yaochi-\(sessionID)",
            memoryRef: candidateID,
            hostRef: hostID,
            sanctumClass: sanctumClass,
            accessPolicy: .conditional,
            revealConditions: yaochiAuditRevealConditions,
            coolingPeriod: 60,
            humanAnchorRequired: true,
            lastRevealedAt: "")
        let matchedConditions: [String] = {
            switch permitMode {
            case .answer, .mirror, .compare:
                return ["host-explicit-recall"]
            default:
                return []
            }
        }()
        let access = BASKunlunYaochiProtocol
            .evaluateAccess(
                entry: entry,
                hostAnchorPresent:
                    humanAnchorTone != .reserved,
                matchedRevealConditions: matchedConditions,
                secondsSinceLastReveal: 86400)
        return (entry: entry, access: access)
    }

    /// M425 (chapter 一百一) — extracted Heaven Gate audit
    /// projection helper. Pre-extraction this ~50-line block
    /// lived inline in `runTurn`. Pure function: same inputs
    /// always produce same outputs; no side effects. M409
    /// doctrine pin (七 transition gates) still holds — the
    /// derive synthesizes an audit-only projection of the
    /// Heaven Gate protocol's readiness check.
    ///
    /// chapter 六百 M1777:visibility broadened `fileprivate` →
    /// `internal` for cross-file call from V1 monolith。
    internal static func deriveHeavenGateAuditProjection(
        sessionID: String,
        candidateID: String,
        permitMode: BASActionPermitMode,
        warrantIDs: [String],
        verdictLevel: BASSovereignVerdictLevel,
        requireSecondCheck: Bool
    ) -> (permit: BASHeavenGatePermit,
          readiness: BASKunlunHeavenGateProtocol.Readiness)
    {
        let gateClass: BASKunlunGateClass = {
            switch permitMode {
            case .answer, .mirror:
                return .public
            case .compare, .draftOnly:
                return .cognitive
            case .delay, .replace, .localOnly:
                return .cognitive
            case .escalate, .block:
                return .host
            }
        }()
        let passState: BASKunlunGateState
        switch verdictLevel {
        case .pass:
            passState = .passed
        case .throttle, .shadowLock:
            passState = .pending
        case .toolCut, .memoryFreeze, .quarantine:
            passState = .remanded
        case .rollback, .deadStop:
            passState = .denied
        }
        let permit = BASHeavenGatePermit(
            gateID: "tianmen-\(sessionID)",
            sourceRef: candidateID,
            targetDomain:
                "domain-\(permitMode.rawValue)",
            gateClass: gateClass,
            requiredSeals:
                warrantIDs.map { "seal-\($0)" },
            actionPermitRef:
                "permit-\(permitMode.rawValue)",
            sovereignWarrantRef: warrantIDs.first ?? "",
            secondCheckRequired: requireSecondCheck,
            passState: passState,
            returnPathRef:
                "rollback-\(sessionID)")
        let readiness = BASKunlunHeavenGateProtocol
            .evaluateReadiness(permit)
        return (permit: permit, readiness: readiness)
    }

    /// 2-condition reveal-conditions list used by the M408 Yaochi
    /// audit-projection derive (audit-only, fixed conditions).
    /// chapter 六百 M1777:stays fileprivate — only consumed by
    /// the co-located deriveYaochiAuditProjection in this file。
    fileprivate static let yaochiAuditRevealConditions: [String] = [
        "host-explicit-recall",
        "anchor-tone-warm",
    ]

    /// M436 (chapter 一百四) — close the 14-layer reconciliation
    /// loop. Pre-fix the substrate had ALL 12 observation bundles
    /// derived per turn (L1/L2/L3/L5/L6/L7/L8/L10/L11/L12/L13 +
    /// L4 worldPrior) but the
    /// `BASObservationReconciliationVerdictEngine.evaluate(...)`
    /// library was NEVER called from production code — only from
    /// tests. Per chapter 一百四 deep architecture audit
    /// (`docs/QINAO_M436_DEEP_ARCHITECTURE_AUDIT_2026-05-03.md`):
    /// 36% of layers were "极致" (load-bearing); 57% were "运转
    /// not maxed" (derived but unread). This helper composes the
    /// per-turn `BASObservationReconciliationReport` from the 12
    /// bundles + a candidate-bundle adapter, runs the verdict
    /// engine, and returns both. The verdict + report go into
    /// audit signalRefs so audit walkers can grep
    /// `reconciliation.severity:halt` etc.
    ///
    /// Pure function: no actor / no IO. The bundles' `.coverageSummary`
    /// projections are stable.
    ///
    /// chapter 六百 M1777:visibility broadened `fileprivate` →
    /// `internal` for cross-file call from V1 monolith。
    internal static func deriveLayerReconciliationReport(
        thoughtFrame: BASThoughtFrame,
        presenceBundle: BASPresenceObservationBundle?,
        decompositionBundle: BASDecompositionObservationBundle?,
        candidateBundle: BASCandidateObservationBundle?,
        turnID: String,
        sessionID: String,
        emittedAt: Date
    ) -> (report: BASObservationReconciliationReport,
          verdict: BASObservationReconciliationVerdict)
    {
        // M436.5 (chapter 一百八 perf recovery) — build the
        // summaries array directly + construct the report once.
        // Pre-M436.5 each `.appending(...)` call (a) constructed
        // a new `BASObservationReconciliationReport` struct with
        // dedup+filter pass on the entire summaries array
        // (O(n²) total over 13 appends) and (b) allocated a new
        // copy of the summaries array on each call. Consolidating
        // to one report construction with a pre-built summaries
        // array runs the dedup+filter once, not 13 times.
        // Recovers ~7-9% of the chapter 一百七 +11.3% test-path
        // perf cost. Pure value-type rewrite, semantically
        // equivalent — `BASObservationReconciliationReport.init`
        // (line 160) runs the same dedup+filter pass that
        // `.appending` would have applied iteratively.
        // M438 (chapter 一百十三 anti-magic-number sweep) —
        // route the capacity hint through the static expected-
        // layers list so a future drift adding/removing a
        // layer (or the L14 sovereign opt-in) updates one
        // place instead of two. Pre-M438 this was hardcoded
        // `13` literal which would silently mismatch
        // `Self.layerReconciliationExpectedLayers.count` if
        // the static array changed.
        var summaries: [BASObservationCoverageSummary] = []
        summaries.reserveCapacity(
            Self.layerReconciliationExpectedLayers.count)
        // L1-L13 cognitive bundles. Order matches
        // `layerReconciliationExpectedLayers` for stable
        // `reconciliation.observed:<L1+L2+...+L13>` emission;
        // `BASObservationReconciliationReport.dedupedAndFiltered`
        // preserves first-seen order so this layout is stable.
        if let b = thoughtFrame.leaseLifeObservationBundle {
            summaries.append(b.coverageSummary)        // L1
        }
        if let b = thoughtFrame.neuralOrganObservationBundle {
            summaries.append(b.coverageSummary)        // L2
        }
        if let b = thoughtFrame.thoughtFoldObservationBundle {
            summaries.append(b.coverageSummary)        // L3
        }
        if let b = thoughtFrame.worldPriorObservationBundle {
            summaries.append(b.coverageSummary)        // L4
        }
        if let b = thoughtFrame.hostConstitutionObservationBundle {
            summaries.append(b.coverageSummary)        // L5
        }
        if let b = presenceBundle {
            summaries.append(b.coverageSummary)        // L6
        }
        if let b = decompositionBundle {
            summaries.append(b.coverageSummary)        // L7
        }
        if let b = thoughtFrame.hippocampalMemoryObservationBundle {
            summaries.append(b.coverageSummary)        // L8
        }
        if let b = candidateBundle {
            // L9 candidate bundle is constructed by
            // `BASNeuralMaterializationCompiler.buildCandidateObservationBundle`
            // with non-canonical `turnID = "l9.turn.step-N"` /
            // `sessionID = decomposeRef`. Pre-M436 the
            // `appending(_:)` guard at line 233 silently no-op'd
            // on key mismatch, dropping L9. M436 normalized; M436.5
            // continues normalization in the consolidated build.
            let raw = b.coverageSummary
            summaries.append(
                BASObservationCoverageSummary(
                    layer: raw.layer,
                    turnID: turnID,
                    sessionID: sessionID,
                    totalObservations: raw.totalObservations,
                    distinctSubjectCount: raw.distinctSubjectCount,
                    hasCoreSignalCoverage: raw.hasCoreSignalCoverage,
                    budgetTotalCost: raw.budgetTotalCost,
                    emittedAt: raw.emittedAt))   // L9
        }
        if let b = thoughtFrame.tribunalObservationBundle {
            summaries.append(b.coverageSummary)        // L10
        }
        if let b = thoughtFrame.riskObservationBundle {
            summaries.append(b.coverageSummary)        // L11
        }
        if let b = thoughtFrame.softHandObservationBundle {
            summaries.append(b.coverageSummary)        // L12
        }
        if let b = thoughtFrame.updateTicketObservationBundle {
            summaries.append(b.coverageSummary)        // L13
        }
        let report = BASObservationReconciliationReport(
            turnID: turnID,
            sessionID: sessionID,
            summaries: summaries)
        // Run verdict against the report. ExpectedLayers list:
        // every layer the substrate expects to hear from on a
        // healthy turn. Today this is the 12 cognitive layers
        // above. Any layer in the list that didn't emit becomes
        // a `.missingLayer` finding in the verdict. Hoisted to
        // a type-level `static let` (M436.2 chapter 一百六 N-1
        // fix) so the array isn't reallocated each turn — pure
        // value list with no per-turn dependency.
        let expectedLayers = Self.layerReconciliationExpectedLayers
        // M436.1 — budget ceiling alignment with Qinao path
        // (default 1.0). M438 (chapter 一百十三) replaced 1.0
        // literal with `layerReconciliationBudgetCeiling`
        // static constant so future adjustments drop in one
        // place. The verdict engine clamps to [0, 1]
        // internally; pre-M436.1 the helper hardcoded 12.0
        // which collapsed to 1.0 in strict comparison (both
        // wrong AND a no-op).
        let verdict = BASObservationReconciliationVerdictEngine
            .evaluate(
                report: report,
                expectedLayers: expectedLayers,
                budgetCeiling: Self
                    .layerReconciliationBudgetCeiling,
                emittedAt: emittedAt)
        return (report: report, verdict: verdict)
    }

    /// M436.2 (chapter 一百六 deep-review M-1/M-2 fix) — pure
    /// 3-way classifier mapping (observations count, core
    /// signal coverage) → audit-emission status string. Status
    /// is `empty` when the bundle has zero observations,
    /// `partial` when observations exist but `hasCoreSignalCoverage`
    /// is false, `full` otherwise. Extracted from the inline
    /// helper inside `buildSovereignAuditEntry` so unit tests
    /// can pin all 3 branches directly without driving a fixture
    /// turn (production-runtime fixtures always have core
    /// coverage, so the `partial` branch was untested pre-M436.2
    /// per chapter 一百六 strict-audit MEDIUM finding M-1).
    /// Pure function: no side effects, no IO, no randomness.
    static func coverageStatus(
        observations: Int, core: Bool
    ) -> String {
        if observations == 0 { return "empty" }
        return core ? "full" : "partial"
    }

    /// M436.2 (chapter 一百六 deep-review N-1 fix) + M436.3
    /// (chapter 一百七 cross-package alignment) — type-level
    /// constant carrying the per-turn 13-layer expectation set
    /// for reconciliation verdict evaluation. Hoisted from a
    /// per-turn local in `deriveLayerReconciliationReport(...)`
    /// so the array literal isn't reallocated each turn (it has
    /// no per-turn dependency — same 13 cognitive layers every
    /// invocation). L14 sovereign is intentionally omitted —
    /// it's the ledger itself, not a layer that emits coverage
    /// TO the ledger.
    ///
    /// **M436.3 (chapter 一百七)**: promoted from `internal` to
    /// `public` so cross-package callers (specifically
    /// `QinaoSovereign.recordTurnCoverage(...)` callers that
    /// want full-cognitive-coverage expectations rather than
    /// the L14-only default) can reference this single source
    /// of truth. Pre-M436.3 the BAS-direct path used
    /// `[L1..L13]` and the Qinao path defaulted to `[L14]`,
    /// producing two divergent reconciliation contracts that
    /// audit walkers reading both ledgers would see as
    /// contradictory. M436.3 alignment: BAS still uses
    /// `[L1..L13]` (sovereign emits the verdict, not coverage);
    /// Qinao callers can opt in via
    /// `BASEBrainRuntimeCoordinator.layerReconciliationExpectedLayerIDs`
    /// (string-typed view below) when they want the same
    /// 13-layer expectation set without coupling to BASHostKit.
    public static let layerReconciliationExpectedLayers:
        [BASCognitiveLayer] = [
            .leaseLife,         // L1
            .neuralOrgan,       // L2
            .thoughtFold,       // L3
            .worldPrior,        // L4
            .hostConstitution,  // L5
            .presenceEye,       // L6
            .mirrorBlade,       // L7
            .hippocampalWell,   // L8
            .dreamLoop,         // L9 (candidate frontier today)
            .triSelfTribunal,   // L10
            .riskClimate,       // L11
            .gentleHand,        // L12
            .evolutionFurnace,  // L13
        ]

    /// M436.3 (chapter 一百七 cross-package alignment) — string-
    /// typed view of `layerReconciliationExpectedLayers`. Used
    /// by Qinao SDK callers (e.g. hosts streaming all 13
    /// cognitive layers via
    /// `QinaoSovereign.recordTurnCoverage(...,
    /// expectedLayerIDs:)`) so that BAS-direct and Qinao paths
    /// agree on the same expectation set when both opt in.
    /// Sorted to match `BASCognitiveLayer.rawValue` ordering
    /// (L1, L2, ... L13) so audit walkers can rely on stable
    /// finding-emission ordering across both paths.
    public static let layerReconciliationExpectedLayerIDs:
        [String] = layerReconciliationExpectedLayers
            .map { $0.rawValue }

    /// M436.3 (chapter 一百七) — full-cognitive-coverage
    /// expectation set: every cognitive layer (L1..L13) PLUS
    /// L14 sovereign. Use this when reconciliation should
    /// expect the L14 layer as well (which Qinao's
    /// `recordTurnCoverage` does by default since the L14
    /// summary is computed from the audit ledger itself).
    /// Aligns Qinao's `[L14]` default with BAS's `[L1..L13]`
    /// expectation by giving callers a single 14-element list
    /// that covers both contracts.
    public static let fullCoverageExpectedLayerIDs: [String] =
        layerReconciliationExpectedLayerIDs
            + [BASCognitiveLayer.sovereign.rawValue]

    /// M438 (chapter 一百十三 anti-magic-number sweep) — budget
    /// ceiling for the per-turn 14-layer reconciliation
    /// verdict evaluation. `1.0` aligns with Qinao path's
    /// default (`QinaoSovereign.recordTurnCoverage(...,
    /// budgetCeiling: 1.0)`) so both paths agree on the same
    /// threshold. The verdict engine clamps `[0, 1]`
    /// internally; values >= 1.0 collapse to 1.0 in the strict
    /// `>` comparison anyway.
    ///
    /// Pre-M438 this value was hardcoded `1.0` literal in
    /// `deriveLayerReconciliationReport`. M436.1 fixed an
    /// earlier hardcoded `12.0` (which collapsed to 1.0 due
    /// to clamping — wrong AND a no-op). M438 promotes to
    /// named static constant so future changes drop in one
    /// place + align via cross-package reference.
    public static let layerReconciliationBudgetCeiling:
        Double = 1.0
}
