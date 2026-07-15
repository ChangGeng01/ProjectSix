// MARK: - BASAgentFabricAdapters
// chapter 九百六十 / M3505 — Phase 2 ch1:DTO adapters
//
// Pure-function adapters that convert existing per-turn types
// (BASDecomposeFrame from L7,BASCandidatePath from L9) into the
// slim DTOs the Agent Fabric seats consume。 Lives in
// BASOrchestration because that module already imports BASMemory
// (the reverse direction is a dep cycle per ch 957)。
//
// Per the ch 957 design comment:"Coordinator adapter (ch 958+)
// builds these DTOs from the live L7 / L9 outputs in one line"
// — this file delivers that one-line。
//
// Pure functions:no I/O,no actor isolation,trivially testable。

import Foundation
import BASMemory
import BASPolicy

public enum BASAgentFabricAdapters {

    /// Build a `BASScoutInput` from the L7 decompose frame。 Maps
    /// each signal cluster the Scout seat reads:pressure /
    /// manipulation / boundary / contradiction。
    public static func scoutInput(
        from frame: BASDecomposeFrame
    ) -> BASScoutInput {
        BASScoutInput(
            pressureSignals: frame.pressureSignals,
            pressureVectorCount: frame.pressureVectors.count,
            manipulationSignals: frame.manipulationSignals,
            manipulationPatternCount:
                frame.manipulationPatterns.count,
            boundaryTouchCount: frame.boundaryTouches.count,
            contradictionRecordCount:
                frame.contradictionRecords.count,
            bareContradictions: frame.contradictions)
    }

    /// Build `[BASPlannerCandidate]` from the L9 loopService
    /// output。 One DTO per candidate path,carrying only the
    /// fields the Planner seat needs。 No mutation of the
    /// original paths。
    public static func plannerCandidates(
        from paths: [BASCandidatePath]
    ) -> [BASPlannerCandidate] {
        paths.map { p in
            BASPlannerCandidate(
                candidateID: p.candidateID,
                title: p.title,
                actionSummary: p.actionSummary,
                confidence: p.confidence,
                expectedBenefit: p.expectedBenefit,
                expectedCost: p.expectedCost,
                reversibility: p.reversibility)
        }
    }

    /// Build a `BASRiskInput` from the L7 frame + candidate paths。
    /// The pressureLevel signal is derived from Scout's pressure-
    /// signal count (≥ 5 signals = high pressure 1.0;linear scale
    /// below)。 manipulation/boundary flags mirror Scout's cluster
    /// detection。
    public static func riskInput(
        from frame: BASDecomposeFrame,
        candidates: [BASCandidatePath]
    ) -> BASRiskInput {
        let scoutPressureCount =
            frame.pressureSignals.count +
            frame.pressureVectors.count
        // Linear pressure level:0 signals → 0.0,5+ signals → 1.0
        let pressureLevel = min(
            1.0, Double(scoutPressureCount) / 5.0)
        let manipulation =
            !frame.manipulationSignals.isEmpty ||
            !frame.manipulationPatterns.isEmpty
        let boundary = !frame.boundaryTouches.isEmpty
        let riskCandidates: [BASRiskCandidate] = candidates.map { p in
            BASRiskCandidate(
                candidateID: p.candidateID,
                reversibility: p.reversibility,
                expectedBenefit: p.expectedBenefit,
                expectedCost: p.expectedCost)
        }
        return BASRiskInput(
            candidates: riskCandidates,
            pressureLevel: pressureLevel,
            manipulationDetected: manipulation,
            boundaryTouched: boundary)
    }

    /// Build a `BASSurfaceInput` for observation-only mode (ch 960)。
    /// Defaults are SAFE — permit granted,no veto,low risk —
    /// because in observation mode the surface delta doesn't
    /// drive any UI;it's recorded for trace replay only。
    /// Future fabric-authoritative mode (ch 961+) will derive
    /// these from the live risk gate + sovereign sentinel state。
    public static func surfaceInputObservationMode(
        acceptedCandidateID: String?,
        riskBand: BASRiskAssessmentBand = .low
    ) -> BASSurfaceInput {
        BASSurfaceInput(
            acceptedCandidateID: acceptedCandidateID,
            actionPermitGranted: true,
            riskBand: riskBand,
            reversibility: 1.0,
            sovereignVetoed: false,
            userRequestsCompare: false)
    }

    /// Build a complete `BASAgentTurnInput` from L7/L9 outputs +
    /// turn metadata。 Convenience over the per-seat adapters。
    /// `acceptedCandidateID` is typically the L9 winner's id (or
    /// nil for turns with no candidate)。
    ///
    /// chapter 九百六十四.5 USER-PASS-5 D2 fix:added optional
    /// `memory`,`critic`,`hostAlignment`,`sovereignSentinel`
    /// parameters。 Previously the coordinator's
    /// `runAgentFabricObservation` could only wire 4 seats —
    /// Memory/Critic/HostAlign/Sovereign were unreachable through
    /// the coordinator even when their roster slots were set。
    /// Now coordinators can pass pre-built DTOs from their L8/
    /// triSelf/host-constitution/sovereign-state adapters。
    /// Defaulted nil preserves prior 4-seat caller compat。
    ///
    /// chapter 九百八十五 / M3630 — Cross-Module Integration Arc ch3:
    /// added optional `evolutionShadow` parameter,closing
    /// ch 982.5 META-REVIEW Gap 8。 Before this chapter the
    /// 9th seat (ch 965 EvolutionShadow) was unreachable
    /// through coordinator adapter even when its roster slot
    /// was set。 Defaulted nil preserves all prior callers
    /// byte-equal。
    public static func turnInput(
        turnID: String,
        decomposeFrame: BASDecomposeFrame,
        candidatePaths: [BASCandidatePath],
        acceptedCandidateID: String?,
        memory: BASMemorySeatInput? = nil,
        critic: BASCriticSeatInput? = nil,
        hostAlignment: BASHostAlignmentInput? = nil,
        sovereignSentinel:
            BASSovereignSentinelInput? = nil,
        evolutionShadow:
            BASEvolutionShadowInput? = nil,
        riskOverride: BASRiskInput? = nil,
        priorityContext: BASMergePriorityContext =
            BASMergePriorityContext(),
        nowNanos: Int64 = 0
    ) -> BASAgentTurnInput {
        // chapter 九百九十四.5 META-REVIEW Round-10 HIGH-1 fix:
        // accept optional `riskOverride` so callers (e.g.
        // BASAgentFabricFullTurnAdapter) can supply a
        // BASRiskCard-enriched BASRiskInput per ch 987 monotonic
        // raise。 Pre-fix the L7-only default path always ran,
        // bypassing ch 987 enrichment when called through the
        // host-integration convenience adapter。 Default nil
        // preserves byte-equality for existing callers。
        let resolvedRisk =
            riskOverride ?? riskInput(
                from: decomposeFrame,
                candidates: candidatePaths)
        return BASAgentTurnInput(
            turnID: turnID,
            scout: scoutInput(from: decomposeFrame),
            plannerCandidates: plannerCandidates(
                from: candidatePaths),
            risk: resolvedRisk,
            surface: surfaceInputObservationMode(
                acceptedCandidateID: acceptedCandidateID),
            memory: memory,
            critic: critic,
            hostAlignment: hostAlignment,
            sovereignSentinel: sovereignSentinel,
            evolutionShadow: evolutionShadow,
            priorityContext: priorityContext,
            nowNanos: nowNanos)
    }

    /// Build a `BASCriticSeatInput` from candidate paths + a
    /// caller-supplied superego activity level。 Maps 1:1 from
    /// `BASCandidatePath` benefit/cost/reversibility to
    /// `BASCriticCandidate` fields。
    public static func criticInput(
        from paths: [BASCandidatePath],
        superegoActiveLevel: Double = 0.5
    ) -> BASCriticSeatInput {
        BASCriticSeatInput(
            candidates: paths.map { p in
                BASCriticCandidate(
                    candidateID: p.candidateID,
                    title: p.title,
                    expectedBenefit: p.expectedBenefit,
                    expectedCost: p.expectedCost,
                    reversibility: p.reversibility)
            },
            superegoActiveLevel: superegoActiveLevel)
    }

    // MARK: - chapter 九百九十 / M3655 — Cross-Module Integration
    //                                     Arc ch8 (final adapter
    //                                     — ch 991 ships E2E test,
    //                                     ch 991.5 ships CRITICAL
    //                                     fix to Rule 4 deny-scope
    //                                     string set):Gap 2 close
    //
    // Validate MCP invocation against a live `BASActionPermit`。
    // Was:`BASMCPCapabilityGateway` (BASMemory) checked
    // `permitID.isEmpty` and `allowedToolDomains.contains(...)`
    // but the `permitID` was just a STRING — never validated
    // against an actual `BASActionPermit` from `BASPolicy`。 The
    // gateway claimed defense-in-depth but had no path to the
    // live host's risk gate output。 Per ch 982.5 META-REVIEW
    // Gap 2,this meant tools could be invoked with `permitID:
    // "any-arbitrary-string"` and the gateway would accept them
    // (because the string was non-empty)。
    //
    // This adapter (in BASOrchestration where it can import both
    // BASMemory's MCP gateway types + BASPolicy's BASActionPermit)
    // closes the gap:given a live `BASActionPermit` (from the
    // host's `riskService.gateAction(...)` output),validate the
    // MCP invocation against the permit's actual fields:
    //   - Rule 1:permit.mode is NOT `.block` (blocked → reject)
    //   - Rule 2:mcpServerID is in permit.allowedDomains
    //     (whitelist match — required if allowedDomains non-empty)
    //   - Rule 3:mcpServerID is NOT in permit.blockedDomains
    //     (blocklist match — defense even if allowedDomains
    //     empty)
    //   - Rule 4:permit.toolScope is NOT "denied" (semantic
    //     scope deny → reject)
    //
    // Returns a (Bool, [String]) — accepted flag + ordered
    // audit refs for the L14 ledger pipeline (reserved prefix
    // `agentMCP.permit:` per future allocation)。
    //
    // Early-return doctrine same as ch 981.9 warrant validator:
    // first matching deny rule wins;defense-in-depth doctrine。

    /// Validate an MCP invocation against a live `BASActionPermit`。
    /// Closes ch 982.5 META-REVIEW Gap 2 (MCP gateway orthogonal
    /// to BASPolicy.BASActionPermit)。
    ///
    /// - Parameters:
    ///   - invocation: the MCP envelope the caller assembled
    ///   - permit: live `BASActionPermit` from
    ///     `riskService.gateAction(...)` for this turn
    /// - Returns: `(accepted, auditRefs)` where `auditRefs`
    ///   carry signals like `agentMCP.permit:granted:server=X`
    ///   or `agentMCP.permit:rejected:reason=blocked-mode` ready
    ///   to be appended to the L14 audit ledger
    public static func validateMCPInvocation(
        _ invocation: BASMCPInvocation,
        against permit: BASActionPermit
    ) -> (accepted: Bool, auditRefs: [String]) {
        // Rule 1:permit mode block → reject (highest priority)
        if permit.mode == .block {
            return (
                accepted: false,
                auditRefs: [
                    "agentMCP.permit:rejected:" +
                    "reason=blocked-mode:server=" +
                    "\(invocation.mcpServerID)",
                ])
        }
        // Rule 2:blocklist match → reject (defense-in-depth
        // checked BEFORE allowlist so a server can be explicitly
        // forbidden even when allowedDomains is broad)
        if permit.blockedDomains.contains(invocation.mcpServerID)
        {
            return (
                accepted: false,
                auditRefs: [
                    "agentMCP.permit:rejected:" +
                    "reason=in-blocked-domains:server=" +
                    "\(invocation.mcpServerID)",
                ])
        }
        // Rule 3:if allowedDomains is non-empty,it acts as
        // whitelist — server MUST be in it。 Empty allowedDomains
        // = permissive (anything not blocked is allowed)。
        if !permit.allowedDomains.isEmpty &&
           !permit.allowedDomains.contains(
                invocation.mcpServerID)
        {
            return (
                accepted: false,
                auditRefs: [
                    "agentMCP.permit:rejected:" +
                    "reason=not-in-allowed-domains:server=" +
                    "\(invocation.mcpServerID)",
                ])
        }
        // Rule 4:toolScope semantic deny → reject。
        // chapter 九百九十一.5 META-REVIEW CRITICAL-1 fix:
        // Round-9-review caught that ch 990 only checked "denied",
        // but production code emits "none" (5 call sites in
        // EBrainRuntimeCoordinator+Permit.swift + EBrainHostRuntime
        // +RiskService.swift) and "blocked" (BASPolicy
        // /EBrainRiskPlaneCore.swift line 254) as the canonical
        // deny scopes。 The string "denied" appears NOWHERE in
        // production — so every live deny-scope permit was being
        // ACCEPTED by the adapter,a real defense-in-depth bypass。
        // Fix:accept all three canonical deny scopes。
        let denyScopes: Set<String> = [
            "none", "blocked", "denied",
        ]
        if denyScopes.contains(permit.toolScope) {
            return (
                accepted: false,
                auditRefs: [
                    "agentMCP.permit:rejected:" +
                    "reason=denied-tool-scope:server=" +
                    "\(invocation.mcpServerID):scope=" +
                    "\(permit.toolScope)",
                ])
        }
        // All rules passed — granted
        return (
            accepted: true,
            auditRefs: [
                "agentMCP.permit:granted:server=" +
                "\(invocation.mcpServerID):tool=" +
                "\(invocation.toolID):scope=" +
                "\(permit.toolScope)",
            ])
    }

    // MARK: - chapter 九百八十九 / M3650 — Cross-Module Integration
    //                                       Arc ch7:Gap 5 close
    //
    // Project the fabric's per-candidate accepted deltas back into
    // a host-shape `BASCandidateFrontier` summary。 Was:
    // `BASPlannerSeat.emit(...)` produced `.candidateFrontier`
    // state-graph deltas with refs like `candidateFrontier#cf-
    // <turnID>-<candidateID>` and per-candidate JSON payloads (one
    // delta per candidate)。 But the host's existing
    // `BASCandidateFrontier` (L9 dream loop) is an AGGREGATE
    // structure with candidateIDs / dominanceOrder /
    // reversiblePaths / guardPaths / frontierWidth /
    // diversityScore。 The two abstractions were disjoint — no
    // path projected the fabric's per-candidate deltas back into
    // a host-consumable aggregate frontier。
    //
    // This adapter closes Gap 5:given the fabric's planner
    // candidates list (input to the Planner seat) the adapter
    // computes the corresponding host-shape `BASCandidateFrontier`
    // summary。 The host can then:
    //   - Read the fabric's planner output as a familiar
    //     aggregate structure
    //   - Compare fabric-derived dominanceOrder against the host's
    //     own L9 dominance computation (sanity check)
    //   - Feed the projection back into the next turn's L9
    //     planning if desired
    //
    // Projection rules (pure-fn):
    //   - `candidateIDs` = input order (preserves the host's
    //     original candidate enumeration)
    //   - `dominanceOrder` = candidates sorted by confidence
    //     DESCENDING (ties broken by candidateID lex ascending
    //     for determinism)
    //   - `reversiblePaths` = candidates in the canonical reversible band
    //     (`BASReversibilityBands.isReversiblePath`)
    //   - `guardPaths` = candidates that are PROTECTIVE SAFE-RETREAT fallbacks —
    //     HIGH reversibility (`BASReversibilityBands.isGuardPath`), per BASGuardBranch.
    //     audit orchestration HIGH-1: this was INVERTED (`reversibility < 0.3`),
    //     feeding L9 the opposite guard set from the neural producer.
    //   - `frontierWidth` = candidate count
    //   - `diversityScore` = `1 - <std-dev of confidence>` clamped
    //     to [0,1] (high diversity = low std-dev across confidences
    //     = candidates are spread, not clustered)
    //   - `delayedPaths` = empty (delay-classification is L11
    //     domain, not derivable from planner output alone)

    /// Project a list of `BASPlannerCandidate` (the fabric's
    /// planner input) into a host-shape `BASCandidateFrontier`
    /// summary。 Closes ch 982.5 META-REVIEW Gap 5
    /// (fabric `.candidateFrontier` disjoint from host
    /// `BASCandidateFrontier`)。
    ///
    /// Pure-fn deterministic — same input always produces
    /// byte-equal output。
    ///
    /// - Parameter candidates: the list passed to Planner seat
    /// - Returns: host-shape aggregate frontier projection
    public static func candidateFrontierProjection(
        from candidates: [BASPlannerCandidate]
    ) -> BASCandidateFrontier {
        let candidateIDs = candidates.map { $0.candidateID }
        // Dominance order:confidence descending,ties broken by
        // candidateID lex ascending for determinism。
        let dominanceOrder = candidates
            .sorted { a, b in
                if a.confidence != b.confidence {
                    return a.confidence > b.confidence
                }
                return a.candidateID < b.candidateID
            }
            .map { $0.candidateID }
        // Reversibility-band classification per ch 958 + ch 967
        // bands。
        let reversiblePaths = candidates
            .filter { BASReversibilityBands.isReversiblePath(reversibility: $0.reversibility) }
            .map { $0.candidateID }
        // audit orchestration HIGH-1: guardPaths are SAFE-RETREAT fallbacks (HIGH reversibility),
        // not the danger band — was `reversibility < 0.3`, the exact opposite of the canonical
        // BASGuardBranch semantic + the neural producer.
        // deep-audit MED: mirror the neural producer — a guard path is a high-reversibility fallback OR
        // an explicit guard-lexicon match on title/summary (was reversibility-band ONLY, so a
        // low-reversibility "pause and review" candidate was a guard path in the neural producer but a
        // danger path here). Single source of truth: BASReversibilityBands.containsGuardLexicon.
        let guardPaths = candidates
            .filter {
                BASReversibilityBands.isGuardPath(reversibility: $0.reversibility)
                    || BASReversibilityBands.containsGuardLexicon($0.title)
                    || BASReversibilityBands.containsGuardLexicon($0.actionSummary)
            }
            .map { $0.candidateID }
        // Diversity score = 1 - std-dev(confidence),clamped。
        // Empty / single-candidate case is "perfectly diverse"
        // by convention (no variance possible)。
        let diversity: Double
        if candidates.count < 2 {
            diversity = 1.0
        } else {
            let confs = candidates.map { $0.confidence }
            let mean = confs.reduce(0.0, +)
                / Double(confs.count)
            let variance = confs.map { ($0 - mean) * ($0 - mean) }
                .reduce(0.0, +) / Double(confs.count)
            let stdDev = variance.squareRoot()
            // std-dev is in [0, 0.5] for confidence ∈ [0,1] when
            // the distribution is bimodal extremes;normalize
            // by 0.5 to map to [0,1] then invert
            let normalized = min(1.0, stdDev / 0.5)
            diversity = max(0.0, min(1.0, 1.0 - normalized))
        }
        return BASCandidateFrontier(
            candidateIDs: candidateIDs,
            dominanceOrder: dominanceOrder,
            reversiblePaths: reversiblePaths,
            guardPaths: guardPaths,
            frontierWidth: candidates.count,
            diversityScore: diversity,
            delayedPaths: [])
    }

    // MARK: - chapter 九百八十八 / M3645 — Cross-Module Integration
    //                                       Arc ch6:Gap 4 close
    //
    // Enrich BASCriticSeatInput from live BASTriSelfScore[]。 Was:
    // `BASCriticSeat` consumed a `superegoActiveLevel: Double`
    // parameter that callers had to provide manually — but ch 953
    // plan section 9 + the L10 tribunal design intent specifically
    // requires the Critic seat to WRAP `triSelfService.superego
    // (judgement)`。 Without this wire,the fabric Critic was a
    // pure-function on candidate paths,disconnected from the L10
    // 三我庭's id/ego/superego scoring。 Two parallel critique
    // computations,no path connecting them。
    //
    // Per ch 956 plan + the L10 design,the fabric Critic seat is
    // invoked BEFORE the live triSelf service (so the fabric's
    // critique informs triSelf's id/ego/superego scoring,not the
    // other way around)。 This adapter is for the COMPLEMENTARY
    // case:after triSelf has scored,enrich the NEXT turn's
    // Critic input with the prior turn's superego signal,so the
    // fabric Critic seat reflects the host's previously-computed
    // superego concern level。
    //
    // Computation:
    //   - `superegoActiveLevel` raised (max) to the average
    //     `superegoScore` across non-vetoed candidates in the
    //     prior turn's tri-self output
    //   - Per ch 967 monotonic raise — never lowers the
    //     superegoActiveLevel
    //   - Empty triScores leaves the base input unchanged
    //
    // Pure-fn deterministic given inputs。

    /// Enrich a `BASCriticSeatInput` with signals from the prior
    /// turn's live `BASTriSelfScore[]`。 Closes ch 982.5
    /// META-REVIEW Gap 4 (fabric Critic seat orthogonal to live
    /// BASMLTriSelfService)。
    ///
    /// chapter 九百九十一.5 META-REVIEW HIGH-1 fix:Round-9 review
    /// caught CRITICAL SEMANTIC INVERSION。 Per `BASMLTriSelfService
    /// .swift:119-120`,`superegoScore = clamp(reversibility)` —
    /// HIGH score = SAFE candidate (high reversibility),LOW score
    /// = UNSAFE candidate。 Veto fires when `superegoScore < threshold`。
    /// The pre-fix adapter averaged the non-vetoed (i.e. SAFE)
    /// candidates' superego scores and used the average AS
    /// `superegoActiveLevel` — which means 3 safe candidates
    /// produced a HIGH strictness reading (inverted!)。 Correct
    /// semantic:`superegoActiveLevel` is CONCERN intensity,which
    /// should RISE when candidates are UNSAFE,not safe。
    ///
    /// Fix:use FRACTION VETOED as the concern signal。
    ///   - 0 vetoed / N total → 0 concern (all candidates safe)
    ///   - N vetoed / N total → 1.0 concern (all unsafe)
    ///   - Mixed → fraction in (0, 1) monotone-continuous
    ///
    /// Monotonic raise:`superegoActiveLevel = max(base,
    /// fractionVetoed)` — never lowers per ch 967。 Empty triScores
    /// produces a no-op (returns base unchanged)。
    ///
    /// - Parameters:
    ///   - triScores: live `BASTriSelfScore[]` from the prior
    ///     turn's `triSelfService.mergeChoice(...)` output
    ///   - baseCriticInput: existing `BASCriticSeatInput` built
    ///     by `criticInput(from:superegoActiveLevel:)` or directly
    /// - Returns: enriched `BASCriticSeatInput` with concern
    ///   signal raised (max) to the prior turn's fraction-vetoed
    public static func enrichCriticInput(
        from triScores: [BASTriSelfScore],
        baseCriticInput: BASCriticSeatInput
    ) -> BASCriticSeatInput {
        // No prior tri scores → return base unchanged
        guard !triScores.isEmpty else { return baseCriticInput }
        // chapter 九百九十一.5 fix:fraction vetoed = concern
        // signal。 Replaces the inverted "avg superego of
        // non-vetoed" logic which raised strictness when
        // candidates were SAFE。
        let vetoedCount = triScores.filter { $0.veto }.count
        let fractionVetoed =
            Double(vetoedCount) / Double(triScores.count)
        // Defensive clamp + monotonic raise (ch 967)
        let clamped = max(0.0, min(1.0, fractionVetoed))
        let mergedLevel = max(
            baseCriticInput.superegoActiveLevel, clamped)
        return BASCriticSeatInput(
            candidates: baseCriticInput.candidates,
            superegoActiveLevel: mergedLevel)
    }

    // MARK: - chapter 九百八十六 / M3635 — Cross-Module Integration
    //                                       Arc ch4:Gap 1 close
    //
    // BASHostAlignmentInput from live BASHostConstitution。 Was:
    // `BASHostAlignmentSeat` had a free-form `hostConstraintsRef`
    // String parameter — caller could pass any string,no validation,
    // no actual coupling to the host's live L5 constitution。 Per
    // ch 982.5 META-REVIEW Gap 1,this meant the fabric's host-
    // alignment seat was orthogonal to the live host constitution
    // — a major design intent violation。
    //
    // This adapter closes the gap:given a live `BASHostConstitution`
    // (already available on the coordinator),build a
    // `BASHostAlignmentInput` that:
    //   - Derives `hostBoundaryAxes` from the union of
    //     `valueAxes.axes` + `boundaryVeil.hardNoGo` (the two
    //     fields that ARE the user's host-level "what's protected"
    //     declarations per the L5 whitepaper)
    //   - Pulls `hostID` directly from the constitution
    //   - Derives `styleStrictness` from `styleGenome.structureBias`
    //     (higher structureBias → stricter alignment) unless caller
    //     overrides (host may have a more nuanced computed measure)
    //   - Accepts caller-supplied `candidates` since the fabric
    //     doesn't yet know which axes each candidate touches —
    //     that semantic mapping is host-app responsibility
    //
    // Deterministic:`hostBoundaryAxes` sorted lex so two calls
    // with the same constitution produce byte-equal output。

    // MARK: - chapter 九百八十七 / M3640 — Cross-Module Integration
    //                                       Arc ch5:Gap 3 close
    //
    // Enrich BASRiskInput from a live BASRiskCard。 Was:
    // `BASRiskSeat` consumed `BASRiskInput.pressureLevel /
    // manipulationDetected / boundaryTouched` derived ONLY from
    // L7 Scout output — completely orthogonal to the host's live
    // `BASRiskServicing.calibrateRisk(...)` which produces a
    // `BASRiskCard` with totalRisk / uncertainty / irreversibility
    // / manipulationStrength / gsiScore。 Per ch 982.5 META-REVIEW
    // Gap 3,this meant the substrate had TWO PARALLEL risk
    // computations:the existing host risk service (L11) AND the
    // fabric's risk seat,with no path connecting them。
    //
    // This adapter closes the gap:given a `BASRiskCard` produced
    // by the live risk service,enrich an existing `BASRiskInput`:
    //   - `pressureLevel` is RAISED (max) to the card's totalRisk
    //     value。 Per ch 967 monotonic-raise discipline,risk
    //     CANNOT be lowered by enrichment。
    //   - `manipulationDetected` is OR-ed with the card's
    //     manipulationStrength >= 0.5 trigger
    //   - `boundaryTouched` is preserved as-is (the card doesn't
    //     have a direct "boundary touched" signal — that signal
    //     comes from L7 Scout's boundaryTouchCount per ch 957
    //     design,which already feeds the base input)
    //   - candidates pass through unchanged
    //
    // Per Root Law 4 (单主权) + ch 967 monotonic raise — the
    // adapter NEVER reduces risk。 Enrichment is union not
    // intersection。

    /// Enrich a `BASRiskInput` with signals from a live
    /// `BASRiskCard`。 Closes ch 982.5 META-REVIEW Gap 3
    /// (fabric risk seat orthogonal to live BASRiskServicing)。
    ///
    /// Monotonic raise discipline:
    ///   - `pressureLevel` only goes UP (max of input + card)
    ///   - `manipulationDetected` only flips ON (input || card-signal)
    ///   - `boundaryTouched` unchanged (signal source is L7 Scout)
    ///
    /// - Parameters:
    ///   - card: live `BASRiskCard` from `BASRiskServicing
    ///     .calibrateRisk(...)`
    ///   - baseRiskInput: existing `BASRiskInput` built by
    ///     `riskInput(from:candidates:)` from L7 decompose output
    /// - Returns: enriched `BASRiskInput` with the union of
    ///   risk signals
    public static func enrichRiskInput(
        from card: BASRiskCard,
        baseRiskInput: BASRiskInput
    ) -> BASRiskInput {
        // chapter 九百九十二 / M3665 META-REVIEW MED-1 fix:was
        // clamping only the card operand (`max(0, min(1, card
        // .totalRisk))`),which is already clamped by
        // `BASRiskCard.init` so that clamp was dead code。
        // `base.pressureLevel` is NOT clamped by `BASRiskInput
        // .init` so a caller passing pressureLevel=5.0 would
        // propagate out-of-range。 Defense in the right place:
        // clamp the MERGED RESULT at [0,1] so adapter boundary
        // produces well-formed output regardless of input。
        // Monotonic raise (Root Law 4 + ch 967) preserved:max()
        // never lowers either operand。
        let rawMerged = max(
            baseRiskInput.pressureLevel,
            card.totalRisk)
        let mergedPressure = max(0.0, min(1.0, rawMerged))
        // Card's manipulationStrength >= 0.5 considered triggering。
        let cardManipulationTrigger =
            card.manipulationStrength >= 0.5
        let mergedManipulation =
            baseRiskInput.manipulationDetected ||
            cardManipulationTrigger
        return BASRiskInput(
            candidates: baseRiskInput.candidates,
            pressureLevel: mergedPressure,
            manipulationDetected: mergedManipulation,
            boundaryTouched: baseRiskInput.boundaryTouched)
    }

    /// Build a `BASHostAlignmentInput` from a live
    /// `BASHostConstitution`。 Closes ch 982.5 META-REVIEW Gap 1
    /// (host alignment seat orthogonal to live host constitution)。
    ///
    /// chapter 九百九十二 / M3665 META-REVIEW MED-3 fix:Round-9
    /// caught that pre-fix adapter only unioned `hardNoGo` from
    /// `BASBoundaryVeil`,but `BASBoundaryVeil` has 5 fields:
    /// hardNoGo + softCaution + confirmRequired +
    /// restrictedMemoryDomains + restrictedToolDomains。 Pre-fix
    /// limited alignment surface to ONLY hardNoGo — missing 4
    /// fields the host may have marked as protected。 New
    /// `includeSoftAxes` flag (default false to preserve ch 986
    /// byte-equality) opts in to the broader 5-field union for
    /// hosts whose alignment policy is "warn me about anything
    /// I've protected"。
    ///
    /// - Parameters:
    ///   - constitution: live L5 host constitution from the
    ///     coordinator's `hostConstitution` slot
    ///   - candidates: per-turn candidates with their axis touches
    ///     (caller computes since axis-touch is host-app
    ///     semantics)
    ///   - styleStrictnessOverride: if non-nil,used instead of
    ///     the derived `styleGenome.structureBias` value
    ///   - includeSoftAxes: if true,boundary axes include
    ///     softCaution + confirmRequired + restrictedMemoryDomains
    ///     + restrictedToolDomains。 Default false preserves ch 986
    ///     byte-equality。 Set true for broader alignment surface。
    /// - Returns: well-formed `BASHostAlignmentInput`
    public static func hostAlignmentInput(
        from constitution: BASHostConstitution,
        candidates: [BASHostAlignmentCandidate] = [],
        styleStrictnessOverride: Double? = nil,
        includeSoftAxes: Bool = false
    ) -> BASHostAlignmentInput {
        // Boundary axes = union of valueAxes.axes + boundaryVeil
        // fields (hardNoGo always;softCaution/confirmRequired/
        // restrictedMemoryDomains/restrictedToolDomains gated on
        // includeSoftAxes flag),sorted lex for determinism。 Per
        // L5 whitepaper §6 valueAxes carries the host's
        // articulated value structure;boundaryVeil enumerates
        // protection levels。 ch 992 MED-3:caller decides whether
        // soft axes also count as alignment-significant。
        var allAxes = constitution.valueAxes.axes
        allAxes.append(contentsOf:
            constitution.boundaryVeil.hardNoGo)
        if includeSoftAxes {
            allAxes.append(contentsOf:
                constitution.boundaryVeil.softCaution)
            allAxes.append(contentsOf:
                constitution.boundaryVeil.confirmRequired)
            allAxes.append(contentsOf: constitution
                .boundaryVeil.restrictedMemoryDomains)
            allAxes.append(contentsOf: constitution
                .boundaryVeil.restrictedToolDomains)
        }
        let unionAxes = Set(allAxes)
        let boundaryAxes = Array(unionAxes).sorted()
        // styleStrictness derived from structureBias which is
        // already in [0.0, 1.0] per BASStyleGenome contract。
        // Defensive clamp anyway。
        let derivedStrictness = max(0.0, min(1.0,
            constitution.styleGenome.structureBias))
        let strictness =
            styleStrictnessOverride ?? derivedStrictness
        return BASHostAlignmentInput(
            candidates: candidates,
            hostBoundaryAxes: boundaryAxes,
            styleStrictness: max(0.0, min(1.0, strictness)),
            hostID: constitution.hostID)
    }
}
