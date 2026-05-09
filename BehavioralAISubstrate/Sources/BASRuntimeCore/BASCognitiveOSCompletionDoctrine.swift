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
    public static let doctrineVersion: String = "ADR-016.M1009"

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
