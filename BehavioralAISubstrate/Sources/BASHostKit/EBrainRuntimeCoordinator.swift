import CryptoKit
import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore
// M320 — `BASUnknownReserve.derive(...)` lives in BASWorldPrior
// and is invoked from `runTurn` to project per-turn unknowns.
import BASWorldPrior

// MARK: - M71 split — BASEBrainRuntimeCoordinator now lives in its own file.
// Types (BASEBrainTurnRequest / BASEBrainTurnResult), evolution summary/
// precision-hotcold/breath-bridge helpers, and shared internal utilities
// (EvolutionSovereignBridgeProjection, String.trimmedNonEmpty, etc.) moved to
// sibling files in BASHostKit during the M71 cohesion split.  The coordinator
// itself is next on the list to be split by cohesion; this commit only removes
// the duplicated pre-struct content.

public struct BASEBrainRuntimeCoordinator {
    public var powerClockService: any BASPowerClockServicing
    public var hostProfileService: any BASHostProfileServicing
    public var contextService: any BASContextServicing
    public var decomposeService: any BASDecomposeServicing
    public var memoryService: any BASMemoryServicing
    public var neuralCoreService: (any BASNeuralCoreServicing)?
    public var loopService: any BASLoopServicing
    public var triSelfService: any BASTriSelfServicing
    public var riskService: any BASRiskServicing
    public var actionService: any BASActionServicing
    public var evolutionService: any BASEvolutionServicing
    public var policyLineage: BASRuntimePolicyLineage?
    public var hostRhythmProfile: BASHostRhythmProfile
    public var hostConstitution: BASHostConstitution?
    public var hostConstitutionVault: BASHostConstitutionVault?
    public var hostVersionTree: BASHostVersionTree?
    public var hostForgetRequest: BASForgetRequest?

    // MARK: - M420 hot-path string constants (chapter 一百)
    //
    // Chapter 一百 deep-bench optimization: invariant string arrays
    // used by the M402 / M405 Kunlun-doctrine derive seams are
    // hoisted to `static let` so each `runTurn` invocation reuses
    // the same Array<String> reference instead of allocating fresh
    // copies. Same string array reference shared between the
    // upstream "for-gate" derive (line ~466) and downstream
    // "for-audit" derive (line ~964).
    //
    // Prior state: each `runTurn` allocated 2× 14-element arrays
    // (activeLayerRefs) + 1× 5-element array (transformationSteps)
    // + 2× 3-element arrays (centerlineRules). Each allocation
    // touches the heap and dirties the stack; replacing with
    // shared static references avoids ~38 string-array allocations
    // and ~18 string-interpolation calls per turn.
    //
    // Doctrine pin: zero behavior change. The arrays' contents
    // are byte-identical to the inline literals they replace.
    // Specifically verified by:
    //   - `BASKunlunProtocolTests` (M401, 37 schema-parity tests)
    //     pinning the field round-trip Codable behavior of
    //     BASKunlunAxis (which holds activeLayerRefs +
    //     centerlineRules).
    //   - `M402KunlunAxisAuditTests` pinning the runtime emission
    //     of `kunlun.axis.center` / `.deviation` /
    //     `.requires-gate` codes from the axis derive.
    //   - `M404M405KunlunJadeRiverAuditTests` pinning emission
    //     of `kunlun.river.transformations` (uses
    //     riverOriginTransformationSteps) + `kunlun.jade.seal`.
    //   - `M408M409M410KunlunYaochiTianmenAuditTests` pinning
    //     emission of `kunlun.yaochi.access` (uses
    //     yaochiAuditRevealConditions).
    //   - `M415KunlunBehavioralSnapshotTests` byte-equal snapshots
    //     of every derive seam — these would fail loudly if the
    //     static-let arrays diverged in any byte from the inline
    //     literals.
    //
    // M421 update: the original M420 perf claim of "-8.6%" was
    // statistical noise (N=1 measurement). Re-measurement at N=10
    // × 200 sessions found the effect indistinguishable from noise
    // at 95% CI. M420 is kept as code-quality / structural
    // cleanup (zero behavior change verified above), not as a
    // perf win. See `docs/QINAO_M421_M420_STAT_RIGOROUS_ANALYSIS_2026-05-03.md`.

    /// 14-layer ref list used by the M402 axis derive (both
    /// upstream gate-side and downstream audit-side).
    fileprivate static let kunlunActiveLayerRefs: [String] = [
        "L1", "L2", "L3", "L4", "L5", "L6",
        "L7", "L8", "L9", "L10", "L11", "L12",
        "L13", "L14",
    ]

    /// **M595 chapter 一百六十六 — anti-magic-number**: deviation
    /// threshold for `BASKunlunAxis` construction. Used at BOTH
    /// the gate-side (line ~1048) AND audit-side (line ~1820)
    /// construction. Pre-fix both call sites had inline `0.7`,
    /// duplicating the magic literal.
    /// Doctrine derivation: 0.7 is the centerScore threshold above
    /// which alignment is "centered" (axis aligned with target).
    /// Below 0.7 → requiresGate = true → axis-aware permit
    /// escalation per Kunlun §4.1.
    fileprivate static let kunlunAxisDeviationThreshold: Double =
        0.7

    /// **M595 chapter 一百六十六 — anti-magic-number**: default
    /// confidence floor when `thoughtFrame.uncertaintyLedger` is
    /// nil (no L4 uncertainty derivation). 1.0 = fully confident
    /// = no uncertainty cap = `BASUnknownReserve` returns
    /// assertion ceiling `.unrestricted`. Used at BOTH gate-side
    /// (line ~1028) AND audit-side (line ~1834) BASUnknownReserve
    /// derive calls; pre-fix both call sites had inline `?? 1.0`.
    /// Doctrine: absent uncertainty ledger → trust thought frame;
    /// don't spurious-cap permit assertions when we have no
    /// reason to.
    fileprivate static let
        defaultConfidenceFloorWhenNoUncertaintyLedger: Double =
        1.0

    /// 5-step pipeline transformation list used by the M405
    /// River-Origin trace derive.
    fileprivate static let riverOriginTransformationSteps: [String] = [
        "risk.bind", "permit.synthesize", "neural.materialize",
        "tribunal.merge", "audit.emit",
    ]

    /// Pre-computed centerline-rules array per
    /// `BASActionPermitMode`. Avoids per-turn string interpolation
    /// + 3-element array allocation in M402 axis derive.
    /// Computed once at first access (Swift static-let lazy init).
    fileprivate static let kunlunCenterlineRulesByMode:
        [BASActionPermitMode: [String]] =
    {
        var result: [BASActionPermitMode: [String]] = [:]
        for mode in BASActionPermitMode.allCases {
            result[mode] = [
                "respects-host-boundary",
                "honors-world-anchor",
                "permit-mode-\(mode.rawValue)",
            ]
        }
        return result
    }()

    /// M422 fix-pin (chapter 一百一 deep-review): explicit lookup
    /// helper for `kunlunCenterlineRulesByMode` that fails fast in
    /// debug builds when a permit mode is missing from the dict.
    /// Pre-fix the call sites used `?? []` silent fallback, which
    /// would have masked any future drift (e.g. a new
    /// `BASActionPermitMode` case added without updating the dict)
    /// by silently emitting an empty `centerlineRules` array —
    /// changing the M402 axis-emission byte-stream silently and
    /// breaking M415 byte-equal snapshot tests downstream rather
    /// than at the lookup site. The `assertionFailure` makes the
    /// developer error surface immediately in debug + tests; the
    /// `return []` graceful-degradation path stays for release
    /// builds (per substrate doctrine of graceful degradation).
    fileprivate static func kunlunCenterlineRules(
        for mode: BASActionPermitMode
    ) -> [String] {
        if let rules = kunlunCenterlineRulesByMode[mode] {
            return rules
        }
        assertionFailure(
            "BASActionPermitMode \(mode) missing from " +
            "kunlunCenterlineRulesByMode. Did you add a new " +
            "permit-mode case without updating the dict's " +
            "static-let initializer?")
        return []
    }

    // MARK: - M450 (chapter 一百十八) — cosmic-cold counterweight derivation
    //
    // 4 pure functions deriving the L10 cosmic-cold counterweight
    // axes from existing turn state. Each output ∈ [0, 1] per
    // chapter 一百十四 schema doctrine. Anti-magic-number: every
    // numeric literal is justified by the white-paper threshold
    // table or the M384/M406 escalation precedent.

    /// `dignityBias` axis — high when narrowing risk requires
    /// surface-level dignity preservation. Permit-mode-aware:
    /// when the L11 wind gate has narrowed below `.answer`,
    /// the host's dignity surface is at risk.
    fileprivate static let dignityBiasExtremeWithNarrowedMode: Double = 0.85
    fileprivate static let dignityBiasExtremeWithAnswerMode: Double = 0.5
    fileprivate static let dignityBiasHighWithNarrowedMode: Double = 0.7
    fileprivate static let dignityBiasMediumNarrowed: Double = 0.55
    fileprivate static let dignityBiasBaseline: Double = 0.2

    fileprivate static func dignityBiasFromRisk(
        _ riskLevel: BASBrainRiskLevel,
        permitMode: BASActionPermitMode
    ) -> Double {
        let narrowed = (permitMode != .answer)
        switch riskLevel {
        case .extreme:
            return narrowed
                ? dignityBiasExtremeWithNarrowedMode
                : dignityBiasExtremeWithAnswerMode
        case .high:
            return narrowed
                ? dignityBiasHighWithNarrowedMode
                : dignityBiasBaseline
        case .medium:
            return narrowed
                ? dignityBiasMediumNarrowed
                : dignityBiasBaseline
        case .low:
            return dignityBiasBaseline
        }
    }

    /// `agencyFloor` axis — high when candidate slate is narrow
    /// (≤ 1 candidate), so the host has limited choice and
    /// agency must be explicitly preserved.
    fileprivate static let agencyFloorWithNoCandidates: Double = 0.85
    fileprivate static let agencyFloorWithSingleCandidate: Double = 0.7
    fileprivate static let agencyFloorWithDualCandidates: Double = 0.4
    fileprivate static let agencyFloorBaseline: Double = 0.2

    fileprivate static func agencyFloorFromCandidates(
        _ count: Int
    ) -> Double {
        if count == 0 { return agencyFloorWithNoCandidates }
        if count == 1 { return agencyFloorWithSingleCandidate }
        if count == 2 { return agencyFloorWithDualCandidates }
        return agencyFloorBaseline
    }

    /// `antiFatalism` axis — high when risk level signals "this
    /// is just how it is" framing pressure. Reject cosmic-fatalism
    /// per Cthulhu RL5 (不把宇宙冷感做成宿主冷处理).
    fileprivate static let antiFatalismExtreme: Double = 0.85
    fileprivate static let antiFatalismHigh: Double = 0.65
    fileprivate static let antiFatalismMedium: Double = 0.35
    fileprivate static let antiFatalismLow: Double = 0.1

    fileprivate static func antiFatalismFromRisk(
        _ riskLevel: BASBrainRiskLevel
    ) -> Double {
        switch riskLevel {
        case .extreme: return antiFatalismExtreme
        case .high: return antiFatalismHigh
        case .medium: return antiFatalismMedium
        case .low: return antiFatalismLow
        }
    }

    /// `antiPaternalism` axis — high when permit narrows below
    /// `.answer`, signalling "the system is deciding for the
    /// host". Reject paternalism per Cthulhu RL10.
    fileprivate static let antiPaternalismDelayOrEscalate: Double = 0.85
    fileprivate static let antiPaternalismMirrorOrCompare: Double = 0.65
    fileprivate static let antiPaternalismDraftOrLocal: Double = 0.45
    fileprivate static let antiPaternalismBlockOrReplace: Double = 0.3
    fileprivate static let antiPaternalismAnswerOrUnknown: Double = 0.1

    fileprivate static func antiPaternalismFromPermit(
        _ mode: BASActionPermitMode
    ) -> Double {
        switch mode {
        case .delay, .escalate:
            return antiPaternalismDelayOrEscalate
        case .mirror, .compare:
            return antiPaternalismMirrorOrCompare
        case .draftOnly, .localOnly:
            return antiPaternalismDraftOrLocal
        case .block, .replace:
            return antiPaternalismBlockOrReplace
        case .answer:
            return antiPaternalismAnswerOrUnknown
        }
    }

    /// M425 (chapter 一百一) — extracted Yaochi audit projection
    /// helper. Pre-extraction this 38-line block lived inline in
    /// `runTurn`; the extraction is part of the "shrink runTurn"
    /// refactor down-payment per chapter 九十八 deep-review M418-3.
    /// Pure function: same inputs always produce same outputs;
    /// no side effects. M408 doctrine pin (Yaochi sanctum 默认
    /// 不参与普通检索) still holds — the derive synthesizes an
    /// audit-only projection.
    fileprivate static func deriveYaochiAuditProjection(
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
    fileprivate static func deriveHeavenGateAuditProjection(
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
    fileprivate static func deriveLayerReconciliationReport(
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

    /// chapter 四百二 / M948:optional event log surface for hosts
    /// that opt into event-sourced atom storage。Default nil
    /// preserves byte-equal pre-Phase-1 behavior。
    public let memoryEventLog: (any BASEventLogStorage)?

    /// chapter 四百二 / M948:optional mutation event emitter
    /// hosts can use to bridge `BASMemoryMutationWriter` outcomes
    /// into the typed event log。Default nil preserves byte-equal
    /// pre-Phase-1 behavior。Per-turn `runTurn` is unchanged in
    /// Phase 1;Phase 2 (chapter 四百三) collapses the per-call
    /// emit-then-write step into one routine。
    public let memoryMutationEventEmitter:
        BASMemoryMutationEventEmitter?

    public init(
        powerClockService: any BASPowerClockServicing,
        hostProfileService: any BASHostProfileServicing,
        contextService: any BASContextServicing,
        decomposeService: any BASDecomposeServicing,
        memoryService: any BASMemoryServicing,
        neuralCoreService: (any BASNeuralCoreServicing)? = nil,
        loopService: any BASLoopServicing,
        triSelfService: any BASTriSelfServicing,
        riskService: any BASRiskServicing,
        actionService: any BASActionServicing,
        evolutionService: any BASEvolutionServicing,
        policyLineage: BASRuntimePolicyLineage? = nil,
        hostRhythmProfile: BASHostRhythmProfile = .generic,
        hostConstitution: BASHostConstitution? = nil,
        hostConstitutionVault: BASHostConstitutionVault? = nil,
        hostVersionTree: BASHostVersionTree? = nil,
        hostForgetRequest: BASForgetRequest? = nil,
        memoryEventLog: (any BASEventLogStorage)? = nil,
        memoryMutationEventEmitter:
            BASMemoryMutationEventEmitter? = nil
    ) {
        self.powerClockService = powerClockService
        self.hostProfileService = hostProfileService
        self.contextService = contextService
        self.decomposeService = decomposeService
        self.memoryService = memoryService
        self.neuralCoreService = neuralCoreService
        self.loopService = loopService
        self.triSelfService = triSelfService
        self.riskService = riskService
        self.actionService = actionService
        self.evolutionService = evolutionService
        self.policyLineage = policyLineage
        self.hostRhythmProfile = hostRhythmProfile
        self.hostConstitution = hostConstitution
        self.hostConstitutionVault = hostConstitutionVault
        self.hostVersionTree = hostVersionTree
        self.hostForgetRequest = hostForgetRequest
        self.memoryEventLog = memoryEventLog
        self.memoryMutationEventEmitter =
            memoryMutationEventEmitter
    }

    public func runTurn(
        _ request: BASEBrainTurnRequest
    ) -> BASEBrainTurnResult {
        let requestedBudget = powerClockService.planBudget(
            deviceState: request.deviceState,
            taskPing: request.userInput,
            riskHint: request.riskHint
        )
        let (plannedBudget, budgetFindings) = normalizeBudget(
            requestedBudget,
            riskHint: request.riskHint,
            activeKillSwitches: request.activeKillSwitches
        )

        let routedBudget = BASBudgetFrame(
            schemaVersion: plannedBudget.schemaVersion,
            runMode: plannedBudget.runMode,
            maxLoops: plannedBudget.maxLoops,
            maxCandidates: plannedBudget.maxCandidates,
            maxDecodeTokens: plannedBudget.maxDecodeTokens,
            retrievalDepth: plannedBudget.retrievalDepth,
            precisionProfile: plannedBudget.precisionProfile,
            deviceRoute: powerClockService.routeDevice(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            thermalGuardLevel: plannedBudget.thermalGuardLevel,
            maintenanceAllowed: powerClockService.scheduleMaintenance(
                deviceState: request.deviceState,
                budget: plannedBudget
            ),
            leaseID: plannedBudget.leaseID,
            leaseExpiresAt: plannedBudget.leaseExpiresAt,
            maintenanceClass: plannedBudget.maintenanceClass,
            wakeIntentID: plannedBudget.wakeIntentID,
            allowedHeads: plannedBudget.allowedHeads,
            policyBundleVersion: plannedBudget.policyBundleVersion,
            policyDecisionIDs: plannedBudget.policyDecisionIDs
        )

        let hostContext = hostProfileService.resolveHost(
            hostID: request.hostID,
            contextFrame: nil,
            riskCard: nil
        )
        let rawContextFrame = contextService.analyzeContext(
            userInput: request.userInput,
            hostContext: hostContext,
            budget: routedBudget
        )

        // M53 — L6 presence-eye main-chain wiring. Derive the
        // per-channel observation bundle at the same seam where the
        // coordinator obtains the context frame, using the same
        // `sessionID` / `turnID` formula that `buildRuntimeTrace`
        // emits downstream. This keeps L6 observations
        // coherent-by-construction with the L14 audit record.
        // M956 chapter 四百三 系统熵 第四刀:replace inline derivation
        // with the M954 BASFrameContext factory。Single-source pin
        // is now compile-time enforced — the formula lives in
        // `BASFrameContext.init(hostID:taskTypeRaw:runModeRaw:
        // recordedAt:)` (chapter 二百一一)。Byte-equal output per
        // M954's verbatim-pin test。
        let frameContext = request.makeFrameContext(
            rawContextFrame: rawContextFrame,
            routedBudget: routedBudget)
        let derivedSessionID = frameContext.sessionID
        let derivedTurnID = frameContext.turnID
        let contextFrame = rawContextFrame
            .withDerivedPresenceObservationBundle(
                frameContext: frameContext)

        var decomposeFrame = decomposeService.decompose(
            contextFrame: contextFrame,
            memoryHints: []
        )
        decomposeFrame.mirrorText = decomposeService.mirror(
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame
        )
        if decomposeFrame.contradictions.isEmpty {
            decomposeFrame.contradictions = decomposeService.checkContradiction(
                contextFrame: contextFrame,
                decomposeFrame: decomposeFrame
            )
        }

        // M54 — L7 mirror-blade main-chain wiring. Derive the
        // per-signal decomposition bundle at the seam where
        // `decomposeFrame` has been fully populated (facts / mirror
        // text / contradictions), reusing the same sessionID / turnID
        // that the M53 L6 bundle and `buildRuntimeTrace` downstream
        // use. This keeps L7 observations coherent-by-construction
        // with the L14 audit record and with L6 on the same turn.
        decomposeFrame = decomposeFrame
            .withDerivedDecompositionObservationBundle(
                frameContext: frameContext)

        let rawMemoryBundle = memoryService.retrieve(
            decomposeFrame: decomposeFrame,
            hostContext: hostContext,
            budget: routedBudget
        )
        let (memoryBundle, memoryFindings) = normalizeMemoryBundle(
            rawMemoryBundle,
            budget: routedBudget
        )
        let baseNeuralCore = neuralCoreService?.synthesize(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        ) ?? defaultNeuralCoreFrame(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            activeKillSwitches: request.activeKillSwitches
        )

        var thoughtFrame = loopService.iterate(
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            budget: routedBudget
        )
        if thoughtFrame.candidates.isEmpty {
            thoughtFrame.candidates = loopService.proposePaths(
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle,
                budget: routedBudget
            )
        }
        if thoughtFrame.forecasts.isEmpty {
            thoughtFrame.forecasts = loopService.forecast(
                candidates: thoughtFrame.candidates,
                decomposeFrame: decomposeFrame,
                memoryBundle: memoryBundle
            )
        }
        if thoughtFrame.critiques.isEmpty {
            thoughtFrame.critiques = loopService.critique(
                candidates: thoughtFrame.candidates,
                forecasts: thoughtFrame.forecasts,
                hostContext: hostContext
            )
        }
        let (normalizedThoughtFrame, loopFindings) = normalizeThoughtFrame(
            thoughtFrame,
            budget: routedBudget
        )
        thoughtFrame = normalizedThoughtFrame
        thoughtFrame.organMap = baseNeuralCore.organMap
        let thoughtArtifacts = neuralCoreService?.materializeThoughtArtifacts(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            hostProfile: hostContext,
            thoughtFrame: thoughtFrame
        ) ?? BASNeuralMaterializationCompiler.materializeThoughtArtifacts(
            thoughtFrame: thoughtFrame
        )
        thoughtFrame.candidateFrontier = thoughtArtifacts.candidateFrontier
        thoughtFrame.counterfactualBundles = thoughtArtifacts.counterfactualBundles
        thoughtFrame.critiqueBundles = thoughtArtifacts.critiqueBundles
        thoughtFrame.uncertaintyLedger = thoughtArtifacts.uncertaintyLedger
        thoughtFrame.evidenceDebts = thoughtArtifacts.evidenceDebts
        thoughtFrame.convergenceCertificate = thoughtArtifacts.convergenceCertificate
        thoughtFrame.loopLeaseReceipt = thoughtArtifacts.loopLeaseReceipt
        thoughtFrame.sovereignBreakpointHints = thoughtArtifacts.sovereignBreakpointHints
        let publicProjection = neuralCoreService?.materializePublicProjection(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            hostProfile: hostContext,
            thoughtFrame: thoughtFrame
        ) ?? BASNeuralMaterializationCompiler.materializePublicProjection(
            thoughtFrame: thoughtFrame
        )
        if let projectedCandidates = publicProjection.candidates {
            thoughtFrame.candidates = projectedCandidates
        }
        if let projectedForecasts = publicProjection.forecasts {
            thoughtFrame.forecasts = projectedForecasts
        }
        if let projectedCritiques = publicProjection.critiques {
            thoughtFrame.critiques = projectedCritiques
        }

        // M59 — L4 world-prior main-chain wiring. Derive the
        // per-candidate / per-signal world-prior bundle at the seam
        // where `materializeThoughtArtifacts` has populated
        // counterfactualBundles / critiqueBundles / uncertaintyLedger
        // and `publicProjection` has merged candidate/forecast/critique
        // lists — before tri-self tribunal runs so L10 can see L4
        // signals on the same turn. Reuses M53's derived (sessionID,
        // turnID) so L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles on
        // this turn share strictly equal coordinates — the L14 audit
        // surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedWorldPriorObservationBundle(
                frameContext: frameContext)

        var (triScores, mergedChoice) = triSelfService.mergeChoice(
            thoughtFrame: thoughtFrame,
            hostContext: hostContext
        )
        thoughtFrame.triScores = triScores
        thoughtFrame.vetoMarks = mergedChoice.vetoMarks
        thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
        thoughtFrame.agencyReservation = mergedChoice.agencyReservation
        thoughtFrame.remandOrders = mergedChoice.remandOrders
        thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        let reconciledThoughtFrame = reconcileDreamLoopConvergence(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice
        )
        if reconciledThoughtFrame.stopReason != thoughtFrame.stopReason {
            thoughtFrame = reconciledThoughtFrame
            (triScores, mergedChoice) = triSelfService.mergeChoice(
                thoughtFrame: thoughtFrame,
                hostContext: hostContext
            )
            thoughtFrame.triScores = triScores
            thoughtFrame.vetoMarks = mergedChoice.vetoMarks
            thoughtFrame.tradeoffLedgers = mergedChoice.tradeoffLedgers
            thoughtFrame.agencyReservation = mergedChoice.agencyReservation
            thoughtFrame.remandOrders = mergedChoice.remandOrders
            thoughtFrame.courtDecisionDraft = mergedChoice.courtDecisionDraft
        }

        // M55 — L10 tri-self tribunal main-chain wiring. Derive the
        // per-voice tribunal bundle at the seam where the tribunal
        // has settled — after `triSelfService.mergeChoice` (and any
        // reconciliation rerun) has filled in triScores / vetoMarks
        // / tradeoffLedgers / remandOrders / courtDecisionDraft —
        // reusing the same sessionID / turnID that the M53 L6 bundle,
        // M54 L7 bundle, and `buildRuntimeTrace` downstream use. This
        // keeps L10 observations coherent-by-construction with the
        // L14 audit record and with L6 / L7 / L9 on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedTribunalObservationBundle(
                frameContext: frameContext)

        let riskService = self.riskService
        let rawRiskDecisionPackage = riskService.buildRiskDecisionPackage(
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            triScores: triScores,
            budget: routedBudget
        )
        let rawRiskCard = rawRiskDecisionPackage.riskCard
        let rawActionPermit = rawRiskDecisionPackage.actionPermit
        let (riskCard, actionPermit, riskFindings) = normalizeRiskDecision(
            riskCard: rawRiskCard,
            actionPermit: rawActionPermit,
            budget: routedBudget,
            activeKillSwitches: request.activeKillSwitches
        )
        var normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: rawRiskDecisionPackage,
            riskCard: riskCard,
            actionPermit: actionPermit
        )
        let resolvedRiskService = riskService
        let bindings = neuralCoreService?.materializeRiskBindings(
            budgetFrame: routedBudget,
            contextFrame: contextFrame,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeRiskBindings(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            riskCard: riskCard,
            actionPermit: actionPermit,
            riskLevelResolver: { score in
                resolvedRiskService.riskLevel(for: score)
            }
        )
        let primaryBinding = BASNeuralMaterializationCompiler.selectedRiskBinding(
            from: bindings,
            mergedChoice: mergedChoice,
            thoughtFrame: thoughtFrame
        )
        let boundRiskCard = primaryBinding?.riskCard ?? riskCard
        // M392 — `boundActionPermit` is rebound by the Cthulhu
        // doctrine gate block below (M303/M304/M384/M320/M385).
        // The block runs BEFORE `applySovereignNeuralContract`,
        // `materializeToolIntent`, `actionService.render`, and
        // `projectedRenderedOutput`, so the escalation /
        // assertion-ceiling cap is visible to every downstream
        // consumer (not just audit emission). M399's
        // `--cthulhu-end-to-end-demo` empirically verifies the
        // post-gate permit reaches surface render (e.g. the demo
        // run on 2026-05-02 produced `permit.mode = .delay,
        // stackedModes = [.draftOnly], assertionCeiling =
        // "meta-only"` after the gate fired, all reflected
        // verbatim in `result.actionPermit`).
        var boundActionPermit = primaryBinding?.actionPermit ?? actionPermit
        normalizedRiskDecisionPackage = projectedRiskDecisionPackage(
            from: normalizedRiskDecisionPackage,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            binding: primaryBinding
        )
        thoughtFrame.riskBindings = bindings.isEmpty ? nil : bindings
        thoughtFrame.riskCard = boundRiskCard
        thoughtFrame.actionPermit = boundActionPermit
        thoughtFrame.riskDecisionPackage = normalizedRiskDecisionPackage

        // M392 — Cthulhu doctrine pressure / anchor / unknown-reserve
        // derives + permit gating wires moved UP to here (was at the
        // audit-projection seam, line 681+). The wires now fire
        // BEFORE `actionService.render(...)` and
        // `projectedRenderedOutput(...)`, so the rendered surface
        // reflects the escalated stackedModes (M384) and the capped
        // assertionCeiling (M385). Pre-M392 the wires were
        // audit-visible only because the surface had already been
        // sealed against the un-escalated permit; post-M392 the
        // surface stays consistent with the persisted permit.
        //
        // The audit-projection block at line 681+ continues to
        // derive its own copies of `abyssalPressureForAudit`,
        // `humanAnchorSignalForAudit`, and `unknownReserveForAudit`
        // — those derives are pure functions of the same inputs and
        // produce identical outputs for audit emission. This is
        // intentional: the upstream derives feed the gating wires;
        // the downstream derives feed audit emission. Same values
        // by construction; separate locals for separation of
        // concerns.
        let abyssalPressureForGate = BASAbyssalPressureBudget
            .derive(
                turnID: derivedSessionID,
                riskLevel: boundRiskCard.riskLevel,
                uncertaintyLedger:
                    thoughtFrame.uncertaintyLedger,
                evidenceDebtCount:
                    thoughtFrame.evidenceDebts?.count ?? 0)
        let humanAnchorSignalForGate = BASHumanAnchorProtocol
            .derive(
                anchorID: "human-anchor-\(derivedSessionID)",
                hostSummaryRef: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                permitMode: boundActionPermit.mode,
                candidateCount: thoughtFrame.candidates.count)
        let abyssalEscalation = BASAbyssalPermitEscalation
            .escalate(
                permit: boundActionPermit,
                pressure: abyssalPressureForGate,
                humanAnchor: humanAnchorSignalForGate)
        boundActionPermit = abyssalEscalation.permit
        let unknownReserveForGate = BASUnknownReserve.derive(
            reserveID:
                "unknown-reserve-\(derivedSessionID)",
            confidenceFloor: thoughtFrame.uncertaintyLedger?
                .confidenceFloor
                ?? Self
                .defaultConfidenceFloorWhenNoUncertaintyLedger)
        let assertionCeilingDecisionForGate = BASAssertionCeilingGate
            .cap(
                permit: boundActionPermit,
                reserve: unknownReserveForGate)
        boundActionPermit = assertionCeilingDecisionForGate.permit
        // M406 — Kunlun axis-alignment escalation. Run AFTER the
        // M384 abyssal escalation + M385 assertion-ceiling cap so
        // axis deviations compose with Cthulhu pressure on the
        // same `boundActionPermit`. Doctrine: when both fire on
        // the same turn, both reason codes accumulate; mode
        // (single commit mouth) stays at L11.
        //
        // The "for-gate" alignment derive mirrors the audit-side
        // derive in the audit-projection seam below (line ~960).
        // Same inputs (host context + risk level + permit mode +
        // candidate count) → same output by construction. The
        // separation of locals follows the M392 pattern: upstream
        // values feed the gate; downstream values feed audit
        // emission.
        // chapter 四百九十四 / M1355 — Gate-side Kunlun axis fold。
        // The SAME inline-construction block (~89 LOC) that lived
        // at audit-side (lines ~1865-1953 pre-fold, folded by
        // chapter 493 M1348-M1349) ALSO lived at gate-side here。
        // M595 chapter 一百六十六 cross-site drift fix established
        // both sites must share predicate semantics — chapter 494
        // now shares the FACTORY (not just the semantics)。
        //
        // Gate-side passes `quarantineRecordsIsEmpty: true` to
        // skip the audit-side quarantine check (quarantineRecords
        // is computed AFTER this seam — the substrate's permit
        // synthesis already factors quarantine state into
        // permit.mode at this point per M595)。
        let kunlunAxisProtocolForGate =
            BASTurnAuditProjectionsKunlunAxisProtocol.compute(
                sessionID: derivedSessionID,
                hostID: hostContext.hostID,
                permitMode: boundActionPermit.mode,
                riskLevel: boundRiskCard.riskLevel,
                quarantineRecordsIsEmpty: true,
                humanAnchorRecommendedSurfaceTone:
                    humanAnchorSignalForGate
                        .recommendedSurfaceTone,
                sovereignEscalationHint:
                    abyssalPressureForGate
                        .sovereignEscalationHint,
                primaryCandidateID:
                    thoughtFrame.candidates.first?
                        .candidateID ?? "no-candidate",
                kunlunActiveLayerRefs:
                    Self.kunlunActiveLayerRefs,
                centerlineRules:
                    Self.kunlunCenterlineRules(
                        for: boundActionPermit.mode),
                kunlunAxisDeviationThreshold: Self
                    .kunlunAxisDeviationThreshold)
        let kunlunAxisForGate = kunlunAxisProtocolForGate.axis
        let kunlunAxisAlignmentForGate =
            kunlunAxisProtocolForGate.alignment
        let kunlunEscalation = BASKunlunPermitEscalation
            .escalate(
                permit: boundActionPermit,
                alignment: kunlunAxisAlignmentForGate,
                humanAnchor: humanAnchorSignalForGate)
        boundActionPermit = kunlunEscalation.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M417 fix-pin (chapter 九十七 deep-review H1): capture
        // escalation-decision reason codes for audit emission.
        // When red line #8 fires (humanAnchor.tone == .reserved),
        // both M384 abyssal and M406 kunlun escalations return
        // the original permit unchanged with suppression codes
        // attached to the *decision*, not the permit. Pre-fix
        // these codes were discarded; the audit walker had no
        // way to tell "no axis deviation this turn" apart from
        // "axis deviation suppressed by anchor-reserved." We
        // now harvest both decisions' reason codes and feed them
        // into the audit entry's signalRefs so red line #8
        // honoring is observable.
        let escalationSuppressionCodes: [String] = {
            var codes: [String] = []
            if abyssalEscalation.suppressedByHumanAnchor {
                codes.append(contentsOf:
                    abyssalEscalation.reasonCodes)
            }
            if kunlunEscalation.suppressedByHumanAnchor {
                codes.append(contentsOf:
                    kunlunEscalation.reasonCodes)
            }
            return codes
        }()
        // M448-M450 (chapter 一百十八) — production wires for
        // chapter 一百十七 Cthulhu helpers. Each call composes
        // safely with the M384 / M385 / M406 chain above:
        //
        //  - M448 (was M444 helper): derive watcher-hint
        //    projections from existing turn state. Pure function;
        //    no permit / verdict mutation.
        //  - M449 (was M445 helper): compose fog with M385
        //    BASUnknownReserve via assertion-ceiling cap. Permit
        //    narrowing only.
        //  - M450 (was M446 helper): derive
        //    `BASCosmicColdCounterweight` from risk + abyssal
        //    pressure + human-anchor signals; pass into
        //    `BASCthulhuPermitEscalation.escalate` to compose with
        //    M384 / M406 stackedModes.
        //
        // Doctrine: pure derive; no verdict escalation; single
        // commit mouth preserved (only narrows assertionCeiling
        // and appends to stackedModes).
        // chapter 五百六 / M1402 — abyssal+thermal trio fold。
        // 3 ForAudit declarations + their inline derive calls
        // collapsed into a single typed factory call。 Shadow
        // re-bindings below preserve all downstream reader
        // sites unchanged。 V1 byte-equality preserved by
        // factory's identical compute order。
        let abyssalThermalTrioForAudit =
            BASTurnAuditProjectionsAbyssalThermalTrio
                .compute(
                    routedBudget: routedBudget,
                    turnID: derivedTurnID)
        let abyssalRunModeForAudit =
            abyssalThermalTrioForAudit.abyssalRunMode
        let abyssBudgetForAudit =
            abyssalThermalTrioForAudit.abyssBudget
        // M456 (chapter 一百二十) — L8 memory thermal layer
        // projection from runMode at audit-projection time.
        // Now consumed via the typed trio factory above。
        let memoryTemperatureLayerForAudit =
            abyssalThermalTrioForAudit
                .memoryTemperatureLayer
        // M480-M485 (chapter 一百二十五) — Kunlun production
        // wires for chapter-一百二十二/三 schemas. Each derive
        // is a pure function from existing turn state; never
        // mutates permit / verdict / lifecycle state.
        // chapter 四百七十八 / M1289 — V1 fold PILOT replaces
        // 3 separate `let *ForAudit = ...` declarations with
        // one typed factory call。 Byte-equal by construction
        // (factory dispatches the same 3 derive calls in the
        // same order)。 Shadow re-bindings preserve all
        // downstream reader sites unchanged。 BASStressSweep
        // Harness dual mode (M1290) is the regression guard。
        let kunlunTrioForAudit = BASTurnAuditProjectionsKunlunTrio
            .compute(
                routedBudget: routedBudget,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                turnID: derivedTurnID,
                sessionID: derivedSessionID,
                kunlunAxisID: kunlunAxisForGate.axisID)
        let ascentLeaseForAudit = kunlunTrioForAudit.ascentLease
        let axisDeviationForAudit = kunlunTrioForAudit.axisDeviation
        let gatePressureForAudit = kunlunTrioForAudit.gatePressure
        // chapter 四百八十五 / M1317 — V1 fold cluster A
        // continuation。 6 declarations folded via hexa factory。
        let kunlunHexaForAudit = BASTurnAuditProjectionsKunlunHexa
            .compute(
                runMode: routedBudget.runMode,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                candidates: thoughtFrame.candidates,
                turnID: derivedTurnID)
        let yaochiMemoryLayerForAudit = kunlunHexaForAudit
            .yaochiMemoryLayer
        let tianhengProfileForAudit = kunlunHexaForAudit
            .tianhengProfile
        let jadePermitGradeForAudit = kunlunHexaForAudit
            .jadePermitGrade
        // M486-M490 (chapter 一百二十六) — L9 dream-loop + L3
        // fold-page + L13 refinement production wires. Derive
        // per-candidate ascent + rest + return + refinement
        // schemas; one casket per turn.
        let ascentBranchesForAudit = kunlunHexaForAudit
            .ascentBranches
        let restStepsForAudit = kunlunHexaForAudit.restSteps
        let returnPathsForAudit = kunlunHexaForAudit.returnPaths
        // chapter 四百八十五 / M1318 — V1 fold trio #2
        let kunlunTrioTwoForAudit = BASTurnAuditProjectionsKunlunTrioTwo
            .compute(
                runMode: routedBudget.runMode,
                riskLevel: boundRiskCard.riskLevel,
                candidates: thoughtFrame.candidates,
                organRefMorph:
                    thoughtFrame.organMap?.morph.rawValue
                    ?? "unknown",
                turnID: derivedTurnID,
                sessionID: derivedSessionID)
        let jadeCasketForAudit = kunlunTrioTwoForAudit.jadeCasket
        let jadeRefinementTicketsForAudit = kunlunTrioTwoForAudit
            .jadeRefinementTickets
        // M491-M494 (chapter 一百二十七) — final Kunlun host +
        // integrity production wires.
        let jadeFidelityMapForAudit = kunlunTrioTwoForAudit
            .jadeFidelityMap
        // chapter 四百八十六 / M1320 — V1 cluster A FINAL 6 fold
        let kunlunHexaTwoForAudit =
            BASTurnAuditProjectionsKunlunHexaTwo.compute(
                hostID: hostContext.hostID,
                sessionID: derivedSessionID,
                turnID: derivedTurnID,
                unknownRefs: unknownReserveForGate.unknownRefs,
                assertionCeiling: unknownReserveForGate
                    .assertionCeiling,
                riskLevel: boundRiskCard.riskLevel,
                candidates: thoughtFrame.candidates)
        let hostJadeRegisterForAudit = kunlunHexaTwoForAudit
            .hostJadeRegister
        let jadeMirrorDraftForAudit = kunlunHexaTwoForAudit
            .jadeMirrorDraft
        let kunlunUnnamableSetForAudit = kunlunHexaTwoForAudit
            .kunlunUnnamableSet
        let returnPathRefsForAudit = kunlunHexaTwoForAudit
            .returnPathRefs
        let kunlunAscentViewForAudit = kunlunHexaTwoForAudit
            .kunlunAscentView
        let kunlunFarWestReserveForAudit = kunlunHexaTwoForAudit
            .kunlunFarWestReserve
        // M495-M498 (chapter 一百二十七) — chapter 一百二十一
        // Cthulhu leftover production wires.
        // chapter 四百八十六 / M1322 — V1 cluster B start
        let cthulhuPentaForAudit =
            BASTurnAuditProjectionsCthulhuPenta.compute(
                routedBudget: routedBudget,
                runMode: routedBudget.runMode,
                hostID: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                memoryTemperatureLayer:
                    memoryTemperatureLayerForAudit,
                candidates: thoughtFrame.candidates,
                unknownRefs: unknownReserveForGate.unknownRefs,
                assertionCeilingRaw: unknownReserveForGate
                    .assertionCeiling.rawValue,
                turnID: derivedTurnID)
        let abyssalOrganAliasForAudit = cthulhuPentaForAudit
            .abyssalOrganAlias
        let humanAnchorProfileForAudit = cthulhuPentaForAudit
            .humanAnchorProfile
        let sealedMemoryForAudit = cthulhuPentaForAudit
            .sealedMemory
        let cosmicScaleViewForAudit = cthulhuPentaForAudit
            .cosmicScaleView
        let ontologyFogForAudit = cthulhuPentaForAudit
            .ontologyFog
        // M452 (chapter 一百十九) — derive L9 retention loop from
        // unknown reserve. Closes the chapter 一百十八 nil
        // placeholder for `retentionLoop:` in M449. Returns nil
        // when reserve.assertionCeiling == .unrestricted (no
        // retention needed for wide-open trust).
        let unknownRetentionLoopForGate = BASUnknownRetentionLoop
            .derive(
                from: unknownReserveForGate,
                turnID: derivedTurnID)
        // M449 — fog assertion-ceiling cap (composes with M385).
        // Chapter 一百十九 M454: retention loop now non-nil when
        // unknown reserve is below `.unrestricted` ceiling.
        let cthulhuAssertionDecision = BASCthulhuAssertionCeilingGate
            .cap(
                permit: boundActionPermit,
                ontologyFog: ontologyFogForAudit,
                retentionLoop: unknownRetentionLoopForGate)
        boundActionPermit = cthulhuAssertionDecision.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M450 — derive cosmic-cold counterweight from risk
        // signals + L10 anti-paternalism heuristics; pass into
        // M446 escalation. Counterweight axes:
        //  - dignityBias high when risk is extreme + permit
        //    narrows agency (i.e. mode != .answer)
        //  - agencyFloor high when candidate count is low (≤1)
        //  - antiFatalism high when risk level is high or extreme
        //    (reject "this is just how it is" framing)
        //  - antiPaternalism high when permit narrows below
        //    .answer mode (avoid deciding for the host)
        let counterweightForGate = BASCosmicColdCounterweight(
            counterweightID:
                "cosmic-cold-\(derivedSessionID)",
            dignityBias: Self.dignityBiasFromRisk(
                boundRiskCard.riskLevel,
                permitMode: boundActionPermit.mode),
            agencyFloor: Self.agencyFloorFromCandidates(
                thoughtFrame.candidates.count),
            antiFatalism: Self.antiFatalismFromRisk(
                boundRiskCard.riskLevel),
            antiPaternalism: Self
                .antiPaternalismFromPermit(
                    boundActionPermit.mode))
        // M453 (chapter 一百十九) — derive [BASNonEuclideanCandidate]
        // from low-confidence candidates. Closes the chapter 一百十八
        // empty-array placeholder for `nonEuclideanCandidates:` in
        // M450. Returns empty array when no candidate has
        // confidence below `nonEuclideanConfidenceThreshold`.
        let nonEuclideanCandidatesForGate = BASNonEuclideanCandidate
            .deriveAll(
                from: thoughtFrame.candidates,
                turnID: derivedTurnID)
        let cthulhuEscalation = BASCthulhuPermitEscalation
            .escalate(
                permit: boundActionPermit,
                nonEuclideanCandidates:
                    nonEuclideanCandidatesForGate,
                cosmicColdCounterweight: counterweightForGate)
        boundActionPermit = cthulhuEscalation.permit
        thoughtFrame.actionPermit = boundActionPermit
        // M448 — L7 ontology shift mark requires the post-
        // verdict narrative-distortion projection (later in the
        // turn). For the gate-side path, we capture only the
        // L1/L4 projections derived above; ontology-shift-mark
        // is populated at audit-projection time below where
        // narrativeDistortion is already in scope.
        // M56 — L11 risk climate now surfaces per-dimension
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 bundles
        // on this turn share strictly equal coordinates — the L14
        // audit surface joins them by that key.
        thoughtFrame = thoughtFrame
            .withDerivedRiskObservationBundle(
                frameContext: frameContext)

        let hostGateValue = hostProfileService.applyHostGate(
            profile: hostContext,
            taskType: contextFrame.taskType,
            riskCard: boundRiskCard,
            confidence: triScores.map(\.mergedScore).max() ?? 0
        )

        let (finalOrganMap, neuralDegradedReasonCodes) = applySovereignNeuralContract(
            to: thoughtFrame.organMap ?? baseNeuralCore.organMap,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches,
            inheritedReasonCodes: baseNeuralCore.degradedReasonCodes
        )
        thoughtFrame.organMap = finalOrganMap
        thoughtFrame.toolIntentEnvelope = neuralCoreService?.materializeToolIntent(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        ) ?? BASNeuralMaterializationCompiler.materializeToolIntent(
            thoughtFrame: thoughtFrame,
            mergedChoice: mergedChoice,
            actionPermit: boundActionPermit
        )
        thoughtFrame.neuralLeaseReceipt = buildNeuralLeaseReceipt(
            budgetFrame: routedBudget,
            thoughtFrame: thoughtFrame,
            degradedReasonCodes: neuralDegradedReasonCodes
        )

        let baseRenderedOutput = actionService.render(
            choice: mergedChoice,
            riskCard: boundRiskCard,
            permit: boundActionPermit,
            hostContext: hostContext
        )
        let renderedOutput = self.projectedRenderedOutput(
            from: baseRenderedOutput,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage
        )
        // M57 — L12 gentle hand now surfaces per-subject render
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12
        // bundles on this turn share strictly equal coordinates — the
        // L14 audit surface joins them by that key. Must run AFTER
        // renderedOutput is sealed and BEFORE evolutionService sees
        // the frame, so UpdateTicket derivation can read the bundle.
        thoughtFrame = thoughtFrame
            .withDerivedSoftHandObservationBundle(
                renderedOutput: renderedOutput,
                frameContext: frameContext)
        let rawTickets = evolutionService.buildTickets(
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            feedbackEvent: request.feedbackEvent
        )
        let (normalizedTickets, evolutionFindings) = normalizeUpdateTickets(
            rawTickets,
            riskCard: boundRiskCard,
            activeKillSwitches: request.activeKillSwitches
        )
        let evolutionGovernance = buildEvolutionGovernanceArtifacts(
            request: request,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            output: renderedOutput,
            riskCard: boundRiskCard,
            updateTickets: normalizedTickets
        )
        let updateTickets = evolutionGovernance.updateTickets
        // M58 — L13 evolution surface now emits per-ticket update
        // observations on the main-chain thought frame. Reuses M53's
        // derived (sessionID, turnID) so L6 / L7 / L10 / L11 / L12 /
        // L13 bundles on this turn share strictly equal coordinates —
        // the L14 audit surface joins them by that key. Must run AFTER
        // the governed ticket list is sealed and BEFORE buildThoughtFold
        // / buildRuntimeTrace read the frame, so the bundle propagates
        // into the fold + trace and then onto the sovereign verdict.
        thoughtFrame = thoughtFrame
            .withDerivedUpdateTicketObservationBundle(
                updateTickets: updateTickets,
                frameContext: frameContext)

        // M60 — L1 灯芯层 main-chain wiring. Derive the per-turn
        // kernel observation bundle from `routedBudget` (the single
        // source of truth for run mode / thermal guard / maintenance
        // / device route). Reuses M53's derived (sessionID, turnID)
        // so the L1 bundle joins the L4 / L6 / L7 / L10 / L11 / L12
        // / L13 bundles under the same coordinates — the L14 audit
        // surface reconciles them by that key. Placed here (after
        // the evolution ticket observation so the frame's other
        // fields are all sealed) and BEFORE buildThoughtFold /
        // buildRuntimeTrace, so the bundle propagates into the fold
        // + trace and then onto the sovereign verdict on the same
        // turn.
        thoughtFrame = thoughtFrame
            .withDerivedLeaseLifeObservationBundle(
                budgetFrame: routedBudget,
                frameContext: frameContext)

        // M61 — L5 宿纹层 main-chain wiring. Derive the per-turn
        // host-constitution governance observation bundle from the
        // coordinator's `hostConstitution` / `hostVersionTree` /
        // `hostForgetRequest` fields (the single source of truth for
        // active version / committed tree / frozen IDs / pending
        // candidates / forget request on this turn). Reuses M53's
        // derived (sessionID, turnID) so the L5 bundle joins the L1 /
        // L4 / L6 / L7 / L10 / L11 / L12 / L13 bundles under the same
        // coordinates. Placed after the M60 L1 seam so every other
        // main-chain bundle on the frame is sealed before L5 emits.
        thoughtFrame = thoughtFrame
            .withDerivedHostConstitutionObservationBundle(
                constitution: hostConstitution,
                versionTree: hostVersionTree,
                forgetRequest: hostForgetRequest,
                frameContext: frameContext)

        let auditFindings = budgetFindings + memoryFindings + loopFindings + riskFindings + evolutionFindings
        let killSwitches = recommendedKillSwitches(for: auditFindings)
        let thoughtFold = buildThoughtFold(
            request: request,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            thoughtFrame: thoughtFrame,
            riskCard: boundRiskCard,
            hostGateValue: hostGateValue
        )

        // M62 — L3 思纹层 main-chain wiring. Derive the per-turn
        // fold observation bundle from the freshly built
        // `thoughtFold` (single source of truth for foldID +
        // checksum + ark refs + organ packages + degradation
        // reasons). Reuses M53's derived (sessionID, turnID) so the
        // L3 bundle joins the L1 / L4 / L5 / L6 / L7 / L10 / L11 /
        // L12 / L13 bundles under the same coordinates — the L14
        // audit surface reconciles them by that key. Placed between
        // `buildThoughtFold` and `buildRuntimeTrace` so the updated
        // frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedThoughtFoldObservationBundle(
                fold: thoughtFold,
                frameContext: frameContext)

        // M63 — L8 海马层 main-chain wiring. Derive the per-turn
        // hippocampal memory observation bundle from the normalized
        // `memoryBundle` (single source of truth for retrieved atoms
        // + top-level conflict refs + temporal field subsurfaces
        // like quarantine records and forget cascades). Reuses M53's
        // derived (sessionID, turnID) so the L8 bundle joins the
        // L1 / L3 / L4 / L5 / L6 / L7 / L10 / L11 / L12 / L13
        // bundles under the same coordinates — the L14 audit
        // surface reconciles them by that key. Placed right after
        // the M62 L3 seam and before `buildRuntimeTrace` so the
        // updated frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedHippocampalMemoryObservationBundle(
                memoryBundle: memoryBundle,
                frameContext: frameContext)

        // M64 — L2 神经器官层 main-chain wiring. Derive the per-turn
        // neural-organ-registry observation bundle from the
        // coordinator's finalized `thoughtFrame.organMap` (post
        // early seal + `applySovereignNeuralContract` — the single
        // source of truth for morph / active organs / precision
        // tiers / routing policy / sovereign constraints / head
        // guarantees on this turn). Reuses M53's derived
        // (sessionID, turnID) so the L2 bundle joins the L1 / L3 /
        // L4 / L5 / L6 / L7 / L8 / L10 / L11 / L12 / L13 bundles
        // under the same coordinates — the L14 audit surface
        // reconciles them by that key. Placed right after the M63
        // L8 seam and before `buildRuntimeTrace` so the updated
        // frame propagates into the trace and then onto the
        // sovereign verdict on the same turn.
        thoughtFrame = thoughtFrame
            .withDerivedNeuralOrganObservationBundle(
                frameContext: frameContext)

        let runtimeTrace = buildRuntimeTrace(
            request: request,
            budgetFrame: routedBudget,
            hostContext: hostContext,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            activeKillSwitches: request.activeKillSwitches,
            auditFindings: auditFindings,
            killSwitches: killSwitches
        )
        let wakeIntent = buildWakeIntent(
            request: request,
            budgetFrame: routedBudget
        )
        let runLease = buildRunLease(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            actionPermit: boundActionPermit
        )
        let emergencyBrake = buildEmergencyBrake(
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            activeKillSwitches: request.activeKillSwitches
        )
        let sovereignVerdict = buildSovereignVerdict(
            request: request,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            thoughtFold: thoughtFold,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            emergencyBrake: emergencyBrake,
            updateTickets: updateTickets
        )
        let sovereignCommitTokens = buildSovereignCommitTokens(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold,
            actionPermit: boundActionPermit,
            updateTickets: updateTickets,
            renderedOutput: renderedOutput
        )
        let sovereignWarrants = buildSovereignWarrants(
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let sovereignLock = buildSovereignLock(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace
        )
        let quarantineRecords = buildQuarantineRecords(
            sovereignVerdict: sovereignVerdict,
            runtimeTrace: runtimeTrace,
            thoughtFold: thoughtFold
        )
        // M303 — derive Cthulhu/Abyssal pressure from existing
        // turn state right before the audit-entry build so the
        // projection sees the final risk card + uncertainty
        // ledger + evidence debts that L11 / L9 already settled.
        // Pure projection; no verdict escalation; signalRefs
        // additive only.
        // chapter 四百八十七 / M1325 — V1 cluster B trio fold
        let lateClusterBForAudit =
            BASTurnAuditProjectionsLateClusterB.compute(
                turnID: runtimeTrace.sessionID,
                hostID: hostContext.hostID,
                riskLevel: boundRiskCard.riskLevel,
                permit: boundActionPermit,
                uncertaintyLedger:
                    thoughtFrame.uncertaintyLedger,
                evidenceDebtCount:
                    thoughtFrame.evidenceDebts?.count ?? 0,
                candidateCount:
                    thoughtFrame.candidates.count)
        let abyssalPressureForAudit = lateClusterBForAudit
            .abyssalPressure
        // M304 — derive human-anchor signal from final risk +
        // permit + candidate count. White-paper §5.3 / red line
        // 7: hint, not verdict.
        let humanAnchorSignalForAudit = lateClusterBForAudit
            .humanAnchorSignal
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
        let synthesizedSealsForAudit = lifecycleQuartetForAudit
            .synthesizedSeals
        let sealAggregateForAudit = lifecycleQuartetForAudit
            .sealAggregate
        // M305 — synthesize an L13 lifecycle session per fresh
        // UpdateTicket on this turn. All start at `.proposed`
        // (the typed entry point of the 8-stage state machine);
        // cross-turn promotion / retraction is the L13 actor
        // primitives' job, not this projection. The aggregate
        // is nil for turns that produced zero tickets, so the
        // audit-entry builder elides the lifecycle.* codes.
        let lifecycleSessionsForAudit = lifecycleQuartetForAudit
            .lifecycleSessions
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
        let hostFragilityForAudit = lateClusterCForAudit
            .hostFragility
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
        let forbiddenCandidatesForAudit = lateClusterDForAudit
            .forbiddenCandidates
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
        let kunlunMatched = kunlunAxisProtocolForAudit.matched
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
        let surfaceModeForAudit = surfaceTrioForAudit
            .surfaceMode
        let cthulhuSurfaceAliasForAudit = surfaceTrioForAudit
            .cthulhuSurfaceAlias
        let kunlunSurfaceAliasForAudit = surfaceTrioForAudit
            .kunlunSurfaceAlias
        // M436.4 (chapter 一百七 parameter-bundle refactor) —
        // populate the typed audit-observation bundle once and
        // pass to the bundle-form `buildSovereignAuditEntry`.
        // Pre-M436.4 the call site spelled 24+ named parameters
        // inline (130+ lines of named-arg list); now we name
        // each projection field once on the bundle and pass
        // the bundle as a single `projections:` argument. Each
        // chapter that adds a new audit emission grows the
        // bundle struct rather than the function signature.
        let projections = BASAuditObservationProjections(
            candidateObservationBundle: thoughtArtifacts
                .candidateObservationBundle,
            tribunalObservationBundle: thoughtFrame
                .tribunalObservationBundle,
            // M499 (chapter 一百二十七) — thread the
            // fragility-folded pressure into projections so the
            // audit emission reflects the spec-canonical
            // 7-field aggregate.
            abyssalPressure: abyssalPressureWithFragility,
            humanAnchorSignal: humanAnchorSignalForAudit,
            sealAggregate: sealAggregateForAudit,
            lifecycleAggregate: lifecycleAggregateForAudit,
            narrativeDistortion: narrativeDistortionForAudit,
            anomalyTrace: anomalyTraceForAudit,
            abyssalBranches: abyssalBranchesForAudit,
            unknownReserve: unknownReserveForAudit,
            forbiddenAggregate: forbiddenAggregateForAudit,
            kunlunAxisAlignment: kunlunAxisAlignmentForAudit,
            jadeCanonVerification:
                kunlunJadeVerificationForAudit,
            jadeCanonObjectClass: .actionPermit,
            riverOriginLineage: kunlunRiverLineageForAudit,
            yaochiAccess: kunlunYaochiAccessForAudit,
            yaochiSanctumClass:
                kunlunYaochiSanctumForAudit.sanctumClass,
            tianmenReadiness:
                kunlunHeavenGateReadinessForAudit,
            tianmenGateClass:
                kunlunHeavenGateForAudit.gateClass,
            tianmenPassState:
                kunlunHeavenGateForAudit.passState,
            escalationSuppressionCodes:
                escalationSuppressionCodes,
            kunlunAxisView: kunlunAxisViewForAudit,
            kunlunTianmenWarrant: kunlunTianmenWarrantForAudit,
            kunlunGateDenialWrit:
                kunlunGateDenialWritForAudit,
            layerReconciliationVerdict:
                layerReconciliation.verdict,
            layerReconciliationReport:
                layerReconciliation.report,
            presenceObservationBundle:
                contextFrame.presenceObservationBundle,
            decompositionObservationBundle:
                decomposeFrame.decompositionObservationBundle,
            softHandObservationBundle: thoughtFrame
                .softHandObservationBundle,
            leaseLifeObservationBundle: thoughtFrame
                .leaseLifeObservationBundle,
            hostConstitutionObservationBundle: thoughtFrame
                .hostConstitutionObservationBundle,
            thoughtFoldObservationBundle: thoughtFrame
                .thoughtFoldObservationBundle,
            neuralOrganObservationBundle: thoughtFrame
                .neuralOrganObservationBundle,
            hippocampalMemoryObservationBundle: thoughtFrame
                .hippocampalMemoryObservationBundle,
            worldPriorObservationBundle: thoughtFrame
                .worldPriorObservationBundle,
            riskObservationBundle: thoughtFrame
                .riskObservationBundle,
            updateTicketObservationBundle: thoughtFrame
                .updateTicketObservationBundle,
            // M448-M451 (chapter 一百十八) — chapter 一百十七
            // Cthulhu helper outputs threaded through the audit
            // emission seam.
            cosmicScaleView: cosmicScaleViewForAudit,
            ontologyFog: ontologyFogForAudit,
            ontologyShiftMark: ontologyShiftMarkForAudit,
            abyssalRunMode: abyssalRunModeForAudit,
            abyssBudget: abyssBudgetForAudit,
            cthulhuAssertionCeilingReasonCodes:
                cthulhuAssertionDecision.reasonCodes,
            cthulhuPermitEscalationReasonCodes:
                cthulhuEscalation.reasonCodes,
            memoryTemperatureLayer:
                memoryTemperatureLayerForAudit,
            // M480-M485 (chapter 一百二十五) — Kunlun production
            // wire projections.
            ascentLease: ascentLeaseForAudit,
            axisDeviation: axisDeviationForAudit,
            gatePressure: gatePressureForAudit,
            yaochiMemoryLayer: yaochiMemoryLayerForAudit,
            tianhengProfile: tianhengProfileForAudit,
            jadePermitGrade: jadePermitGradeForAudit,
            ascentBranches: ascentBranchesForAudit,
            restSteps: restStepsForAudit,
            returnPaths: returnPathsForAudit,
            jadeCasket: jadeCasketForAudit,
            jadeRefinementTickets:
                jadeRefinementTicketsForAudit,
            // M491-M494 (chapter 一百二十七) — final Kunlun
            // host + integrity production-wire projections.
            jadeFidelityMap: jadeFidelityMapForAudit,
            hostJadeRegister: hostJadeRegisterForAudit,
            jadeMirrorDraft: jadeMirrorDraftForAudit,
            kunlunUnnamableSet: kunlunUnnamableSetForAudit,
            // M495-M498 (chapter 一百二十七) — chapter 一百
            // 二十一 Cthulhu leftover production-wire
            // projections.
            narrativeDistortionMap:
                narrativeDistortionMapForAudit,
            sealedMemory: sealedMemoryForAudit,
            humanAnchorProfile:
                humanAnchorProfileForAudit,
            abyssalOrganAlias: abyssalOrganAliasForAudit,
            // M500-M501 (chapter 一百二十八) — Kunlun L4
            // chapter-99-deferred wires.
            kunlunAscentView: kunlunAscentViewForAudit,
            kunlunFarWestReserve:
                kunlunFarWestReserveForAudit,
            // M502-M510 (chapter 一百二十八) — L12 doctrine
            // surface aliases.
            cthulhuSurfaceAlias:
                cthulhuSurfaceAliasForAudit,
            kunlunSurfaceAlias:
                kunlunSurfaceAliasForAudit)
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
            budgetFrame: routedBudget,
            runtimeTrace: runtimeTrace,
            emergencyBrake: emergencyBrake
        )
        let sovereignActuationCommands = buildSovereignActuationCommands(
            sovereignVerdict: finalSovereignVerdict,
            runtimeTrace: runtimeTrace,
            budgetFrame: routedBudget,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit
        )
        let sovereignExecutionReceipts = buildSovereignExecutionReceipts(
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
            budgetFrame: routedBudget,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict
        )
        let finalizedBudgetFrame = buildFinalizedBudgetFrame(
            routedBudget,
            wakeIntent: wakeIntent,
            runLease: runLease,
            actionPermit: boundActionPermit
        )

        if let runLease {
            thoughtFrame.organMap?.leaseRef = runLease.leaseID
            thoughtFrame.neuralLeaseReceipt?.leaseID = runLease.leaseID
        }

        return BASEBrainTurnResult(
            deviceState: request.deviceState,
            budgetFrame: finalizedBudgetFrame,
            wakeIntent: wakeIntent,
            vitalState: vitalState,
            runLease: runLease,
            emergencyBrake: emergencyBrake,
            sovereignVerdict: finalSovereignVerdict,
            sovereignCommitTokens: sovereignCommitTokens,
            sovereignWarrants: sovereignWarrants,
            sovereignLock: sovereignLock,
            quarantineRecords: quarantineRecords,
            sovereignAuditEntry: sovereignAuditEntry,
            sovereignActuationCommands: sovereignActuationCommands,
            sovereignExecutionReceipts: sovereignExecutionReceipts,
            policyLineage: policyLineage,
            recoveryDisposition: recoveryDisposition,
            hostConstitution: hostConstitution,
            hostConstitutionVault: hostConstitutionVault,
            hostVersionTree: hostVersionTree,
            hostForgetRequest: hostForgetRequest,
            hostContext: hostContext,
            contextFrame: contextFrame,
            decomposeFrame: decomposeFrame,
            memoryBundle: memoryBundle,
            thoughtFrame: thoughtFrame,
            thoughtFold: thoughtFold,
            triScores: triScores,
            mergedChoice: mergedChoice,
            riskCard: boundRiskCard,
            actionPermit: boundActionPermit,
            riskDecisionPackage: normalizedRiskDecisionPackage,
            hostGateValue: hostGateValue,
            renderedOutput: renderedOutput,
            updateTickets: updateTickets,
            experienceCandidates: evolutionGovernance.experienceCandidates,
            workflowCandidates: evolutionGovernance.workflowCandidates,
            guardTemplateCandidates: evolutionGovernance.guardTemplateCandidates,
            biasRecords: evolutionGovernance.biasRecords,
            riskPatternCandidates: evolutionGovernance.riskPatternCandidates,
            learningExportBundles: evolutionGovernance.learningExportBundles,
            shadowTrialRecords: evolutionGovernance.shadowTrialRecords,
            versionDeltas: evolutionGovernance.versionDeltas,
            retractionOrders: evolutionGovernance.retractionOrders,
            evolutionSeals: evolutionGovernance.evolutionSeals,
            runtimeTrace: finalizedRuntimeTrace,
            // M578 (chapter 一百五十三 — 一次性解决掉) — populate
            // 4 typed projection fields directly on turn result so
            // bench/observability code can read REAL substrate
            // outputs instead of synthesizing from public fields.
            kunlunAxisAlignment: projections.kunlunAxisAlignment,
            humanAnchorSignal: projections.humanAnchorSignal,
            abyssalPressure: projections.abyssalPressure,
            unknownReserve: projections.unknownReserve,
            // M581 (chapter 一百五十六 — 解决缺陷 #15-#17) — wire 3
            // additional REAL substrate-emitted schema types (locals
            // built earlier in this function at lines 267 / 335 /
            // 1901 — `kunlunYaochiSanctumForAudit` /
            // `kunlunHeavenGateForAudit` / `kunlunRiverTraceForAudit`)
            // so doctrine bench can use them directly instead of
            // synthesizing from `(permitMode, stake, tone)`. Closes
            // bench saturation: gateFidelity 1.0 / sanctumLeak 0.0 /
            // originCompleteness 1.0 → real substrate variation.
            kunlunHeavenGatePermit: kunlunHeavenGateForAudit,
            kunlunRiverOriginTrace: kunlunRiverTraceForAudit,
            yaochiSanctumEntry: kunlunYaochiSanctumForAudit
        )
    }

    /// M275 — async wrapper that runs a turn AND auto-flows
    /// every emitted ticket into the supplied lifecycle
    /// coordinator. Equivalent to:
    ///
    /// ```swift
    /// let turn = coord.runTurn(request)
    /// await lifecycleCoord.ingestTurnResult(turn)
    /// return turn
    /// ```
    ///
    /// Hosts that already had a lifecycle coordinator wired
    /// previously had to call those two lines manually after
    /// every turn. This wrapper makes that the one-line
    /// pattern. Pass-through behavior matches `runTurn(_:)`
    /// exactly when `lifecycleCoordinator` is nil — no auto-
    /// flow happens. Backward-compatible: existing callers
    /// keep using `runTurn(_:)` unchanged.
    ///
    /// - Parameters:
    ///   - request: same shape as `runTurn(_:)`
    ///   - lifecycleCoordinator: optional. When non-nil, every
    ///     ticket from the result auto-submits via
    ///     `BASUpdateTicketLifecycleCoordinator
    ///       .ingestTurnResult(_:)` (M267).
    public func runTurnAndIngest(
        _ request: BASEBrainTurnRequest,
        lifecycleCoordinator:
            BASUpdateTicketLifecycleCoordinator?
    ) async -> BASEBrainTurnResult {
        let turn = runTurn(request)
        if let coord = lifecycleCoordinator {
            _ = await coord.ingestTurnResult(turn)
        }
        return turn
    }

}
