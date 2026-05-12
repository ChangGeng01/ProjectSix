// MARK: - BASCognitiveOSCompletionDoctrine — chapter 三百八四 / M872
//
// ADR-016: codifies the cognitive OS substrate completion state
// after the M859-M870 12-commit run。Replaces the floating audit
// notes in commit messages with a typed,grep-able doctrine
// surface that downstream code can pin against。
//
// ## Why this exists
//
// Pre-M872 the "what's done vs what's external" answer lived in
// commit-message text + scattered TODO comments。Hosts wanting
// to know whether G6 tool calling is ready couldn't query a
// typed surface — they had to grep commits or read M858 audit
// notes。M872 ships the typed enum so the answer is one
// `BASCognitiveOSGap.allCases.first { $0.status == .external }`
// query away。
//
// ## What this ships
//
//   - `BASCognitiveOSGap` typed enum naming each G1-G13 roadmap
//     gap from chapter 三百五三 / M840
//   - `BASCognitiveOSGapStatus` typed enum (.substrateClosed /
//     .substrateClosedSDKBridgePending / .external)
//   - `BASCognitiveOSCompletionDoctrine` namespace with typed
//     queries (`status(of:)`, `closedGaps()`, `externalGaps()`)
//
// ## Doctrine pins held
//
// - 不变量 #1 / #2 / #3 全保 — doctrine is observation only
// - chapter 二百一一 single-source-of-truth — ONE typed surface
//   for completion state;commit messages defer to this file
// - chapter 一百八十五 anti-magic-number — every gap has a typed
//   case + named status,no inline strings in consumer code
// - ADR-014 OPT-IN — doctrine names the contract;hosts that
//   don't query stay unaffected
// - ADR-016 (this file) — substrate completion is now
//   programmatically queryable

import Foundation

// MARK: - Status

/// Typed status of a cognitive OS gap per the M840 roadmap +
/// M858 audit + M859-M870 closure run。
public enum BASCognitiveOSGapStatus:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    /// Substrate work fully closed at this commit。Hosts can
    /// opt in to the primitives via the bundle / builder /
    /// convenience helpers shipped under M859+。
    case substrateClosed = "substrate-closed"

    /// Substrate work fully closed,but the iOS 26 SDK bridge
    /// (e.g. FoundationModels Tool conformer) hasn't been wired
    /// at the API call site yet。M870 emits a typed audit signal
    /// (`afm-tools-dropped-no-sdk-bridge`) so this state is
    /// LOUD,not silent。
    case substrateClosedSDKBridgePending =
        "substrate-closed-sdk-bridge-pending"

    /// Genuinely external — cannot be done at substrate level。
    /// Examples:Python training pipelines,physical device
    /// validation,external toolchain conversions。
    case external = "external"

    /// Chapter 四百 / M917+M918:external work,but typed
    /// substrate-side contract exists (input schema +
    /// validator + typed result type)。The external work
    /// (Python training pipeline / coreml conversion CLI)
    /// honors the typed contract rather than guessing the
    /// substrate's expected I/O shape。Reduces drift between
    /// external + substrate without the substrate doing the
    /// external work itself。
    case externalSubstrateContractTyped =
        "external-substrate-contract-typed"

    /// Environmental (toolchain / Xcode-version) issue。Not
    /// fixable at the substrate level — depends on toolchain
    /// updates。
    case environmental = "environmental"
}

// MARK: - Gap

/// Typed enum naming each cognitive OS gap from M840 P1-P3
/// roadmap。Extensible via String raw value (chapter 八十七
/// raw value stability — bumping requires audit migration)。
public enum BASCognitiveOSGap:
    String, Sendable, Equatable, Hashable, CaseIterable, Codable
{
    // MARK: - P1 (foundation)

    /// G1 — event-sourced event log + SQLite persistence
    case g1EventLog = "g1-event-log"

    /// G2 — BASUserState reducer + store + SQLite persistence
    case g2UserState = "g2-user-state"

    /// G3 — constitution gate (hardNoGo + softCaution +
    /// restrictedDomains)
    case g3ConstitutionGate = "g3-constitution-gate"

    /// G4 — vector RAG end-to-end (in-memory + SQLite preload)
    case g4VectorRAG = "g4-vector-rag"

    /// G5 — layer actor factories (L2/L3/L5 M848 + L9/L10/L13
    /// /L14 M855 + L7 M870)
    case g5LayerFactories = "g5-layer-factories"

    /// G6 — AFM typed tool calling primitives + outputSchema +
    /// constitution gate
    case g6AFMToolCalling = "g6-afm-tool-calling"

    /// G7 — active verifier permit upgrade (decision logic +
    /// composer)
    case g7ActiveVerifier = "g7-active-verifier"

    // MARK: - P2 (intelligence)

    /// G8 — Mamba SSM integration (training pipeline external)
    case g8MambaSSM = "g8-mamba-ssm"

    /// G9 — knowledge graph + cycle detection + extractor
    /// (heuristics 1-7) + SQLite persistence
    case g9KnowledgeGraph = "g9-knowledge-graph"

    /// G10 — cognitive OS layer actors (L9/L10/L13/L14 M855)
    case g10LayerActors = "g10-layer-actors"

    /// G11 — MLX → CoreML conversion pipeline
    case g11MLXCoreML = "g11-mlx-coreml"

    // MARK: - P3 (eval)

    /// G12 — auto eval harness (typed primitives + SQLite
    /// storage + orchestration actor + regression detection)
    case g12AutoEval = "g12-auto-eval"

    /// G13 — Mamba-2/3 frontier research (P3 deferred)
    case g13MambaFrontier = "g13-mamba-frontier"
}

// MARK: - Completion doctrine

/// ADR-016 typed query namespace。Single source of truth for
/// cognitive OS completion state per chapter 三百八四 / M872。
public enum BASCognitiveOSCompletionDoctrine {

    /// Doctrine version。Bumped when a gap changes status (eg.
    /// G6 transitions from `substrateClosedSDKBridgePending`
    /// to `substrateClosed` once the SDK bridge ships)。
    /// M918 bump:G8 + G11 transitioned from `external` to
    /// `externalSubstrateContractTyped` (substrate-side typed
    /// contracts shipped — `BASMambaTrainingCorpusSchema` +
    /// `BASCoreMLConversionContract`)。G6 gained an explicit
    /// strategy taxonomy via `BASFoundationModelsToolBridge`
    /// (M916) but stays at `substrateClosedSDKBridgePending`
    /// until the iOS 26 SDK Tool conformer bridge stabilizes。
    /// M940 bump:LLM Extraction Engine MVP shipped
    /// (M928-M939) — 12 typed primitives covering the full
    /// 6-module orchestration plus 4 vision-deferred items
    /// (model routing / prompt cache / anti-complexity judge
    /// / training-corpus sublimator)。M940 deep-review fixes
    /// hardened 7 HIGH issues (NaN guards, event-ID
    /// collision, verifier approved-from-stages,
    /// datumID disambiguator, deterministic dict iteration,
    /// role/preset parametrization)。No G-status change —
    /// engine is host-orchestration-class, slots into
    /// existing `BASNeuralCoreServicing` via M933 typed
    /// parallel protocol。
    /// M952 bump:Phase 1 of next-next-gen architecture sweep
    /// (chapter 四百二) shipped — memory event-sourced unification
    /// (M941-M952)。Folds BASMemoryAtom storage into BASEventLog
    /// as the canonical source-of-truth via typed payload +
    /// pure-function reducer + event-sourced atom store conformer
    /// + mutation event emitter + knowledge graph memory-event
    /// extension + storage wire builder integration + coordinator
    /// optional fields。Closes the 双 source-of-truth gap surfaced
    /// by the 3-Explore-agent architecture audit。No G-status
    /// change — Phase 1 is substrate-side machinery,not a roadmap
    /// gap closure。Phase 2 (chapter 四百三) + Phase 3 (chapter 四百四)
    /// follow per `wild-rolling-meerkat.md` plan。
    /// M988 bump:Phase 2 entropy chapter 四百五 v1 close-out
    /// — BUNDLE PROTOCOL COMPREHENSIVE milestone。 chapter
    /// 四百三 (M953-M962, 10 commits) + chapter 四百四 v1+v2+v3+v4
    /// (M963-M980, 18 commits) + chapter 四百五 v1
    /// (M981-M988, 8 commits)。 chapter 四百五 v1 ships
    /// `BASBundleIDProtocol` typed superset + 19 concrete
    /// bundle adoptions across BASBundleProtocol +
    /// BASBundleIDProtocol surfaces (combined with M964
    /// BASMemoryBundle = 20/20 COMPREHENSIVE) + chapter v1
    /// close-out doctrine。 Cross-bundle protocol queries
    /// (count by bundleID,aggregate by recordedAt,filter
    /// by schemaVersion) now work uniformly across ALL 20
    /// concrete bundle types via typed existentials。 Future
    /// v2+ ships V2 actor stage rewrites + permit fold
    /// function + V1↔V2 stress sweep + parallel DAG。
    /// ADR-014 OPT-IN held throughout;V1 runTurn byte-
    /// equality preserved (4780+ BAS tests pass)。No
    /// G-status change。
    /// M992 bump:Phase 2 entropy chapter 四百六 v1 close-out
    /// — V2 LIFECYCLE COMPREHENSIVE milestone。 Chapter 四百六
    /// v1 (M989-M992,4 commits) ships:V2 actor adopts the
    /// 5-slot audit projections aggregator + emits paired
    /// .start + .complete envelopes per turn + audit
    /// projections slot count flows into .complete payload。
    /// V2 actor's audit channel comprehensive。 Future v2+
    /// ships native V2 stage rewrites + permit fold function
    /// + V1↔V2 stress sweep + parallel DAG。 ADR-014 OPT-IN
    /// held;V1 byte-equality preserved (4800+ BAS tests
    /// pass)。No G-status change。
    /// M997 bump:Phase 2 entropy chapter 四百六 v2 close-out
    /// — V2 PARAM COMPREHENSIVE milestone。 V2 actor's runTurn
    /// signature now accepts auditProjections + permit
    /// escalation ledger + timestamp override params with
    /// typed factory chain collapsing emission boilerplate
    /// 24→6 lines。 ADR-014 OPT-IN held;V1 byte-equality
    /// preserved (4825+ BAS tests pass)。No G-status change。
    /// M999 bump:Phase 2 entropy chapter 四百七 entry。 V2
    /// actor's 4-arg init collapses to 1-arg via the typed
    /// `BASTurnRuntimeEngineConfiguration` bundle (M998)。
    /// Chapter 四百七 OPEN at M998-M999。 ADR-014 OPT-IN held;
    /// V1 byte-equality preserved。No G-status change。
    /// M1001 bump:Phase 2 entropy chapter 四百七 v1 close-out
    /// — V2 ACTOR FOUR FOUNDATIONS milestone。 V2 actor's
    /// scaffolding now complete across 4 typed foundations:
    /// configuration bundle (M998) + stage taxonomy (M1000)
    /// + permit ledger (M966) + audit projections aggregator
    /// (M976/M979)。 Future v2+ ships native V2 stage rewrites
    /// + permit fold function + V1↔V2 stress sweep + parallel
    /// DAG adoption (chapter 四百八+)。 ADR-014 OPT-IN held;
    /// V1 byte-equality preserved (4850+ BAS tests pass)。No
    /// G-status change。
    /// M1005 bump:Phase 2 entropy chapter 四百八 v1 close-out
    /// — V2 STAGE EXECUTION FOUNDATION milestone。 V2 actor
    /// now has FIVE typed scaffolding foundations:
    /// configuration (M998) + stage taxonomy (M1000) + stage
    /// execution record+ledger (M1002+M1003) + permit ledger
    /// (M966) + audit projections aggregator (M976/M979)。
    /// Future v2+ ships native V2 stage rewrites consuming
    /// the foundations。 ADR-014 OPT-IN held;V1 byte-equality
    /// preserved (4870+ BAS tests pass)。No G-status change。
    /// M1009 bump:Phase 2 entropy chapter 四百九 v1 close-out
    /// — V2 STAGE PLAN FOUNDATION milestone。 V2 actor now
    /// has SIX typed scaffolding foundations:configuration
    /// (M998) + stage taxonomy (M1000) + stage execution
    /// record+ledger (M1002+M1003) + permit ledger (M966) +
    /// audit projections aggregator (M976/M979) + stage plan
    /// + validation (M1006+M1007)。 V2 actor's runTurn signature
    /// now accepts 5 typed optional scaffolding params。
    /// Future v2+ ships native V2 stage rewrites consuming
    /// all 6 typed foundations。 ADR-014 OPT-IN held;V1
    /// byte-equality preserved (4900+ BAS tests pass)。No
    /// G-status change。
    /// M1013 bump:Phase 2 entropy chapter 四百十 v1 close-out
    /// — V2 PERMIT FOLD INPUT FOUNDATION milestone。 Permit-
    /// fold scaffolding now has SEVEN typed primitives:M966
    /// stage enum + M966 stage record + M966 ledger + M970
    /// positional builder + M1010 step-result pair + M1010
    /// tuple builder + M1011 canonical stage order + M1012
    /// step-results bundle。 Future v2+ ships the actual fold
    /// function consuming the 7 primitives。 ADR-014 OPT-IN
    /// held;V1 byte-equality preserved (4920+ BAS tests pass)。
    /// No G-status change。
    /// M1017 bump:Phase 2 entropy chapter 四百十一 v1 close-out
    /// — V2 STRESS SWEEP INPUT FOUNDATION milestone。 Stress-
    /// sweep scaffolding now has THREE typed primitives:
    /// M1014 dimension enum + M1015 risk-bucket enum + M1016
    /// fixture-cell key (6-slot cartesian-product identifier
    /// + .label)。 Future v2+ ships the stress-sweep harness
    /// consuming the 3 primitives。 ADR-014 OPT-IN held;V1
    /// byte-equality preserved (4960+ BAS tests pass)。No
    /// G-status change。
    /// M1021 bump:Phase 2 entropy chapter 四百十二 v1 close-
    /// out — V2 STRESS SWEEP PLAN FOUNDATION milestone。
    /// Stress-sweep scaffolding now has SIX typed primitives:
    /// M1014 dimension + M1015 risk-bucket + M1016 fixture-
    /// cell + M1018 fixture-set + M1019 canonical sets
    /// (.smoke10/.canonical60) + M1020 filtering helpers
    /// (6 filters)。 Future v2+ ships the harness function
    /// consuming a fixture set + producing per-fixture V1↔V2
    /// byte-equality verdict。 ADR-014 OPT-IN held;V1 byte-
    /// equality preserved (4990+ BAS tests pass)。No G-status
    /// change。
    /// M1025 bump:Phase 2 entropy chapter 四百十三 v1 close-
    /// out — V2 STRESS SWEEP VERDICT FOUNDATION milestone。
    /// Stress-sweep scaffolding now has NINE typed primitives
    /// (3 input + 3 plan + 3 verdict):M1014 dimension +
    /// M1015 risk-bucket + M1016 fixture-cell + M1018 fixture-
    /// set + M1019 canonical sets + M1020 filtering helpers
    /// + M1022 verdict enum + M1023 fixture result pair +
    /// M1024 sweep report aggregate。 Future v2+ ships the
    /// async harness function consuming the 9 primitives。
    /// ADR-014 OPT-IN held;V1 byte-equality preserved (5020+
    /// BAS tests pass)。No G-status change。
    /// M1029 bump:Phase 2 entropy chapter 四百十四 v1 close-
    /// out — V2 PARALLEL DISPATCH FOUNDATION milestone。
    /// Parallel-dispatch scaffolding now has THREE typed
    /// primitives:M1026 cardinality + member-stage list per
    /// group + M1027 BASParallelStageAssembleOrder generic +
    /// M1028 inverse fromCanonicalOrder factory。 Critical
    /// chapter 三百九二 byte-stability anchor for native V2
    /// async-let parallel fan-outs (entryAA2 / dD2 / m1FourWay
    /// / o12Way)。 ADR-014 OPT-IN held;V1 byte-equality
    /// preserved (5050+ BAS tests pass)。No G-status change。
    /// M1033 bump:Phase 2 entropy chapter 四百十五 v1 close-
    /// out — V2 PARALLEL DISPATCH SUMMARY FOUNDATION
    /// milestone。 Parallel-dispatch summary scaffolding now
    /// has THREE typed primitives:M1030 summary value type
    /// + M1031 from-records factory + M1032 ledger extension
    /// returning all 4 group summaries。 Future V2 actor
    /// stages plug summary derivation into the .complete
    /// envelope payload via these primitives。 ADR-014 OPT-IN
    /// held;V1 byte-equality preserved (5090+ BAS tests pass)。
    /// No G-status change。
    /// M1037 bump:Phase 2 entropy chapter 四百十六 v1 close-
    /// out — V2 PARALLEL SUMMARY ENVELOPE INTEGRATION
    /// milestone。 V2 actor's .complete envelope payload now
    /// natively threads parallel dispatch summaries via the
    /// M1034 typed slot,M1035 aggregate accessors,and M1036
    /// per-group ledger accessors。 Audit consumers grep
    /// dashboard fan-out wall-clock dominance + cost
    /// accounting per group。 ADR-014 OPT-IN held;V1 byte-
    /// equality preserved (5110+ BAS tests pass)。No G-status
    /// change。
    /// M1041 bump:Phase 2 entropy chapter 四百十七 v1 close-
    /// out — V2 STAGE LEDGER VALIDATION FOUNDATION
    /// milestone。 Stage-ledger validation now has THREE
    /// typed primitives:M1038 validation surface (3 issue
    /// cases) + M1039 completeness aggregates (isComplete
    /// + missingStages + averageStageDurationMs) + M1040
    /// envelope payload surfaces stageLedgerIsComplete。
    /// Mirrors M1007 stage-plan validation pattern。 ADR-014
    /// OPT-IN held;V1 byte-equality preserved (5140+ BAS
    /// tests pass)。No G-status change。
    /// M1045 bump:Phase 2 entropy chapter 四百十八 v1 close-
    /// out — V2 PLAN-LEDGER COHERENCE FOUNDATION milestone。
    /// Drift-detection scaffolding now has THREE typed
    /// primitives:M1042 coherence-issue enum + M1043 typed
    /// pair (plan+ledger) with .coherenceIssues() + M1044
    /// canonical factory。 Future native V2 stages + V1↔V2
    /// stress harnesses detect plan↔ledger drift via these。
    /// ADR-014 OPT-IN held;V1 byte-equality preserved
    /// (5170+ BAS tests pass)。No G-status change。
    /// M1049 bump:Phase 2 entropy chapter 四百十九 v1 close-
    /// out — V2 COHERENCE ENVELOPE INTEGRATION milestone。
    /// Plan-ledger coherence now flows through the V2 actor's
    /// audit envelope payload via 3 typed surfaces:M1046
    /// typed Int slot (planLedgerCoherenceIssueCount) +
    /// M1047 derived Bool (planLedgerIsCoherent) + M1048
    /// coherence-pair accessors (coherenceIssueCount /
    /// firstIssue)。 Audit consumers grep these to surface
    /// drift on dashboards。 ADR-014 OPT-IN held;V1 byte-
    /// equality preserved (5200+ BAS tests pass)。No G-status
    /// change。
    /// M1053 bump:Phase 2 entropy chapter 四百二十 v1 close-
    /// out — V2 SUMMARY DIGEST FOUNDATION milestone。 Summary
    /// -digest scaffolding now has THREE typed primitives:
    /// M1050 typed digest value (algo + digest + producedAt)
    /// + M1051 SHA256 from-summary factory + M1052 content-
    /// equality .matches(_:) ignoring producedAt。 Future
    /// V1↔V2 stress harnesses verify summary byte-equality
    /// via these primitives。 ADR-014 OPT-IN held;V1 byte-
    /// equality preserved (5220+ BAS tests pass)。No G-status
    /// change。
    /// M1057 bump:Phase 2 entropy chapter 四百二十一 v1 close-
    /// out — V2 PHASE 2 CLOSE-OUT milestone。 Phase 2 entropy
    /// work (chapters 四百三-四百二十一,105 commits across
    /// M953-M1057) closes here。 Substrate-side typed
    /// scaffolding COMPLETE:M1054 BASV2FoundationsRegistry
    /// (12 V2 foundations) + M1055 BASPhase2EntropyClosure
    /// Doctrine + M1056 BASADR018PendingDoctrine (4 deferred
    /// production items)。 Production-side wiring (real actor
    /// services for parallel dispatch / stress sweep / permit
    /// fold / native stage rewrites) tracked under separate
    /// ADR-018-pending roadmap。 ADR-014 OPT-IN held;V1
    /// byte-equality preserved (5250+ BAS tests pass)。No
    /// G-status change。
    /// M1061 bump:Phase 2 entropy chapter 四百二十二 v1 close-
    /// out — V2 SUBSTRATE INTEGRITY milestone。 Strengthens
    /// cross-cutting invariants:M1058 backfill chapter 四百三
    /// schema + completeness invariant test (3 new tests +
    /// 19 chapter round-trips) + M1059 full-payload integration
    /// test (7 new tests / 16 envelope fields / 5-rerun SHA256
    /// stability) + M1060 V2 actor signature freeze test
    /// (4 new tests catching surface drift at PR-time)。
    /// ADR-014 OPT-IN held;V1 byte-equality preserved
    /// (5285+ BAS tests pass)。No G-status change。
    /// M1065 bump:Phase 2 entropy chapter 四百二十三 v1 close-
    /// out — V2 ROADMAP + OPS CONVENIENCE milestone。
    /// Strengthens dev-facing convenience:M1062
    /// BASRoadmapDoctrine typed aggregate over Phase 1 +
    /// Phase 2 + ADR-018 (13 new tests) + M1063 BASV2Foundation
    /// CustomStringConvertible + humanName accessor (7 new
    /// tests) + M1064 BASRuntimeAuditEmissionSummary
    /// .compactDigest() one-line log accessor (6 new tests)。
    /// ADR-014 OPT-IN held;V1 byte-equality preserved
    /// (5310+ BAS tests pass)。No G-status change。
    /// M1069 bump:Phase 2 entropy chapter 四百二十四 v1 close-
    /// out — V2 DOCTRINE-CHAIN CONSISTENCY milestone。
    /// Syncs the substrate's 4+ doctrine surfaces:M1066
    /// Phase 2 doctrine extension (chapter count 19→21,
    /// commits 105→113) + M1067 schema-completeness invariant
    /// extended to all 21 chapters + M1068 cross-cutting
    /// doctrine-chain consistency invariant (7 new tests
    /// catching version/phase/chapter/roadmap/registry/ADR
    /// drift at PR-time)。 ADR-014 OPT-IN held;V1 byte-
    /// equality preserved (5330+ BAS tests pass)。No G-status
    /// change。
    /// M1073 bump:Phase 2 entropy chapter 四百二十五 v1 close-
    /// out — V2 REAL EXECUTOR FOUNDATION milestone。 FIRST
    /// chapter to ship REAL working production logic (not
    /// just typed scaffolding):M1070 BASPermitEscalation
    /// FoldExecutor (REAL 5-step async fold) + M1072
    /// BASParallelStageDispatchExecutor (REAL async let
    /// 2-way + 4-way fan-out)。 ADR-018 PARTIAL RATIFICATION:
    /// permitEscalationFold + parallelDispatchDriver both
    /// flipped from .pending to .shipped。 2 of 4 ADR-018
    /// items now done。 ADR-014 OPT-IN held;V1 byte-equality
    /// preserved (5340+ BAS tests pass)。No G-status change。
    /// M1077 bump:Phase 2 entropy chapter 四百二十六 v1 close-
    /// out — V2 ADR-018 FULL RATIFICATION milestone。 Ships
    /// REAL working stress sweep harness (M1074
    /// BASStressSweepHarness) + REAL working native stage
    /// executor (M1075 BASNativeStageExecutor)。 ALL 4
    /// ADR-018 items now SHIPPED;BASRoadmapDoctrine flips
    /// ADR-018 phase to .shipped;overall progress 66% →
    /// 100%。 ADR-014 OPT-IN held;V1 byte-equality preserved
    /// (5375+ BAS tests pass)。No G-status change。
    /// M1083 bump:RADICAL EVOLUTION SWEEP chapter 四百二十七
    /// v1 close-out — V2 RUNTIME COMPOSITION SURFACE
    /// milestone。 Ships M1080 BASRuntimeInternalDelegate
    /// (4 REAL executors composed) + M1081 BASTurnRuntimeMode
    /// typed enum (V1↔V2 mode switch) + M1082 BASTurnRuntime
    /// Engine.runWithPlan() composition (FIRST function
    /// wiring all 4 REAL executors end-to-end)。 V2 actor's
    /// 6 typed scaffolding params previously dead-on-arrival
    /// are now ACTIVATED。 ADR-014 OPT-IN held;V1 byte-equality
    /// preserved (5398+ BAS tests pass)。No G-status change。
    /// M1099 bump:RADICAL EVOLUTION SWEEP chapter 四百三十一
    /// v1 close-out — NATIVE APPLE SILICON FOUNDATION
    /// milestone。 Ships BASMetalSubstrate as the FIRST
    /// substrate module to link Metal / MPS / MPSGraph /
    /// Accelerate / CoreML at link-time + ship typed tensor
    /// primitives (BASTensor / BASTensorShape /
    /// BASTensorDescriptor) + ANE introspection
    /// (BASANECapability / BASNeuralOp /
    /// BASANECapabilityProbe actor) + unified kernel registry
    /// (BASMetalKernelRegistry actor + BASMetalKernel
    /// protocol) + 3 reference CPU kernels (BASMatMulKernel /
    /// BASRMSNormKernel / BASRotaryEmbeddingKernel)。 ADR-014
    /// OPT-IN held — no V1 hot path consumes BASMetalSubstrate
    /// yet;Phase F scheduler will be the first consumer。 V1
    /// byte-equality preserved (5,400+ BAS tests pass)。 No
    /// G-status change。
    /// M1103 bump:RADICAL EVOLUTION SWEEP chapter 四百三十二
    /// v1 close-out — HARDWARE-AWARE SCHEDULER COMPOSITION
    /// milestone。 First chapter where the V2 runtime engine
    /// CONSUMES the Phase E BASMetalSubstrate primitives:
    /// (1) BASTurnRuntimeEngineConfiguration grows 3 new
    /// optional slots (runtimeMode + metalKernelRegistry +
    /// aneCapability),(2) BASTurnRuntimeEngine wires them
    /// into actor storage + per-call dispatch probe captures
    /// the consumption,(3) BASHardwareAwareScheduler actor +
    /// BASStageAcceleratorHint + BASStageAcceleratorAssignment
    /// envelopes ship as the first scheduler primitive
    /// reading M1097 capability + M1098 registry。 ADR-014
    /// OPT-IN held — default config keeps engine in
    /// .v1ByteEqual + nil registry + nil capability
    /// (byte-equal output)。 V1 byte-equality preserved
    /// (5,500+ BAS tests pass)。 No default-mode flip — that
    /// needs CI dual-mode evidence first。 No G-status change。
    /// M1107 bump:RADICAL EVOLUTION SWEEP final close-out
    /// at chapter 四百三十三。 Ships
    /// BASStagePlanAcceleratorHints sidecar (stage-keyed
    /// dictionary mapping each BASTurnRuntimeStage to a
    /// BASStageAcceleratorHint without modifying
    /// BASTurnRuntimeStagePlan) + BASRadicalEvolutionSweep
    /// ClosureDoctrine (single typed cumulative surface for
    /// the entire 6-phase sweep arc:phaseA/B/C/D/E/F + 11
    /// deferred destructive operations explicitly enumerated)。
    /// Sweep total:28 commits across 7 chapters (4 phase +
    /// 3 backfill chapters + this final close-out)。 ADR-014
    /// OPT-IN preserved at every commit boundary。 V1
    /// byte-equality preserved (5,700+ BAS tests pass)。 No
    /// G-status change。
    /// M1109 bump:RADICAL EVOLUTION SWEEP deep-review
    /// remediation round 2。 Chapter 四百三十三 self-extends
    /// to cover M1108 (round 1 — fixed chapter 428's stale
    /// ADR-016 knife text + extended index from 5 → 7
    /// chapters) + M1109 (round 2 — fixed 7 stale
    /// '5,4XX+/5,5XX+ tests pass' claims to '5,700+',
    /// fixed '22 chapter doctrines' deletion claim to '31',
    /// brought M1108-M1109 inside the chapter doctrine
    /// system instead of letting them hover outside)。
    /// Sweep total:30 commits across 7 chapters (chapter
    /// 433 now has 6 cuts instead of 4)。 ADR-014 OPT-IN
    /// preserved at every commit boundary。 V1 byte-equality
    /// preserved (5,706+ BAS tests pass)。 No G-status
    /// change。 Loop closed (完全 闭环)。
    /// M1115 bump:POST-RADICAL EVOLUTION SWEEP chapter
    /// 四百三十四 — SAFETY SUBSTRATE + CANONICAL60 DRIVER。
    /// 6 cuts (M1110-M1115):
    /// (1) external consumer audit + Qinao SDK reality
    ///     reflected in BASModuleConsolidationPolicy
    ///     (chatCompletionsAdapter + mlxAdapter flipped
    ///     to .blocked with explicit blockedReason),
    /// (2) BASEntropyChapterIndex.phase2Entries —
    ///     complete 31-entry mirror covering all Phase 2
    ///     chapters (24 pre-RADICAL + 7 RADICAL),
    /// (3) BASStressSweepCanonical60Driver — typed
    ///     60-fixture set + identity/divergence stub
    ///     runners — harness now exercisable end-to-end,
    /// (4-6) chapter close-out + Phase 2 + ADR-016 bumps。
    /// No destructive ops。 V1 byte-equality preserved
    /// (5,710+ BAS tests pass)。 No G-status change。
    /// M1119 bump:POST-RADICAL EVOLUTION SWEEP Wave 6
    /// — chapter 四百三十五 ships FIRST PRODUCTION
    /// SCHEDULER CONSUMPTION。 4 cuts (M1116-M1119):
    /// (1) BASTurnRuntimeEngineConfiguration.stagePlanHints
    ///     optional slot,
    /// (2) BASTurnRuntimeEngine wires hints + lazy
    ///     scheduler + lastAssignmentLedger;runWithPlan
    ///     calls scheduler.assign(...) per stage step,
    /// (3) BASTurnRuntimePlanAssignmentLedger typed
    ///     evidence surface,
    /// (4) chapter close-out + Phase 2 + ADR-016 bumps。
    /// First chapter where the substrate genuinely
    /// CONSULTS the scheduler in production runtime path
    /// (was a typed primitive without caller pre-M1116)。
    /// V1 byte-equality preserved (5,720+ BAS tests pass)。
    /// No G-status change。
    /// M1123 bump:POST-RADICAL EVOLUTION SWEEP Wave 7
    /// — chapter 四百三十六 ships FIRST LEDGER-DRIVEN
    /// DISPATCH。 4 cuts (M1120-M1123):
    /// (1) BASNativeStageDispatchLedger typed evidence
    ///     (records + 4 typed aggregates),
    /// (2) BASNativeStageExecutor.executePlanWith
    ///     Assignments(...) + RoutedStageExecutor
    ///     closure — scheduler decisions actually
    ///     drive stage routing,
    /// (3) 11 tests proving end-to-end ledger
    ///     consumption,
    /// (4) chapter close-out + Phase 2 + ADR-016 bumps。
    /// First chapter where 'scheduler decided X →
    /// executor honored X' is a verifiable end-to-end
    /// invariant。 V1 byte-equality preserved (5,770+
    /// BAS tests pass)。 No G-status change。
    /// M1127 bump:POST-RADICAL EVOLUTION SWEEP Wave 8
    /// — chapter 四百三十七 ships END-TO-END ROUTED
    /// DISPATCH。 4 cuts (M1124-M1127):
    /// (1) recon delegate + executor topology,
    /// (2) BASRuntimeInternalDelegate.runScaffoldedWith
    ///     Assignments(...) bridges executor's routed
    ///     path through delegate boundary,
    /// (3) BASTurnRuntimeEngine.runWithPlan(...) branches
    ///     on lastAssignmentLedger — non-empty → routed
    ///     path → captures dispatch ledger,
    /// (4) chapter close-out + Phase 2 + ADR-016 bumps。
    /// First chapter where a single runWithPlan(...) call
    /// produces TWO typed ledgers (assignments +
    /// dispatch) proving end-to-end:scheduler decided
    /// X → executor honored X for stage Y。 V1 byte-
    /// equality preserved (5,790+ BAS tests pass)。 No
    /// G-status change。
    /// M1131 bump:POST-RADICAL EVOLUTION SWEEP Wave 9
    /// — chapter 四百三十八 ships HOST-SIDE INJECTION。
    /// 4 cuts (M1128-M1131):
    /// (1) BASTurnRuntimeEngineConfiguration 2 new
    ///     optional slots (routedStageExecutor +
    ///     fallbackStageExecutor),
    /// (2) BASTurnRuntimeEngine threading,
    /// (3) 7 host-injection tests,
    /// (4) chapter close-out + Phase 2 + ADR-016 bumps。
    /// First chapter where Qinao SDK can wire mlxArray →
    /// BASMLXAdapter dispatch via a single config slot。
    /// Substrate-side end-to-end is now COMPLETE;
    /// remaining "更硬核" gap is purely host-side。 V1
    /// byte-equality preserved (5,800+ BAS tests pass)。
    /// No G-status change。
    /// M1135 bump:POST-RADICAL EVOLUTION SWEEP Wave 10
    /// — chapter 四百三十九 ships DISPATCH ↔ EVENT LOG
    /// BRIDGE。 4 cuts (M1132-M1135):
    /// (1) BASEventPayloadKind 5th case + typed
    ///     BASNativeStageDispatchEventPayload struct,
    /// (2) BASEventLogEntry factory + reverse accessor
    ///     + BASEventLogProjectors projector,
    /// (3) 13 tests proving end-to-end round-trip,
    /// (4) chapter close-out + bumps。
    /// First chapter where the substrate has ZERO
    /// blackbox actor state for runtime decisions —
    /// every choice surfaces through 5 typed event-log
    /// payload kinds (memoryAtom + turnLifecycle +
    /// parallelStage + permitEscalation +
    /// nativeStageDispatch)。 V1 byte-equality
    /// preserved (5,830+ BAS tests pass)。 No G-status
    /// change。
    /// M1139 bump:POST-RADICAL EVOLUTION SWEEP Wave 11
    /// — chapter 四百四十 ships DISPATCH AUTO-EMIT。 4
    /// cuts (M1136-M1139):
    /// (1) recon BASEventLogStorage.append signature,
    /// (2) BASTurnRuntimeEngine wiring +
    ///     emitNativeStageDispatchEventIfNeeded helper +
    ///     lastEmittedDispatchEventID tracking field,
    /// (3) 5 compile-pin + guard-logic tests,
    /// (4) chapter close-out + bumps。
    /// First chapter where substrate-side autonomy is
    /// COMPLETE — hosts only need to wire the event
    /// log,everything else flows through automatically。
    /// V1 byte-equality preserved (5,850+ BAS tests
    /// pass)。 No G-status change。
    /// M1143 bump:POST-RADICAL EVOLUTION SWEEP Wave 12
    /// — chapter 四百四十一 ships PLAN-ASSIGNMENT EVENT
    /// TYPE。 4 cuts (M1140-M1143):
    /// (1) BASTurnRuntimePlanAssignmentEventPayload typed
    ///     Codable payload + 7-field record mirror +
    ///     .from(ledger:) factory + BASEventLogEntry
    ///     factory + reverse accessor + projector + 6th
    ///     BASEventPayloadKind case (planAssignment),
    /// (2) BASTurnRuntimeEngine wiring +
    ///     emitPlanAssignmentEventIfNeeded helper +
    ///     lastEmittedPlanAssignmentEventID tracking
    ///     field + accessor,
    /// (3) 16 pin tests (12 payload + 4 engine accessor),
    /// (4) chapter close-out + bumps。
    /// First chapter where substrate-side replay surface
    /// is COMPLETE — 6 typed payload kinds carry the FULL
    /// routed-dispatch story (capture → honor) through
    /// ONE canonical event log。 V1 byte-equality
    /// preserved (5,900+ BAS tests pass)。 No G-status
    /// change。
    /// M1147 bump:POST-RADICAL EVOLUTION SWEEP Wave 13
    /// — chapter 四百四十二 ships REPLAY-REBUILD
    /// INTEGRATION。 4 cuts (M1144-M1147):
    /// (1) recon BASEventLogStorage + BASInMemoryEventLog
    ///     Storage + 6 payload-kind factories,
    /// (2) BASEventLogReplayBundle typed Sendable +
    ///     Equatable + Hashable struct aggregating all 6
    ///     projector outputs + totalEventCount +
    ///     perKindEventCount + .empty + NEW
    ///     BASEventLogProjectors.projectAllPayloadKinds(_:)
    ///     pure factory,
    /// (3) 13 round-trip integration tests
    ///     (BASEventLogReplayBundleIntegrationTests),
    /// (4) chapter close-out + bumps。
    /// First chapter where 6-kind event-log replay surface
    /// is PROVEN end-to-end through real BASInMemoryEvent
    /// LogStorage round-trip + a typed bundle replay
    /// consumers consume as a single source-of-truth。
    /// V1 byte-equality preserved (5,920+ BAS tests
    /// pass)。 No G-status change。
    /// M1151 bump:POST-RADICAL EVOLUTION SWEEP Wave 14
    /// — chapter 四百四十三 ships CROSS-SESSION REPLAY
    /// ASSEMBLY。 4 cuts (M1148-M1151):
    /// (1) recon BASEventLogStorage cross-session API
    ///     + design merge semantics,
    /// (2) BASEventLogReplayBundle.merging(_:) instance
    ///     method + .combining(_:) static factory + NEW
    ///     BASEventLogProjectors.projectAcrossAllSessions(
    ///     from:sinceTimestampMs:limit:) async factory
    ///     pulling events globally-time-ordered from
    ///     storage,
    /// (3) 14 cross-session integration tests
    ///     (BASEventLogCrossSessionReplayTests),
    /// (4) chapter close-out + bumps。
    /// First chapter where the 6-kind replay surface
    /// offers a complete typed API for distributed
    /// consumers (G8 SSM training,causal graph
    /// extraction,distributed audit) — pulling events
    /// across all sessions directly from storage +
    /// composing bundles deterministically。 V1 byte-
    /// equality preserved (5,930+ BAS tests pass)。 No
    /// G-status change。
    /// M1155 bump:POST-RADICAL EVOLUTION SWEEP Wave 15
    /// — chapter 四百四十四 ships PER-STAGE EVENT
    /// PAYLOAD。 4 cuts (M1152-M1155):
    /// (1) recon shape + design,
    /// (2) BASNativeStagePerStepEventPayload typed
    ///     Codable + factory + projector + 7th
    ///     BASEventPayloadKind case + EXTENDED
    ///     BASEventLogReplayBundle to 7 fields,
    /// (3) 12 pin tests
    ///     (BASNativeStagePerStepEventPayloadTests),
    /// (4) chapter close-out + bumps。
    /// First chapter where unified event log carries
    /// 7 typed payload kinds with a sibling per-stage
    /// granularity option for fine-grained causal-graph
    /// extraction。 Engine does NOT auto-emit per-step
    /// events (5-10x volume) — hosts opt-in directly。
    /// V1 byte-equality preserved (5,940+ BAS tests
    /// pass)。 No G-status change。
    /// M1159 bump:POST-RADICAL EVOLUTION SWEEP Wave 16
    /// — chapter 四百四十五 ships FEDERATED EVENT LOG
    /// MULTI-BACKEND。 4 cuts (M1156-M1159):
    /// (1) recon shape + design,
    /// (2) BASFederatedEventLogStorage actor +
    ///     BASFederatedEventLogStorageError typed error
    ///     conforming to BASEventLogStorage protocol,
    /// (3) 15 integration tests
    ///     (BASFederatedEventLogStorageTests),
    /// (4) chapter close-out + bumps。
    /// First chapter where typed federation over N
    /// storage backends ships as a drop-in
    /// BASEventLogStorage conformer — chapter 443
    /// projectAcrossAllSessions(from:) accepts it
    /// without parallel API。 V1 byte-equality
    /// preserved (5,960+ BAS tests pass)。 No G-status
    /// change。
    /// M1163 bump:POST-RADICAL EVOLUTION SWEEP Wave 17
    /// — chapter 四百四十六 ships POST-RADICAL EVOLUTION
    /// SWEEP CLOSE-OUT meta-doctrine。 4 cuts (M1160-
    /// M1163):
    /// (1) recon cumulative chapter range + commits,
    /// (2) BASPostRadicalSweepDoctrine typed namespace
    ///     summarizing 8 substrate-side achievements
    ///     + 5 explicitly deferred items + 10 doctrine
    ///     pins held throughout + range/wave/commit
    ///     metrics,
    /// (3) 9 pin tests
    ///     (BASPostRadicalSweepDoctrineTests),
    /// (4) chapter close-out + bumps。
    /// Anchor for future chapter narratives — chapter
    /// 447+ cites BASPostRadicalSweepDoctrine instead
    /// of re-deriving from 13+ chapter doctrine files。
    /// Closes the entire POST-RADICAL EVOLUTION SWEEP
    /// (Waves 1-17,chapters 427-446,M1080-M1163,84
    /// commits)。 V1 byte-equality preserved (5,970+
    /// BAS tests pass)。 No G-status change。
    /// M1167 bump:POST-SWEEP REAL EXECUTION FOLLOW-
    /// THROUGH chapter 1 — chapter 四百四十七 ships
    /// FIRST REAL GPU KERNEL EXECUTION。 Triggered by
    /// 2026-05-11 user audit revealing the SWEEP
    /// shipped scaffolding + audit + 0 real ANE
    /// leverage。 4 cuts (M1164-M1167):
    /// (1) audit recon (0 MPSGraph calls + 3 CPU-stub
    ///     "Metal kernels"),
    /// (2) BASMPSGraphMatMulKernel actor wrapping
    ///     MTLDevice + MPSMatrixMultiplication with
    ///     real CPU→MTLBuffer→GPU→MTLBuffer→CPU dispatch,
    /// (3) 4 PROOF tests verifying byte-equal output +
    ///     non-square shapes + GPU/CPU agreement,
    /// (4) chapter close-out + bumps。 SWEEP doctrine
    ///     STAYS frozen at chapter 446;chapter 447
    ///     opens post-sweep real-execution narrative。
    /// First time in substrate history that input bytes
    /// actually flow through Apple Silicon GPU and
    /// return byte-equal output。 「原生利用神经引擎」
    /// directive moves from 0% → has-first-truthful-
    /// endpoint。 V1 byte-equality preserved。 No
    /// G-status change。
    /// M1171 bump:POST-SWEEP REAL EXECUTION chapter 2
    /// — chapter 四百四十八 ships SECOND real GPU kernel
    /// (rmsNorm via MPSGraph,first MPSGraph usage in
    /// substrate)。 4 cuts:(1) recon + design,(2)
    /// BASMPSGraphRMSNormKernel actor with 6-op graph,
    /// (3) 4 PROOF tests (1e-4 absolute tolerance for
    /// sqrt-amplified FMA reordering),(4) chapter
    /// close-out。 「原生利用神经引擎」 progress 1/3 → 2/3
    /// GPU kernels。 V1 byte-equality preserved。 No
    /// G-status change。
    /// M1175 bump:POST-SWEEP REAL EXECUTION chapter 3
    /// — chapter 四百四十九 ships THIRD real GPU kernel
    /// (rotaryEmbedding via MPSGraph)。 「原生利用神经引
    /// 擎」 progress 2/3 → 3/3 GPU kernel triad complete。
    /// M1179 bump:POST-SWEEP BIOMIMETIC chapter 1 —
    /// chapter 四百五十 ships substrate's FIRST stateful
    /// + selective-gated primitive BASMambaSSMState
    /// (recurrent hidden state across calls + input-
    /// dependent Δ/B/C selective gating)。 「不够仿生」
    /// critique 0/10 → 4/10。 V1 byte-equality preserved。
    /// No G-status change。
    /// M1183 bump:POST-SWEEP BIOMIMETIC chapter 2 —
    /// chapter 四百五十一 ships GPU acceleration for
    /// BASMambaSSMState via runtime-compiled custom
    /// Metal compute shader。 First custom Metal shader
    /// in substrate;CPU + GPU paths share the SAME
    /// actor-isolated hidden state。 「不够仿生」 4/10
    /// → 5/10。 V1 byte-equality preserved。
    /// M1187 bump:POST-SWEEP BIOMIMETIC chapter 3 —
    /// chapter 四百五十二 ships BASPredictiveCodingProbe,
    /// substrate's FIRST closed-loop adaptive primitive。
    /// Canonical predictive-coding update μ ← μ + α·ε;
    /// running MSE as adaptation signal。 Closes-loop
    /// proof:50 obs of constant signal → prediction
    /// converges;distribution shift → error spike +
    /// recalibration。 「不够灵活」 ~15% → ~35%。 V1
    /// byte-equality preserved。 No G-status change。
    /// M1191 bump:POST-SWEEP REAL EXECUTION chapter
    /// — chapter 四百五十三 adds 4th transformer kernel
    /// (attention via MPSGraph) — substrate now has
    /// every primitive a modern attention block needs。
    /// 「原生利用神经引擎」 3/3 → 4/4。
    /// M1195 bump:POST-SWEEP BIOMIMETIC chapter 4 —
    /// chapter 四百五十四 ships BASPlasticityFold,
    /// substrate's FIRST learning primitive (3-rule
    /// enum:Hebbian + antiHebbian + outcomeModulated
    /// Hebbian)。 testHebbianLearnsAssociation proves
    /// substrate learns from repeated (pre,post)
    /// pairs。 「不够灵活」 ~35% → ~50%。 Substrate now
    /// has BOTH closed-loop adaptation (chapter 452)
    /// AND substrate-level learning (chapter 454)。 V1
    /// byte-equality preserved。 No G-status change。
    /// M1199 bump:POST-SWEEP BIOMIMETIC chapter 5 —
    /// chapter 四百五十五 ships BASBiomimeticState
    /// Snapshot,cross-turn / cross-session persistence
    /// for ALL 3 biomimetic primitives (Mamba SSM +
    /// predictive-coding probe + plasticity fold)。
    /// Codable snapshot bundles + in-actor export/
    /// import methods + 20 PROOF tests including 3
    /// CHECKPOINT-RESTORE-EVOLUTION-PARITY proofs that
    /// restored state's subsequent trajectory byte-
    /// equals a never-corrupted reference actor's
    /// trajectory。 「不够仿生」 5/10 → 6/10 (substrate
    /// now REMEMBERS adaptive state across host
    /// restarts — biology survives sleep,substrate
    /// survives process termination)。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1203 bump:POST-SWEEP BIOMIMETIC chapter 6 —
    /// chapter 四百五十六 ships BASBiomimeticTurn
    /// Observer,substrate's FIRST cross-primitive
    /// orchestrator bundling the 3 biomimetic
    /// primitives + chapter 455 snapshot value-type
    /// behind ONE actor + ONE typed observe(_:) entry。
    /// 15 PROOF tests including OBSERVER-LEVEL
    /// CHECKPOINT-RESTORE-EVOLUTION-PARITY (byte-equal
    /// trajectory after corruption + restore at
    /// orchestrator level)。 Aggregate snapshot import
    /// has TWO boundary clamps:unpopulated-slot
    /// silently ignored,populated-primitive-with-nil-
    /// snapshot-slot left untouched。 「不够灵活」
    /// ~50% → ~58% (hosts integrate biomimetic state
    /// with one actor injection instead of three)。
    /// V1 byte-equality preserved。 No G-status change。
    /// M1207 bump:POST-SWEEP BIOMIMETIC chapter 7 —
    /// chapter 四百五十七 ships canonical Spike-Timing-
    /// Dependent Plasticity (STDP) as 4th rule case
    /// under the same BASPlasticityFold actor。
    /// BASPlasticitySTDPParams typed (A_+,A_-,τ_+,
    /// τ_-) bundle with Bi & Poo 1998 defaults +
    /// chapter 一百八十五 clamps + Codable backward-
    /// compat (legacy snapshots default to canonical
    /// params)。 amplitude(Δt) follows asymmetric
    /// exponential window:LTP for Δt > 0,LTD for
    /// Δt < 0,zero at Δt = 0。 16 PROOF tests verify
    /// LTP / LTD / exponential decay / asymmetric A
    /// + τ bias / non-STDP-rule-ignore-timingDelta /
    /// observer routing / Codable backward-compat。
    /// Substrate now learns CAUSAL ORDERING (timing-
    /// dependent),not just correlations (rate-based)。
    /// 「不够仿生」 6/10 → 7/10。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1211 bump:POST-SWEEP BIOMIMETIC chapter 8 —
    /// chapter 四百五十八 ships GPU-accelerated
    /// plasticity update via runtime-compiled Metal
    /// compute kernel。 Lazy Metal pipeline mirroring
    /// chapter 451 Mamba GPU pattern;each (i,j) thread
    /// owns one weight cell (no atomic contention);
    /// scale CPU-side so all 4 rules share kernel。 9
    /// PROOF tests verify GPU/CPU agreement byte-equal
    /// within 1e-5 across all 4 rules + cross-path
    /// mixing (CPU/GPU/CPU on same fold yields 3× Δ
    /// proving shared hidden weight state)。 Plasticity
    /// was the LAST CPU-only compute-heavy primitive;
    /// chapter 458 closes the GPU gap。 「原生利用神经引擎」
    /// 4/4 → 5/5。 V1 byte-equality preserved。 No
    /// G-status change。
    /// M1215 bump:POST-SWEEP BIOMIMETIC chapter 9 —
    /// chapter 四百五十九 ships BASHierarchicalPredictive
    /// Coding,substrate's FIRST multi-level adaptive
    /// primitive。 N-layer stack where each layer
    /// predicts the layer below + propagates only the
    /// prediction error upward (canonical Rao &
    /// Ballard 1999 / Friston free-energy
    /// architecture)。 Equal-dim invariant keeps
    /// cascade simple;custom Codable init enforces
    /// invariant on DECODE。 Aggregate snapshot bundle
    /// covers entire stack。 12 PROOF tests verify
    /// cascade propagation,convergence,snapshot
    /// round-trip,Codable invariant enforcement on
    /// malformed JSON。 Top-layer error = irreducible
    /// surprise signal。 「不够仿生」 7/10 → 8/10
    /// (substrate now mirrors cortical hierarchies)。
    /// V1 byte-equality preserved。 No G-status change。
    /// M1219 bump:DEBT REPAYMENT chapter 1 — chapter
    /// 四百六十 ships BASMetalBenchmarkHarness with
    /// REAL µs measurements。 Closes benchmark debt
    /// surfaced by chapter 459 self-audit。 Real
    /// measurements caught a NUANCE the fictional
    /// chapter 458 doctrine numbers hid:GPU is
    /// SLOWER than CPU at tiny shapes (32×32 → 0.66x)
    /// due to kernel-launch overhead;dominates at
    /// production-relevant shapes (256×256 → 33.9x;
    /// 1024×1024 → 138.0x)。 Chapter 458 doctrine
    /// UPDATED to remove fictional numbers + cite
    /// harness。 V1 byte-equality preserved。
    /// M1223 bump:DEBT REPAYMENT chapter 2 — chapter
    /// 四百六十一 ships first REAL wire from
    /// BASTurnRuntimeEngine to BASBiomimeticTurn
    /// Observer via two new optional configuration
    /// slots (biomimeticTurnObserver +
    /// biomimeticTurnSignalBuilder) defaulting to nil
    /// for ADR-014 OPT-IN + 7-LOC hook block at end
    /// of runWithPlan firing observer with try?
    /// swallow (红线 7 observation-not-commitment)。
    /// Closes integration debt — chapters 456+
    /// orchestration code is no longer dead-on-
    /// arrival。 「Substrate not integrated into turn
    /// loop」 0% → ~70%。 V1 byte-equality preserved。
    /// No G-status change。
    /// M1227 bump:DEBT REPAYMENT chapter 3 — chapter
    /// 四百六十二 closes the LAST 30% of chapter 461
    /// integration debt。 NEW BASCoordinatorTestStubs
    /// .swift factory wires all 10 service protocols
    /// + returns ready-to-use BASEBrainRuntime
    /// Coordinator。 3 new end-to-end PROOF tests in
    /// BASTurnRuntimeEngineBiomimeticHookTests verify
    /// the chapter 461 hook fires per REAL turn through
    /// engine.runWithPlan + real coordinator + delegate
    /// dispatch + lifecycle emits。 Integration debt
    /// 70% → 100%。 All 3 debts from chapter 459 self-
    /// audit now CLOSED (SampleHost iOS build +
    /// benchmark fictional numbers + substrate
    /// integration)。 V1 byte-equality preserved
    /// through end-to-end test。 No G-status change。
    /// M1231 bump:STRUCTURAL DEBT REPAYMENT chapter 1
    /// — chapter 四百六十三 ships Phase 1 of doctrine
    /// collapse (the structural debt called out in
    /// chapter 462 self-audit:60+ per-chapter Swift
    /// files × ~200 LOC of prose,Phase D of original
    /// radical plan never executed)。 NEW
    /// BASChapterDoctrineRecord typed value-type +
    /// BASChapterDoctrineRegistry with 10 entries for
    /// chapters 453-462 derived from existing per-
    /// chapter Swift sources。 14 PROOF tests verify
    /// registry byte-mirrors sources + Codable round-
    /// trip + lookup APIs。 Phase 2 (chapter 464+)
    /// writes new chapters as direct registry entries。
    /// Phase 3 (chapter 465+) deletes the 60+
    /// historical Swift files。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1235 bump:STRUCTURAL DEBT REPAYMENT chapter 2
    /// — chapter 四百六十四 ships Phase 2 of doctrine
    /// collapse:the FIRST chapter doctrine that lives
    /// ONLY in BASChapterDoctrineRegistry,no per-
    /// chapter Swift file。 The chapter PROVES the
    /// Phase 2 pattern by BEING its first instance。
    /// 10 PROOF tests verify schema parity with Swift-
    /// file chapters + M-range contiguity with chapter
    /// 463 + Codable round-trip of literal record +
    /// Phase 2 covenant (every chapter past 453 has
    /// a registry entry)。 Per-chapter LOC delta:
    /// ~+50 literal vs ~+200 Swift file (4× reduction)。
    /// Phase 3 still pending。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1239 bump:STRUCTURAL DEBT REPAYMENT chapter 3
    /// — chapter 四百六十五 ships Phase 2b proof-of-
    /// pattern for doctrine-collapse literal
    /// conversion。 Course-corrects from original plan
    /// (chapter 465 = Phase 3 destructive `git rm`) to
    /// auto-mode-safe scope:literal conversion of 1
    /// chapter (453) in BASChapterDoctrineRegistry+
    /// Literals.swift + 6 PROOF tests pinning literal-
    /// vs-derivation byte-equality。 Phase 3 destruction
    /// (60+ file `git rm` + bulk literal conversion)
    /// requires explicit user confirmation and is
    /// queued for chapter 466+。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1243 bump:STRUCTURAL DEBT REPAYMENT chapter 4
    /// — chapter 四百六十六 ships Phase 3 of doctrine
    /// collapse with explicit user OK on a separate
    /// phase-3-doctrine-collapse branch。 Auto-extracted
    /// 61 chapter literals via Python script + swapped
    /// BASChapterDoctrineRegistry.all to consume
    /// literals + replaced 61 historical Swift doctrine
    /// files with thin ~50-LOC forwarders that read
    /// FROM the registry (dependency direction
    /// inverted)。 Net LOC delta:~10K LOC doctrine →
    /// ~3.9K LOC literals + ~3K LOC forwarders =
    /// ~−3K LOC repayment。 All 6178+ existing tests
    /// continue passing (forwarders preserve API)。
    /// V1 byte-equality preserved。 No G-status change。
    /// M1247 bump:POST-PHASE-3 FEATURE chapter 1 —
    /// chapter 四百六十七 ships auto-checkpoint
    /// integration tying together chapter 455
    /// snapshot value-type + chapter 456 observer +
    /// chapter 461 engine hook + unified event log。
    /// 8th BASEventPayloadKind case added
    /// (.biomimeticCheckpoint)。 New typed payload
    /// BASBiomimeticCheckpointEventPayload + factory +
    /// reverse accessor。 BASTurnRuntimeEngine
    /// Configuration gains biomimeticCheckpointEveryN
    /// Turns slot;engine hook extends to emit
    /// checkpoint events every N turns when all 3
    /// prerequisites wired。 12 PROOF tests include
    /// end-to-end emission cadence verification via
    /// stub coordinator。 ADR-014 OPT-IN preserved
    /// (default nil cadence = no emission)。 V1 byte-
    /// equality preserved。 No G-status change。
    /// M1251 bump:POST-PHASE-3 FEATURE chapter 2 —
    /// chapter 四百六十八 ships BASBiomimeticCheckpoint
    /// Replay namespace closing the cross-session
    /// biomimetic-state recovery loop。 3 helper
    /// methods (latestCheckpoint,restoreObserver,
    /// checkpointCount) reduce 6-step manual replay
    /// plumbing to 1-call surface。 9 PROOF tests
    /// including bedrock END-TO-END loop closure:
    /// engine emits checkpoints → fresh observer on
    /// new session calls restoreObserver(...) →
    /// state byte-matches emitter at checkpoint time。
    /// V1 byte-equality preserved。 No G-status change。
    /// M1267 bump:POST-PHASE-3 FEATURES 3-6 —
    /// chapters 469 (BCM meta-plasticity) + 470
    /// (hierarchical observer slot) + 471 (Mamba
    /// benchmark expansion) + 472 (bundle projection
    /// completion) all shipped in one batch on
    /// phase-3-doctrine-collapse branch。 All chapter-
    /// 468 plannedFutureCuts now closed。 V1 byte-
    /// equality preserved。 No G-status change。
    /// M1271 bump:POST-PHASE-3 self-audit cleanup —
    /// chapter 四百七十三 addresses all 8 findings
    /// from the chapter 466 deep review with PROOF
    /// tests backing each fix:circular byte-mirror
    /// retired in favor of frozen-SHA256 anti-drift;
    /// BCM wired into observer as 5th slot (closes
    /// dead-on-arrival);e2e hierarchical + BCM
    /// through real engine;chapter 472 backward-compat
    /// decoder PROOF;production-scale Mamba benchmark
    /// (25.85x at B=2 D=64 N=16 L=128);Python scripts
    /// committed for reproducibility;chapter 466 prose
    /// honestly revised (REPLACED not DELETED;~−3.5K
    /// LOC not ~−12K)。 V1 byte-equality preserved。 No
    /// G-status change。
    /// M1275 bump:REAL HOT-PATH ATTACK phase 1 —
    /// chapter 四百七十四 substantively closes 3 of
    /// the 6 chapter-473 deep-review directives that
    /// scored ≤4/10:1) BASANELiveReader factory
    /// closes "原生利用神经引擎 1/10" (live MLCompute
    /// device binding behind opt-in factory + thermal
    /// derating);2) BASKernelRegistryDispatchExecutor
    /// factory closes "更硬核 4/10" (registry dispatch
    /// wired with 5 typed outcomes);3) end-to-end
    /// integration PROOF of the full hint→scheduler→
    /// assignment→executor→registry→kernel chain。
    /// ADR-014 OPT-IN preserved。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1279 bump:REAL HOT-PATH ATTACK phase 2 —
    /// chapter 四百七十五 closes the EchoKernel
    /// placeholder gap from M1274 with substantive
    /// PROOF。 1) BASCanonicalKernelInputBuilders
    /// typed factory for matMul/rmsNorm/rotaryEmbedding
    /// inputs;2) FIRST test in the substrate where an
    /// MPSGraph kernel runs with real inputs and produces
    /// numerically correct output (2×2 + 2×3×4 +
    /// identity);3) full chain end-to-end PROOF with
    /// REAL BASMPSGraphMatMulKernel (no more EchoKernel
    /// stub)。 ADR-014 OPT-IN preserved。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1283 bump:REAL HOT-PATH ATTACK phase 3 —
    /// chapter 四百七十六 extends kernel numerical-
    /// correctness coverage to RMSNorm (M1280) +
    /// RotaryEmbedding (M1282) so 3 of 4 MPSGraph
    /// kernels now have PROOF。 ALSO ships M1281
    /// BASKernelDispatchOutcomeBundle — the FIRST real
    /// BASBundle<Item> typealias migration in the
    /// substrate (closes part of the chapter 473
    /// '低熵复杂系统 1/10' gap with substantive evidence,
    /// not scaffolding)。 ADR-014 OPT-IN preserved。 V1
    /// byte-equality preserved。 No G-status change。
    /// M1287 bump:REAL HOT-PATH ATTACK phase 4 final
    /// session close-out — chapter 四百七十七 ships:
    /// (1) M1284 attention kernel numerical PROOF closes
    /// 4-of-4 MPSGraph coverage;(2) M1285
    /// BASRealHotPathAttackEvaluationDoctrine — honest
    /// 6-directive re-scoring (baseline 11/60 → current
    /// 28/60 = +17 points);(3) M1286
    /// BASMPSGraphKernelCoverageBundle — second
    /// BASBundle<Item> migration proves pattern scales;
    /// (4) M1287 close-out。 4-chapter REAL HOT-PATH
    /// ATTACK arc sealed (chapters 474-477 / 16 commits)。
    /// ADR-014 OPT-IN preserved。 V1 byte-equality
    /// preserved。 No G-status change。
    /// M1291 bump:REAL HOT-PATH ATTACK to 100% Phase A
    /// — chapter 四百七十八 ships V1 fold PILOT。 (1)
    /// M1288 BASTurnAuditProjectionsKunlunTrio typed
    /// factory + 6 PROOF tests;(2) M1289 coordinator
    /// splice replaces 3 ForAudit declarations at lines
    /// 1240-1255 with factory call + shadow re-bindings;
    /// (3) M1290 BASTurnRuntimeFullSummaryStressSweep
    /// Runner closes chapter 434 deferral + ships
    /// canonical60 end-to-end harness with 300-turn-run
    /// 0-divergence PROOF。 (4) M1291 close-out。 First
    /// mechanical V1 fold lands。 ADR-014 OPT-IN
    /// preserved。 V1 byte-equality preserved (full
    /// suite still green)。 No G-status change。
    /// M1295 bump:Phase B missing MPSGraph kernels —
    /// chapter 四百七十九 brings BASNeuralOp coverage
    /// from 4-of-8 to 7-of-8 (87.5%)。 3 new GPU kernels:
    /// (1) M1292 BASMPSGraphSoftmaxKernel via
    /// graph.softMax(with:axis:) + 5 PROOF tests;
    /// (2) M1293 BASMPSGraphLayerNormKernel composing
    /// mean-centering + variance + rsqrt + scale + shift
    /// + 5 PROOF tests;(3) M1294 BASMPSGraphConv2DKernel
    /// with NHWC + HWIO + valid padding + 4 PROOF tests。
    /// (4) M1295 close-out。 Only ssmScan deferred to
    /// Tier 2 chapter 496。 ADR-014 OPT-IN preserved。 V1
    /// byte-equality preserved。 No G-status change。
    /// M1299 bump:Phase C — chapter 四百八十 ships ANE
    /// default flip + MPSGraph cache scaffolding。 (1)
    /// M1296 BASANECapabilityProbe defaults to
    /// BASANELiveReader.live() on iOS 17+/macOS 14+
    /// (zero production-caller break);(2) M1297
    /// BASMPSGraphExecutableCache observation actor +
    /// 3rd real BASBundle<Item> typealias migration;
    /// (3) M1298 dispatch latency benchmark measures
    /// 45× same-shape vs distinct-shape gap proving
    /// cache opportunity;(4) M1299 close-out。 Per-
    /// kernel cache wiring deferred。 ADR-014 OPT-IN
    /// preserved (conservativeReader() factory for
    /// explicit opt-out)。 V1 byte-equality preserved。
    /// No G-status change。
    public static let doctrineVersion: String = "ADR-016.M1748"

    /// Query the typed status of a specific gap。
    public static func status(
        of gap: BASCognitiveOSGap
    ) -> BASCognitiveOSGapStatus {
        switch gap {
        // P1 foundation — all closed at substrate level
        case .g1EventLog,
             .g2UserState,
             .g3ConstitutionGate,
             .g4VectorRAG,
             .g5LayerFactories,
             .g7ActiveVerifier:
            return .substrateClosed

        // G6 typed primitives shipped (M851/M852/M853);AFM
        // SDK Tool conformer bridge pending iOS 26 stabilization。
        // M870 makes the gap LOUD via audit suffix。
        case .g6AFMToolCalling:
            return .substrateClosedSDKBridgePending

        // P2 intelligence
        case .g9KnowledgeGraph,
             .g10LayerActors:
            return .substrateClosed

        case .g8MambaSSM:
            // M917:typed substrate-side input contract
            // shipped (BASMambaTrainingCorpusSchema +
            // BASMambaTrainingValidator)。Python training
            // pipeline + GPU + corpus still external,but now
            // honors the typed contract instead of guessing
            // the substrate's I/O shape。
            return .externalSubstrateContractTyped

        case .g11MLXCoreML:
            // M918:typed substrate-side conversion contract
            // shipped (BASCoreMLConversionContract +
            // input/output/parity Codable specs +
            // validator)。MLX → CoreML CLI driver still
            // external,but now reads + emits the typed
            // contract on both ends。
            return .externalSubstrateContractTyped

        // P3 eval
        case .g12AutoEval:
            // M861 typed primitives + M863 SQLite persistence
            // + M864 orchestration actor
            return .substrateClosed

        case .g13MambaFrontier:
            // P3 research deferred per M840 roadmap
            return .external
        }
    }

    /// All gaps with `substrateClosed` status (hosts can opt in
    /// today)。
    public static func closedGaps() -> [BASCognitiveOSGap] {
        BASCognitiveOSGap.allCases.filter {
            status(of: $0) == .substrateClosed
        }
    }

    /// All gaps with `substrateClosedSDKBridgePending` status —
    /// substrate ready,SDK call site needs the bridge wired
    /// when iOS 26 SDK stabilizes。
    public static func sdkBridgePendingGaps()
        -> [BASCognitiveOSGap]
    {
        BASCognitiveOSGap.allCases.filter {
            status(of: $0)
                == .substrateClosedSDKBridgePending
        }
    }

    /// All genuinely external gaps (cannot be done at substrate
    /// level — Python pipelines,external toolchain,device
    /// validation)。
    /// M918:returns only `.external` status,not the M917+M918
    /// typed-contract flavor。Use `externalContractTypedGaps()`
    /// for that subset。
    public static func externalGaps() -> [BASCognitiveOSGap] {
        BASCognitiveOSGap.allCases.filter {
            status(of: $0) == .external
        }
    }

    /// M918:all gaps with `externalSubstrateContractTyped`
    /// status — external work,but with substrate-side typed
    /// contract shipped。Currently G8 (Mamba SSM training) +
    /// G11 (MLX→CoreML conversion)。
    public static func externalContractTypedGaps()
        -> [BASCognitiveOSGap]
    {
        BASCognitiveOSGap.allCases.filter {
            status(of: $0)
                == .externalSubstrateContractTyped
        }
    }

    /// All environmental gaps (toolchain / Xcode-version issues
    /// not fixable at substrate level)。Currently empty — the
    /// known BASMLXAdapter macros plugin issue is documented
    /// inline in MLXLoRATrainer.swift but is not a "gap" in
    /// the M840 roadmap sense (it's a build environment issue,
    /// not an unshipped capability)。
    public static func environmentalGaps()
        -> [BASCognitiveOSGap]
    {
        BASCognitiveOSGap.allCases.filter {
            status(of: $0) == .environmental
        }
    }

    /// Closure ratio — fraction of P1-P3 gaps that are closed
    /// at substrate level (counts substrateClosed +
    /// substrateClosedSDKBridgePending +
    /// externalSubstrateContractTyped toward closure since
    /// those are all substrate-tractable;counts pure
    /// `external` + `environmental` against)。
    /// M918 update:typed-contract external gaps now count
    /// toward closure since the substrate-side surface IS
    /// shipped (only the Python / CLI external work remains)。
    public static func substrateClosureRatio() -> Double {
        let total = Double(BASCognitiveOSGap.allCases.count)
        guard total > 0 else { return 0 }
        let closedCount = Double(
            BASCognitiveOSGap.allCases.filter { gap in
                let s = status(of: gap)
                return s == .substrateClosed
                    || s == .substrateClosedSDKBridgePending
                    || s == .externalSubstrateContractTyped
            }.count)
        return closedCount / total
    }
}
