import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

// Context-IR step 4 — runTurn stage methods with DECLARED read surfaces (see
// EBrainRuntimeCoordinator+RunTurnStagesMemoryRisk.swift header for the doctrine).

extension BASEBrainRuntimeCoordinator {

    func renderStageB(
        request: BASEBrainTurnRequest,
        contextPlan: BASTurnContextPlan,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        derivedSessionID: String,
        derivedTurnID: String,
        memoryDeliberate: BASMemoryDeliberateStageContext,
        riskEscalate: BASRiskEscalateStageContext,
        renderVerdict: BASRenderVerdictStageContext
    ) -> BASAuditProjectionStageContext {
        let thoughtArtifacts = memoryDeliberate.thoughtArtifacts
        let abyssalThermalTrioForAudit = riskEscalate.abyssalThermalTrioForAudit
        let cthulhuAssertionDecision = riskEscalate.cthulhuAssertionDecision
        let cthulhuEscalation = riskEscalate.cthulhuEscalation
        let cthulhuPentaForAudit = riskEscalate.cthulhuPentaForAudit
        let escalationSuppressionCodes = riskEscalate.escalationSuppressionCodes
        let kunlunHexaForAudit = riskEscalate.kunlunHexaForAudit
        let kunlunHexaTwoForAudit = riskEscalate.kunlunHexaTwoForAudit
        let kunlunTrioForAudit = riskEscalate.kunlunTrioForAudit
        let kunlunTrioTwoForAudit = riskEscalate.kunlunTrioTwoForAudit
        let boundActionPermit = riskEscalate.boundActionPermit
        let boundRiskCard = riskEscalate.boundRiskCard
        var thoughtFrame = renderVerdict.thoughtFrame
        let abyssalPressureForAudit = renderVerdict.abyssalPressureForAudit
        let humanAnchorSignalForAudit = renderVerdict.humanAnchorSignalForAudit
        let lateClusterBForAudit = renderVerdict.lateClusterBForAudit
        let quarantineRecords = renderVerdict.quarantineRecords
        let runLease = renderVerdict.runLease
        let runtimeTrace = renderVerdict.runtimeTrace
        let sovereignCommitTokens = renderVerdict.sovereignCommitTokens
        let sovereignVerdict = renderVerdict.sovereignVerdict
        let sovereignWarrants = renderVerdict.sovereignWarrants
        let thoughtFold = renderVerdict.thoughtFold
        let updateTickets = renderVerdict.updateTickets
        let wakeIntent = renderVerdict.wakeIntent
        let emergencyBrake = renderVerdict.emergencyBrake
    // M384 escalation now fires upstream (M392 — see the
    // gating block right after `thoughtFrame.actionPermit =
    // boundActionPermit` at line ~380). The audit emission
    // below reads the escalated permit via `boundActionPermit`,
    // and the per-turn audit-projection derives below
    // (`abyssalPressureForAudit` / `humanAnchorSignalForAudit`)
    // produce identical values to the upstream gate-side
    // derives — they exist as separate locals for separation
    // of concerns (gate-side vs audit-side reads).
    // M304 — synthesize seal envelopes from the turn's
    // quarantine records. Each quarantine becomes a
    // sovereign-only seal (the strictest tier short of
    // forbidden) targeting the quarantine source. Aggregate
    // returns nil when there are no quarantines this turn,
    // and the audit-entry builder elides both seal codes.
    // chapter 四百八十八 / M1329 — lifecycle quartet fold
    let lifecycleQuartetForAudit =
        BASTurnAuditProjectionsLifecycleQuartet.compute(
            quarantineRecords: quarantineRecords,
            updateTickets: updateTickets)
    // chapter 五百三十四 / M1513 — dead-code purge:
    // synthesizedSealsForAudit + lifecycleSessionsForAudit
    // shadow re-bindings never read downstream。 Only the
    // aggregates (sealAggregateForAudit +
    // lifecycleAggregateForAudit) are consumed。
    let sealAggregateForAudit = lifecycleQuartetForAudit
        .sealAggregate
    let lifecycleAggregateForAudit = lifecycleQuartetForAudit
        .lifecycleAggregate
    // M316 — derive narrative distortion projection from
    // final risk + permit. Stays at zero on most axes
    // (M316.derive only populates forcedClosure +
    // urgencyMask) so the audit-entry consumer elides the
    // narrative codes unless the turn shows real
    // distortion shape.
    let narrativeDistortionForAudit = lateClusterBForAudit
        .narrativeDistortion
    // M317 — derive anomaly trace from the M316 distortion.
    // Returns nil when no axis crosses the emit threshold;
    // audit-entry consumer elides the codes when nil.
    // chapter 四百八十九 / M1333 — V1 cluster B sextet fold
    let lateClusterCForAudit =
        BASTurnAuditProjectionsLateClusterC.compute(
            sessionID: runtimeTrace.sessionID,
            turnID: derivedTurnID,
            narrativeDistortion:
                narrativeDistortionForAudit,
            abyssalPressure:
                abyssalPressureForAudit,
            humanAnchorSignal:
                humanAnchorSignalForAudit,
            candidates: thoughtFrame.candidates)
    let anomalyTraceForAudit = lateClusterCForAudit
        .anomalyTrace
    let abyssalBranchesForAudit = lateClusterCForAudit
        .abyssalBranches
    let ontologyShiftMarkForAudit = lateClusterCForAudit
        .ontologyShiftMark
    let narrativeDistortionMapForAudit = lateClusterCForAudit
        .narrativeDistortionMap
    // chapter 五百三十四 / M1513 — dead-code purge:
    // hostFragilityForAudit shadow re-binding never read
    // downstream。 abyssalPressureWithFragility remains
    // as it IS consumed below。
    let abyssalPressureWithFragility = lateClusterCForAudit
        .abyssalPressureWithFragility
    // M320 — derive `BASUnknownReserve` projection from L9
    // uncertainty ledger's confidence floor. When the floor
    // is high (≥0.8) the reserve resolves to `.unrestricted`
    // and the audit consumer elides the codes; otherwise
    // emits ceiling tier + ref count.
    // chapter 四百九十一 / M1340 — V1 cluster B trio fold
    let lateClusterDForAudit =
        BASTurnAuditProjectionsLateClusterD.compute(
            sessionID: runtimeTrace.sessionID,
            confidenceFloor:
                thoughtFrame.uncertaintyLedger?
                    .confidenceFloor
                ?? Self
                .defaultConfidenceFloorWhenNoUncertaintyLedger,
            quarantineRecords: quarantineRecords)
    let unknownReserveForAudit = lateClusterDForAudit
        .unknownReserve
    // chapter 五百三十四 / M1513 — dead-code purge:
    // forbiddenCandidatesForAudit shadow re-binding
    // never read downstream。 forbiddenAggregateForAudit
    // remains as it IS consumed below。
    let forbiddenAggregateForAudit = lateClusterDForAudit
        .forbiddenAggregate
    // M402 — Kunlun axis + alignment audit projection.
    // Builds a synthetic axis from the host context + permit
    // mode + risk level, computes alignment for the turn's
    // primary candidate. This is audit-only emission; M406
    // (chapter 九十三) will hook the alignment into L11 permit
    // synthesis. Doctrine: kunlun.axis.* codes are
    // observability-only at this milestone — no decision
    // influence yet (parity with M303 / M304 audit-only
    // pre-M384 phase for Cthulhu).
    // chapter 四百九十三 / M1348-M1349 — Kunlun axis + alignment
    // fold。 4 ForAudit declarations + heavy predicate logic
    // collapsed into a single typed factory call。 M583 (chapter
    // 一百五十七) per-turn-predicate semantics preserved 1:1
    // inside the factory;V1 byte-equality maintained per the
    // stress-sweep dual-mode regression guard。
    let kunlunAxisProtocolForAudit =
        BASTurnAuditProjectionsKunlunAxisProtocol.compute(
            sessionID: runtimeTrace.sessionID,
            hostID: hostContext.hostID,
            permitMode: boundActionPermit.mode,
            riskLevel: boundRiskCard.riskLevel,
            quarantineRecordsIsEmpty:
                quarantineRecords.isEmpty,
            humanAnchorRecommendedSurfaceTone:
                humanAnchorSignalForAudit
                    .recommendedSurfaceTone,
            sovereignEscalationHint:
                abyssalPressureForAudit
                    .sovereignEscalationHint,
            primaryCandidateID:
                thoughtFrame.candidates.first?.candidateID
                ?? "no-candidate",
            kunlunActiveLayerRefs:
                Self.kunlunActiveLayerRefs,
            centerlineRules:
                Self.kunlunCenterlineRules(
                    for: boundActionPermit.mode),
            kunlunAxisDeviationThreshold: Self
                .kunlunAxisDeviationThreshold)
    let kunlunAxisForAudit = kunlunAxisProtocolForAudit.axis
    // chapter 五百三十四 / M1513 — dead-code purge:
    // kunlunMatched shadow re-binding never read
    // downstream。 Deleted。
    let kunlunDeviationCodes = kunlunAxisProtocolForAudit
        .deviationCodes
    let kunlunAxisAlignmentForAudit = kunlunAxisProtocolForAudit
        .alignment
    // M404 — Jade Canon seal verification audit projection.
    // Doctrine §4.2: 无来源不成玉 / 无签名不进门 / 无回放不
    // 升格 / 无撤销路径不得长期生效. Synthesize a per-turn
    // seal for the bound action permit (always class
    // `.actionPermit` since the permit IS the high-integrity
    // object being sealed at L11). Source provenance comes
    // from the verdict + sovereign warrants; signature ref
    // from verdict ID; integrity hash from thoughtFold
    // checksum; revocation path from session-keyed rollback
    // anchor ref. Audit-only emission — actual seal-driven
    // gating is M413+ composability work (chapter 九十五).
    // chapter 四百九十三 / M1350-M1351 — Kunlun seal + river
    // origin fold。 4 ForAudit declarations + 2 inline struct
    // constructions collapsed into a single typed factory call。
    // M404 (jade canon §4.2) + M405 (river origin §4.5)
    // semantics preserved 1:1;V1 byte-equality required。
    let kunlunSealRiverForAudit =
        BASTurnAuditProjectionsKunlunSealRiver.compute(
            sessionID: runtimeTrace.sessionID,
            permitMode: boundActionPermit.mode,
            requireMirror: boundActionPermit
                .requireMirror,
            requireCompare: boundActionPermit
                .requireCompare,
            requireSecondCheck: boundActionPermit
                .requireSecondCheck,
            verdictID: sovereignVerdict.verdictID,
            verdictLevel: sovereignVerdict
                .verdictLevel.rawValue,
            warrantIDs: sovereignWarrants
                .map(\.warrantID),
            candidateIDs: thoughtFrame.candidates
                .map(\.candidateID),
            quarantineIDs: quarantineRecords
                .map(\.quarantineID),
            thoughtFoldID: thoughtFold.foldID,
            thoughtFoldChecksum: thoughtFold.checksum,
            riverOriginTransformationSteps:
                Self.riverOriginTransformationSteps)
    let kunlunJadeSealForAudit = kunlunSealRiverForAudit.seal
    let kunlunJadeVerificationForAudit =
        kunlunSealRiverForAudit.verification
    let kunlunRiverTraceForAudit =
        kunlunSealRiverForAudit.trace
    let kunlunRiverLineageForAudit =
        kunlunSealRiverForAudit.lineage
    // M408 — Yaochi Sanctum access audit projection. Doctrine
    // §4.4 (line 556-560): 可以存在但默认不参与普通检索 / 可以
    // 被保护但不能被系统操控 / 可以被召回但必须有上下文授权与
    // 承接表面. Synthesize a per-turn sample sanctum entry
    // representing the highest-sensitivity memory class touched
    // by this turn (when quarantine records exist, treat them
    // as `.sensitive` proxy; otherwise mint a `.boundary` proxy
    // representing the host's general protective posture).
    // Run `BASKunlunYaochiProtocol.evaluateAccess` against
    // current request context (host anchor present iff
    // humanAnchorSignal is .reserved tone signaling distance;
    // otherwise present); audit-only emission — actual L8
    // hippocampal gating is M413+ work (chapter 九十五).
    // M425 (chapter 一百一) — extracted to
    // `deriveYaochiAuditProjection`; see file top.
    let yaochiProjection =
        Self.deriveYaochiAuditProjection(
            sessionID: runtimeTrace.sessionID,
            candidateID: thoughtFrame.candidates.first?
                .candidateID ?? "no-memory",
            hostID: hostContext.hostID,
            hasQuarantines:
                !quarantineRecords.isEmpty,
            humanAnchorTone:
                humanAnchorSignalForAudit
                    .recommendedSurfaceTone,
            permitMode: boundActionPermit.mode)
    let kunlunYaochiSanctumForAudit =
        yaochiProjection.entry
    let kunlunYaochiAccessForAudit =
        yaochiProjection.access
    // M409 — Heaven Gate Permit readiness audit projection.
    // Doctrine §4.3: 不是有路径就能进现实 / 不是有候选就能进
    // 宿主层 / 不是有经验就能进成长层 / 不是有工具意图就能工具
    // 写. Synthesize a per-turn permit representing the
    // highest gate class implied by the turn's bound permit
    // mode (`.tool` for tool-emitting permits, `.public` for
    // answer/mirror, `.cognitive` otherwise). Required seals:
    // synthesize one per warrant. Sovereign warrant ref
    // sourced from the first sovereign warrant when present.
    // Pass state derived from verdict level (passed when
    // verdict is `.advisory`/`.unrestricted`, otherwise
    // pending/remanded). Audit-only emission — actual gate
    // enforcement is M410 follow-up.
    // M425 (chapter 一百一) — extracted to
    // `deriveHeavenGateAuditProjection`; see file top.
    let heavenGateProjection =
        Self.deriveHeavenGateAuditProjection(
            sessionID: runtimeTrace.sessionID,
            candidateID: thoughtFrame.candidates.first?
                .candidateID ?? "no-candidate",
            permitMode: boundActionPermit.mode,
            warrantIDs: sovereignWarrants
                .map(\.warrantID),
            verdictLevel: sovereignVerdict.verdictLevel,
            requireSecondCheck:
                boundActionPermit.requireSecondCheck)
    let kunlunHeavenGateForAudit =
        heavenGateProjection.permit
    let kunlunHeavenGateReadinessForAudit =
        heavenGateProjection.readiness
    // M424 (chapter 一百一) — wire chapter 九十九 typed schemas
    // into runtime so they're not just "typed-surface-only".
    // Each schema is derived from existing audit-projection
    // state (zero new substrate dependencies) and emits a
    // status code into signalRefs so audit walkers can verify
    // the schema fired on each turn.
    //
    // Three schemas wired here:
    //
    // 1. BASKunlunAxisView (§5.4) — derived from existing
    //    kunlunAxisForAudit + deviation codes; emits
    //    `kunlun.axis.view:wellformed|partial`.
    // 2. BASKunlunTianmenWarrant (§5.14) — derived from
    //    existing kunlunHeavenGateForAudit + verdict ref +
    //    seal ref; emits `kunlun.warrant.authorized:true|false`.
    // 3. BASKunlunGateDenialWrit (§5.14) — derived from
    //    readiness when not ready; emits `kunlun.denial.well-
    //    formed:true` when present (denial is doctrine-
    //    correct per 该断时断 — denials must always carry
    //    typed reason codes + return path + denied domain).
    //
    // Two schemas (BASKunlunAscentView, BASKunlunFarWestReserve)
    // are intentionally NOT wired here — they need synthetic
    // ascent/distance data that the substrate doesn't yet
    // expose. Wiring them without real data would emit
    // misleading audit codes. Deferred with criteria: wire
    // when a per-turn ascent context or unknown-distance
    // projection is added upstream.
    // chapter 四百九十四 / M1353-M1354 — Tianmen trio fold。
    // 3 ForAudit declarations + ~56 LOC of inline construction
    // logic (axisView + tianmenWarrant + gateDenialWrit
    // mutual-exclusion guards) collapsed into a single typed
    // factory call。 M424 chapter 一百一 mutual-exclusivity
    // invariant preserved (该断时断 — denials carry typed
    // reason codes)。 V1 byte-equality required。
    let kunlunTianmenTrioForAudit =
        BASTurnAuditProjectionsKunlunTianmenTrio.compute(
            sessionID: runtimeTrace.sessionID,
            permitMode: boundActionPermit.mode,
            primaryCandidateID:
                thoughtFrame.candidates.first?
                    .candidateID ?? "no-candidate",
            worldAnchorRef:
                kunlunAxisForAudit.worldAnchorRef,
            centerlineRules:
                kunlunAxisForAudit.centerlineRules,
            deviationCodes: kunlunDeviationCodes,
            heavenGateID:
                kunlunHeavenGateForAudit.gateID,
            heavenGateIsReady:
                kunlunHeavenGateReadinessForAudit
                    .isReady,
            heavenGateReasonCodes:
                kunlunHeavenGateReadinessForAudit
                    .reasonCodes,
            firstSovereignWarrantID: sovereignWarrants
                .first?.warrantID,
            jadeCanonSealRef:
                kunlunJadeSealForAudit.sealID,
            riverOriginRef:
                kunlunRiverTraceForAudit.traceID)
    let kunlunAxisViewForAudit = kunlunTianmenTrioForAudit
        .axisView
    let kunlunTianmenWarrantForAudit =
        kunlunTianmenTrioForAudit.tianmenWarrant
    let kunlunGateDenialWritForAudit =
        kunlunTianmenTrioForAudit.gateDenialWrit
    // M436 (chapter 一百四) — derive the per-turn 14-layer
    // reconciliation report + verdict from all 13 cognitive
    // bundles in scope (L1..L13). Pre-fix this engine
    // existed as a library but was never invoked from
    // production; the audit ledger therefore had ZERO
    // visibility into "did all expected layers participate
    // this turn." Now the verdict's findings (missing layer
    // / partial coverage / budget overspend) emit
    // `reconciliation.*` codes into `signalRefs` below, and
    // the report's `summaries` give audit walkers the full
    // observed-layer list. Doctrine pin: pure derive, no
    // verdict escalation, no permit mutation, no decision
    // influence — purely additive metadata.
    let layerReconciliation = Self
        .deriveLayerReconciliationReport(
            thoughtFrame: thoughtFrame,
            presenceBundle:
                contextFrame.presenceObservationBundle,
            decompositionBundle:
                decomposeFrame.decompositionObservationBundle,
            candidateBundle: thoughtArtifacts
                .candidateObservationBundle,
            // Canonical key formula matching the rest of
            // the substrate: derivedTurnID + derivedSessionID
            // are what the M53 / M54 / M55 / M62 / M63 /
            // M64 derive helpers feed into every per-layer
            // bundle. Using the same pair here lets
            // `BASObservationReconciliationReport.appending`
            // accept every bundle's summary instead of
            // dropping ones whose keys don't match.
            turnID: derivedTurnID,
            sessionID: derivedSessionID,
            emittedAt: runtimeTrace.recordedAt)
    // M502-M510 (chapter 一百二十八) — L12 doctrine surface
    // aliases. Pure translation tables from final permit
    // mode → BASSurfaceMode → doctrine-specific aliases.
    // nil when permit mode has no L12 surface (e.g. .answer
    // / .escalate proceed without surface rendering).
    // chapter 四百九十二 / M1345 — surface trio fold
    let surfaceTrioForAudit =
        BASTurnAuditProjectionsSurfaceTrio.compute(
            permitMode: boundActionPermit.mode)
    // chapter 五百三十四 / M1513 — dead-code purge:
    // surfaceModeForAudit shadow re-binding never
    // read downstream。 Deleted。
    let cthulhuSurfaceAliasForAudit = surfaceTrioForAudit
        .cthulhuSurfaceAlias
    let kunlunSurfaceAliasForAudit = surfaceTrioForAudit
        .kunlunSurfaceAlias
    // M436.4 (chapter 一百七 parameter-bundle refactor) —
    // populate the typed audit-observation bundle once and
    // pass to the bundle-form `buildSovereignAuditEntry`.
    // Pre-M436.4 the call site spelled 24+ named parameters
    // chapter 五百十五 / M1437 — V1 monolith projections
    // construction FOLD using the unified 3-block init
    // (M1435)。
    // chapter 五百十六 / M1443 — extended to 4-block
    // init (M1442),packaging 9 more Kunlun protocol
    // fields into the new kunlunProtocolBlock。
    // chapter 五百十七 / M1447 — extended to 5-block
    // init (M1446),packaging 7 more L1-L7 Cthulhu
    // aggregate fields into the new
    // cthulhuAggregatesBlock。
    //
    // Byte-equality with the pre-fold path GUARANTEED
    // by M1435 + M1442 + M1446 PROOF tests + stress-
    // sweep canonical60 × 3 repeat runs 0-divergence。
    //
    // The 4 Kunlun trios + Cthulhu trio + Penta + 11
    // cognitive bundles + 9 Kunlun protocol fields + 7
    // Cthulhu aggregate fields now flow into 5 typed
    // input surfaces (53 of 56 projection fields,
    // ~95% packaging coverage)。
    let kunlunInputsForAudit =
        BASAuditObservationProjectionsKunlunInputs(
            trio: kunlunTrioForAudit,
            hexa: kunlunHexaForAudit,
            trioTwo: kunlunTrioTwoForAudit,
            hexaTwo: kunlunHexaTwoForAudit)
    let cthulhuInputsForAudit =
        BASAuditObservationProjectionsCthulhuInputs(
            abyssalThermalTrio:
                abyssalThermalTrioForAudit,
            cthulhuPenta: cthulhuPentaForAudit)
    let observationBundlesForAudit =
        BASAuditObservationProjectionsObservationBundlesBlock(
            presence:
                contextFrame.presenceObservationBundle,
            decomposition: decomposeFrame
                .decompositionObservationBundle,
            softHand: thoughtFrame
                .softHandObservationBundle,
            leaseLife: thoughtFrame
                .leaseLifeObservationBundle,
            hostConstitution: thoughtFrame
                .hostConstitutionObservationBundle,
            thoughtFold: thoughtFrame
                .thoughtFoldObservationBundle,
            neuralOrgan: thoughtFrame
                .neuralOrganObservationBundle,
            hippocampalMemory: thoughtFrame
                .hippocampalMemoryObservationBundle,
            worldPrior: thoughtFrame
                .worldPriorObservationBundle,
            risk: thoughtFrame
                .riskObservationBundle,
            updateTicket: thoughtFrame
                .updateTicketObservationBundle)
    let kunlunProtocolBlockForAudit =
        BASAuditObservationProjectionsKunlunProtocolBlock(
            kunlunAxisAlignment:
                kunlunAxisAlignmentForAudit,
            jadeCanonVerification:
                kunlunJadeVerificationForAudit,
            jadeCanonObjectClass: .actionPermit,
            riverOriginLineage:
                kunlunRiverLineageForAudit,
            yaochiAccess:
                kunlunYaochiAccessForAudit,
            yaochiSanctumClass:
                kunlunYaochiSanctumForAudit
                    .sanctumClass,
            tianmenReadiness:
                kunlunHeavenGateReadinessForAudit,
            tianmenGateClass:
                kunlunHeavenGateForAudit.gateClass,
            tianmenPassState:
                kunlunHeavenGateForAudit.passState)
    let cthulhuAggregatesBlockForAudit =
        BASAuditObservationProjectionsCthulhuAggregatesBlock(
            abyssalPressure:
                abyssalPressureWithFragility,
            humanAnchorSignal:
                humanAnchorSignalForAudit,
            sealAggregate: sealAggregateForAudit,
            lifecycleAggregate:
                lifecycleAggregateForAudit,
            narrativeDistortion:
                narrativeDistortionForAudit,
            anomalyTrace: anomalyTraceForAudit,
            abyssalBranches:
                abyssalBranchesForAudit)
    // chapter 五百十八 / M1451 — 6th block extension
    let closureBlockForAudit =
        BASAuditObservationProjectionsClosureBlock(
            candidateObservationBundle:
                thoughtArtifacts
                    .candidateObservationBundle,
            tribunalObservationBundle:
                thoughtFrame
                    .tribunalObservationBundle,
            unknownReserve: unknownReserveForAudit,
            forbiddenAggregate:
                forbiddenAggregateForAudit,
            layerReconciliationVerdict:
                layerReconciliation.verdict,
            layerReconciliationReport:
                layerReconciliation.report,
            escalationSuppressionCodes:
                escalationSuppressionCodes)
    // chapter 五百二十一 / M1463 — 7th block extension
    let kunlunAuditSchemasBlockForAudit =
        BASAuditObservationProjectionsKunlunAuditSchemasBlock(
            kunlunAxisView: kunlunAxisViewForAudit,
            kunlunTianmenWarrant:
                kunlunTianmenWarrantForAudit,
            kunlunGateDenialWrit:
                kunlunGateDenialWritForAudit)
    // chapter 五百二十二 / M1467 — 8th + FINAL block
    // extension。 100% V1 call-site packaging coverage
    // milestone:every audit-projection field now
    // flows through a typed input surface。
    let cthulhuLeftoversBlockForAudit =
        BASAuditObservationProjectionsCthulhuLeftoversBlock(
            ontologyShiftMark:
                ontologyShiftMarkForAudit,
            narrativeDistortionMap:
                narrativeDistortionMapForAudit,
            cthulhuAssertionCeilingReasonCodes:
                cthulhuAssertionDecision
                    .reasonCodes,
            cthulhuPermitEscalationReasonCodes:
                cthulhuEscalation.reasonCodes,
            cthulhuSurfaceAlias:
                cthulhuSurfaceAliasForAudit,
            kunlunSurfaceAlias:
                kunlunSurfaceAliasForAudit)
    let projections = BASAuditObservationProjections(
        kunlunInputs: kunlunInputsForAudit,
        cthulhuInputs: cthulhuInputsForAudit,
        observationBundles:
            observationBundlesForAudit,
        kunlunProtocolBlock:
            kunlunProtocolBlockForAudit,
        cthulhuAggregatesBlock:
            cthulhuAggregatesBlockForAudit,
        closureBlock: closureBlockForAudit,
        kunlunAuditSchemasBlock:
            kunlunAuditSchemasBlockForAudit,
        cthulhuLeftoversBlock:
            cthulhuLeftoversBlockForAudit)
    // chapter 五百十九 / M1454 — FIRST PRODUCTION
    // WIRE-IN of the M1426 projection-block emission
    // pattern。 When the host wired
    // `projectionBlockEmissionHandler` at coordinator
    // construction time,we fire it now with the
    // typed observation record。 Default nil = handler
    // not set = behavior identical to pre-M1454。
    //
    // V1 byte-equality preserved:the handler runs
    // AFTER projections construction,does not mutate
    // any audit state,and its return value is
    // discarded。 Stress-sweep regression guard
    // catches drift。
    if let handler = projectionBlockEmissionHandler {
        let observation =
            BASAuditObservationProjectionsBundleEmitter
                .makeObservation(
                    turnID: derivedTurnID,
                    sessionID: derivedSessionID,
                    emittedAt: Date(),
                    kunlunInputs:
                        kunlunInputsForAudit,
                    cthulhuInputs:
                        cthulhuInputsForAudit)
        handler(observation)
    }
    let sovereignAuditEntry = buildSovereignAuditEntry(
        sovereignVerdict: sovereignVerdict,
        sovereignCommitTokens: sovereignCommitTokens,
        sovereignWarrants: sovereignWarrants,
        quarantineRecords: quarantineRecords,
        runtimeTrace: runtimeTrace,
        thoughtFold: thoughtFold,
        riskCard: boundRiskCard,
        actionPermit: boundActionPermit,
        projections: projections)
    let finalSovereignVerdict: BASSovereignVerdict? = {
        var verdict = sovereignVerdict
        verdict.auditRef = sovereignAuditEntry.auditID
        return verdict
    }()
    let vitalState = buildVitalState(
        deviceState: request.deviceState,
        budgetFrame: contextPlan.routedBudget,
        runtimeTrace: runtimeTrace,
        emergencyBrake: emergencyBrake
    )
    let sovereignActuationCommands = buildSovereignActuationCommands(
        sovereignVerdict: finalSovereignVerdict,
        runtimeTrace: runtimeTrace,
        budgetFrame: contextPlan.routedBudget,
        riskCard: boundRiskCard,
        actionPermit: boundActionPermit
    )
    let sovereignExecutionReceipts = Self.buildSovereignExecutionReceipts(
        sovereignActuationCommands: sovereignActuationCommands,
        runtimeTrace: runtimeTrace
    )
    let finalizedRuntimeTrace = appendingSovereignTraceEvent(
        to: runtimeTrace,
        commands: sovereignActuationCommands,
        receipts: sovereignExecutionReceipts,
        thoughtFrame: thoughtFrame
    )
    let recoveryDisposition = buildRecoveryDisposition(
        budgetFrame: contextPlan.routedBudget,
        emergencyBrake: emergencyBrake,
        sovereignVerdict: finalSovereignVerdict
    )
    let finalizedBudgetFrame = buildFinalizedBudgetFrame(
        contextPlan.routedBudget,
        wakeIntent: wakeIntent,
        runLease: runLease,
        actionPermit: boundActionPermit
    )

    if let runLease {
        thoughtFrame.organMap?.leaseRef = runLease.leaseID
        thoughtFrame.neuralLeaseReceipt?.leaseID = runLease.leaseID
    }

        return BASAuditProjectionStageContext(
            thoughtFrame: thoughtFrame,
            finalSovereignVerdict: finalSovereignVerdict,
            finalizedBudgetFrame: finalizedBudgetFrame,
            finalizedRuntimeTrace: finalizedRuntimeTrace,
            kunlunHeavenGateForAudit: kunlunHeavenGateForAudit,
            kunlunRiverTraceForAudit: kunlunRiverTraceForAudit,
            kunlunYaochiSanctumForAudit: kunlunYaochiSanctumForAudit,
            projections: projections,
            recoveryDisposition: recoveryDisposition,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            vitalState: vitalState)
    }

    // stage-frame isolation: the 9-bundle assembly temporaries die with this frame
    func assembleStage(
        request: BASEBrainTurnRequest,
        contextFrame: BASContextFrame,
        decomposeFrame: BASDecomposeFrame,
        hostContext: BASHostProfile,
        memoryDeliberate: BASMemoryDeliberateStageContext,
        riskBind: BASRiskBindStageContext,
        riskEscalate: BASRiskEscalateStageContext,
        renderVerdict: BASRenderVerdictStageContext,
        auditProjection: BASAuditProjectionStageContext
    ) -> BASEBrainTurnResult {
        let memoryBundle = memoryDeliberate.memoryBundle
        let mergedChoice = memoryDeliberate.mergedChoice
        let triScores = memoryDeliberate.triScores
        let normalizedRiskDecisionPackage = riskBind.normalizedRiskDecisionPackage
        let boundActionPermit = riskEscalate.boundActionPermit
        let boundRiskCard = riskEscalate.boundRiskCard
        let hostGateValue = riskEscalate.hostGateValue
        let thoughtFrame = auditProjection.thoughtFrame   // post-renderB (lease refs attached)
        let emergencyBrake = renderVerdict.emergencyBrake
        let evolutionGovernance = renderVerdict.evolutionGovernance
        let quarantineRecords = renderVerdict.quarantineRecords
        let renderedOutput = renderVerdict.renderedOutput
        let runLease = renderVerdict.runLease
        let sovereignCommitTokens = renderVerdict.sovereignCommitTokens
        let sovereignLock = renderVerdict.sovereignLock
        let sovereignWarrants = renderVerdict.sovereignWarrants
        let thoughtFold = renderVerdict.thoughtFold
        let updateTickets = renderVerdict.updateTickets
        let wakeIntent = renderVerdict.wakeIntent
        let finalSovereignVerdict = auditProjection.finalSovereignVerdict
        let finalizedBudgetFrame = auditProjection.finalizedBudgetFrame
        let finalizedRuntimeTrace = auditProjection.finalizedRuntimeTrace
        let kunlunHeavenGateForAudit = auditProjection.kunlunHeavenGateForAudit
        let kunlunRiverTraceForAudit = auditProjection.kunlunRiverTraceForAudit
        let kunlunYaochiSanctumForAudit = auditProjection.kunlunYaochiSanctumForAudit
        let projections = auditProjection.projections
        let recoveryDisposition = auditProjection.recoveryDisposition
        let sovereignActuationCommands = auditProjection.sovereignActuationCommands
        let sovereignAuditEntry = auditProjection.sovereignAuditEntry
        let sovereignExecutionReceipts = auditProjection.sovereignExecutionReceipts
        let vitalState = auditProjection.vitalState
        let turnResult = BASEBrainTurnResult(
            // chapter 五百三十一 / M1503 — V1 splice:
            // 6 device/lifecycle args collapse to 1 typed
            // deviceLifecycleBundle (deviceState +
            // budgetFrame + wakeIntent + vitalState +
            // runLease + emergencyBrake)。 Byte-equality
            // preserved by M1502 PROOF (bundle accessors
            // pass through verbatim)。
            deviceLifecycleBundle:
                BASEBrainTurnResultDeviceLifecycleBundle(
                    deviceState: request.deviceState,
                    budgetFrame: finalizedBudgetFrame,
                    wakeIntent: wakeIntent,
                    vitalState: vitalState,
                    runLease: runLease,
                    emergencyBrake: emergencyBrake),
            // chapter 五百二十五 / M1479 — V1 splice:
            // 8 sovereign-cluster args collapse to 1
            // typed sovereignBundle。 Byte-equality
            // preserved by M1478 PROOF (bundle accessors
            // pass through verbatim)。
            sovereignBundle:
                BASEBrainTurnResultSovereignBundle(
                    sovereignVerdict:
                        finalSovereignVerdict,
                    sovereignCommitTokens:
                        sovereignCommitTokens,
                    sovereignWarrants:
                        sovereignWarrants,
                    sovereignLock: sovereignLock,
                    quarantineRecords:
                        quarantineRecords,
                    sovereignAuditEntry:
                        sovereignAuditEntry,
                    sovereignActuationCommands:
                        sovereignActuationCommands,
                    sovereignExecutionReceipts:
                        sovereignExecutionReceipts),
            // chapter 五百三十二 / M1507 — V1 splice:
            // 3 forensic metadata args collapse to 1
            // typed forensicMetadataBundle (policyLineage
            // + recoveryDisposition + runtimeTrace)。
            // Byte-equality preserved by M1506 PROOF
            // (bundle accessors pass through verbatim)。
            // 100% arg packaging coverage achieved at
            // this V1 call site。
            forensicMetadataBundle:
                BASEBrainTurnResultForensicMetadataBundle(
                    policyLineage: policyLineage,
                    recoveryDisposition:
                        recoveryDisposition,
                    runtimeTrace:
                        finalizedRuntimeTrace),
            // chapter 五百二十六 / M1483 — V1 splice:
            // 5 host-cluster args collapse to 1 typed
            // hostBundle。 Byte-equality preserved by
            // M1482 PROOF (bundle accessors pass through
            // verbatim)。
            hostBundle:
                BASEBrainTurnResultHostBundle(
                    hostConstitution: hostConstitution,
                    hostConstitutionVault:
                        hostConstitutionVault,
                    hostVersionTree: hostVersionTree,
                    hostForgetRequest:
                        hostForgetRequest,
                    hostContext: hostContext),
            // chapter 五百二十八 / M1491 — V1 splice:
            // 5 cognitive-frame args collapse to 1 typed
            // cognitiveFramesBundle。 Byte-equality
            // preserved by M1490 PROOF。
            cognitiveFramesBundle:
                BASEBrainTurnResultCognitiveFramesBundle(
                    contextFrame: contextFrame,
                    decomposeFrame: decomposeFrame,
                    memoryBundle: memoryBundle,
                    thoughtFrame: thoughtFrame,
                    thoughtFold: thoughtFold),
            // chapter 五百二十九 / M1495 — V1 splice:
            // 4 risk/choice args collapse to 1 typed
            // riskChoiceBundle。 Byte-equality preserved
            // by M1494 PROOF。
            riskChoiceBundle:
                BASEBrainTurnResultRiskChoiceBundle(
                    triScores: triScores,
                    mergedChoice: mergedChoice,
                    riskCard: boundRiskCard,
                    actionPermit: boundActionPermit),
            // chapter 五百三十 / M1499 — V1 splice:
            // 4 misc args collapse to 1 typed miscBundle。
            // Byte-equality preserved by M1498 PROOF。
            miscBundle:
                BASEBrainTurnResultMiscBundle(
                    riskDecisionPackage:
                        normalizedRiskDecisionPackage,
                    hostGateValue: hostGateValue,
                    renderedOutput: renderedOutput,
                    updateTickets: updateTickets),
            // chapter 五百二十四 / M1475 — V1 splice:
            // 10 evolution-cluster args collapse to 1
            // typed evolutionBundle。 Byte-equality
            // preserved by M1474 PROOF (bundle accessors
            // pass through verbatim)。
            evolutionBundle:
                BASEBrainTurnResultEvolutionBundle(
                    experienceCandidates:
                        evolutionGovernance
                            .experienceCandidates,
                    workflowCandidates:
                        evolutionGovernance
                            .workflowCandidates,
                    guardTemplateCandidates:
                        evolutionGovernance
                            .guardTemplateCandidates,
                    biasRecords:
                        evolutionGovernance
                            .biasRecords,
                    riskPatternCandidates:
                        evolutionGovernance
                            .riskPatternCandidates,
                    learningExportBundles:
                        evolutionGovernance
                            .learningExportBundles,
                    shadowTrialRecords:
                        evolutionGovernance
                            .shadowTrialRecords,
                    versionDeltas:
                        evolutionGovernance
                            .versionDeltas,
                    retractionOrders:
                        evolutionGovernance
                            .retractionOrders,
                    evolutionSeals:
                        evolutionGovernance
                            .evolutionSeals),
            // chapter 五百二十六 / M1483 — V1 splice:
            // 7 audit-projection-forwarded args collapse
            // to 1 typed auditProjectionForwardBundle。
            // Bundle accessors pass through verbatim:
            //   - M578 (chapter 一百五十三) 4 fields
            //     from projections (kunlunAxisAlignment +
            //     humanAnchorSignal + abyssalPressure +
            //     unknownReserve)
            //   - M581 (chapter 一百五十六) 3 fields from
            //     runTurn-scope locals (heavenGate +
            //     riverTrace + yaochiSanctum)
            // Byte-equality preserved via 3-bundle init
            // delegation (M1482)。
            auditProjectionForwardBundle:
                BASEBrainTurnResultAuditProjectionForwardBundle(
                    kunlunAxisAlignment:
                        projections.kunlunAxisAlignment,
                    humanAnchorSignal:
                        projections.humanAnchorSignal,
                    abyssalPressure:
                        projections.abyssalPressure,
                    unknownReserve:
                        projections.unknownReserve,
                    kunlunHeavenGatePermit:
                        kunlunHeavenGateForAudit,
                    kunlunRiverOriginTrace:
                        kunlunRiverTraceForAudit,
                    yaochiSanctumEntry:
                        kunlunYaochiSanctumForAudit)
        )
        return turnResult
    }
}
