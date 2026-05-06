import Foundation
import BASHostKit
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(BASMLXAdapter)
import BASMLXAdapter
import BASOrgan
#endif

// MARK: - M573 (chapter 一百四十七 part 2) bench helpers (inlined here
// because adding a separate file requires Xcode project edits)

// M798 chapter 二百十七 — `SampleHostBenchRow` extracted to
// dedicated file `SampleHostLegacyBenchRunner.swift` (alongside
// the legacy `SampleHostBenchRunner` actor).

// M799 chapter 二百十八 — 6 prompt dimension enums +
// `SampleHostPromptSignature` + `SampleHostGeneratedPrompt`
// extracted to dedicated file `SampleHostPromptTypes.swift`
// (single-source-of-truth for combinatorial prompt-space schema
// per chapter 二百十一 doctrine).

// M793 chapter 二百十二 — `SampleHostBenchPromptCatalog` extracted
// to dedicated file `SampleHostBenchPromptCatalog.swift`.
// Coprime stride 5041 + 5-variant mutation alphabet doctrine
// preserved verbatim. Bench loop callers unchanged.

// M800 chapter 二百十九 — `SampleHostBenchHelpers` foundation
// enum extracted to dedicated file `SampleHostBenchHelpers.swift`.
// Other carve-out files extend this enum; original definition
// owns the file (chapter 二百十一 single-source-of-truth).

// M798 chapter 二百十七 — `SampleHostBenchRunner` actor extracted
// to dedicated file `SampleHostLegacyBenchRunner.swift` (alongside
// the legacy `SampleHostBenchRow` struct it persists).

@MainActor
final class SampleHostModel: ObservableObject {
    @Published private(set) var result: BASHostSessionResult
    @Published private(set) var lastError: String?
    @Published private(set) var benchIsRunning: Bool = false
    @Published private(set) var benchIterationsCompleted: Int = 0
    @Published private(set) var benchAuditCodesTotal: Int = 0
    @Published private(set) var benchStartTime: Date?
    @Published private(set) var benchLastError: String?
    @Published private(set) var benchOutputPath: String = ""
    // M609 chapter 一百七十六 §176.13 — direct AFM test (foreground UI invocation)
    @Published private(set) var afmTestStatus: String = "idle"
    @Published private(set) var afmTestOutput: String = ""
    @Published private(set) var afmTestPrompt: String = "Suggest one calming evening habit in one sentence."
    @Published private(set) var afmTestDurationMs: Double = 0
    @Published private(set) var afmIsRunning: Bool = false

    // M610 chapter 一百七十六 §176.14 — long-running AFM bench
    // (8h default per user request; full flexible config: every numeric
    // value is a `@Published` so all "fixed values" are programmatic).
    @Published var afmBenchDurationHours: Double = 8.0
    @Published var afmBenchStrideRotationCSV: String = "5041,5039,5051,5077,7919"
    @Published var afmBenchRotationPeriodIter: Int = 11_300
    @Published var afmBenchMutationSeedCount: Int = 5
    @Published var afmBenchJSONLRotationMB: Int = 15
    // Default `false` — substrate routes ~50% to .delay + ~50% to
    // .block (chapter 175 empirical), so default skipBlocked=true would
    // skip every iter. User saw "全 skip 了" with default true. New
    // default: always call AFM (toggle on if 8h bench should respect
    // substrate routing for AFM cost-saving).
    @Published var afmBenchSkipBlocked: Bool = false
    @Published var afmBenchAFMTimeoutSec: Int = 30
    @Published private(set) var afmBenchIsRunning: Bool = false
    @Published private(set) var afmBenchIterations: Int = 0
    @Published private(set) var afmBenchAFMSuccessCount: Int = 0
    @Published private(set) var afmBenchAFMSkippedCount: Int = 0
    @Published private(set) var afmBenchAFMErrorCount: Int = 0
    @Published private(set) var afmBenchOutputPath: String = ""
    @Published private(set) var afmBenchStartTime: Date?
    @Published private(set) var afmBenchLastError: String?
    private var afmBenchTask: Task<Void, Never>?

    // M619 chapter 一百七十七 §177 — Hybrid AFM + Gemma bench with
    // CoreML-driven router (ChengluPreflight v0 single head).
    @Published var hybridBenchDurationHours: Double = 8.0
    @Published var hybridBenchStrideRotationCSV: String = "5041,5039,5051,5077,7919"
    @Published var hybridBenchRotationPeriodIter: Int = 11_300
    @Published var hybridBenchMutationSeedCount: Int = 5
    @Published var hybridBenchJSONLRotationMB: Int = 15
    // M710 chapter 一百九十一 — extracted from HybridBenchTuning
    // constants. User can adjust via UI (chapter 191 sliders).
    @Published var hybridBenchVerbosityThresholdChars: Int =
        HybridBenchTuning.verbosityThresholdChars
    @Published var hybridBenchSigmoidClassThreshold: Double =
        HybridBenchTuning.sigmoidClassThreshold
    @Published var hybridBenchYieldEveryNIters: Int =
        HybridBenchTuning.yieldEveryNIters
    @Published var hybridBenchPostLLMTruncationChars: Int =
        HybridBenchTuning.postLLMBodyTruncationChars
    /// M711 chapter 一百九十一 — `.canonical` (chapter 178+
    /// default) vs `.fourteenLayer` (M711 14-layer smoke).
    /// M719 chapter 一百九十二 — `.heavyTailed` 10h preset.
    @Published var hybridBenchSmokeMode:
        HybridBenchConfig.SmokeMode = .canonical
    /// M731 chapter 一百九十四 — chapter-192 safety-kit flex
    /// constants exposed to UI. Bench loop reads live so operator
    /// can adjust mid-config without rebuild. Bounds enforced
    /// via `update*` methods to keep doctrine within sane range.
    @Published var hybridBenchAnomalyWindowSize: Int = 100
    @Published var hybridBenchDriftSigmaThreshold: Double = 3.0
    @Published var hybridBenchMutationProbability: Double = 0.05
    @Published var hybridBenchCheckpointEveryNIters: Int = 1000
    /// M735 chapter 一百九十五 — per-iter LLM call timeout in seconds.
    /// Both AFM and Gemma calls are wrapped with this deadline so a
    /// hung LLM never freezes the bench loop. Default 60s is loose
    /// (Gemma cold-start can be ~30s; AFM normal is sub-2s).
    @Published var hybridBenchLLMTimeoutSeconds: Double = 60.0
    /// M735 — track per-iter timeout fires for live dashboard.
    @Published private(set) var hybridBenchLLMTimeoutCount: Int = 0
    /// M740 chapter 一百九十七 — opt-in pause on `.serious` thermal.
    /// Chapter 一百九十六 iPhone 17e smoke: 91% of 12-min substrate-
    /// only run at `.serious` thermal. For 10h, operator on hot
    /// device can flip true so `.serious` triggers pause in
    /// addition to `.critical`. Default false to preserve doctrine.
    @Published var hybridBenchPauseOnSerious: Bool = false
    /// M766 chapter 二百四 — workflowProfile flex picker.
    /// Pre-this-batch bench hardcoded `.reflective` which caused
    /// 100% substrate-skip across BOTH heavy-tailed (4h51m, 113K
    /// iters) AND canonical (45min, 41K iters) iPhone runs —
    /// substrate's reflective workflow always routes to .delay
    /// regardless of stake. For LLM-data accumulation, `.primary`
    /// gives faster decisions = more `.answer` permits = AFM/Gemma
    /// fires. Default `.reflective` preserves chapter 178+ doctrine
    /// baseline; operator picks `.primary` for training-data runs.
    @Published var hybridBenchWorkflowProfile:
        BASHostWorkflowProfile = .reflective
    /// M744 chapter 一百九十八 — active cooling sleep period.
    /// Every N iters where the device is at `.serious` or worse,
    /// inject a 10-second cooling sleep. 0 = disabled (default).
    /// Chapter 一百九十六 iPhone smoke showed sustained `.serious`
    /// for 10+ min; 1000-iter cooling at 18 iter/sec ≈ once every
    /// 55s. Operator opts in for 10h on hot device.
    @Published var hybridBenchCoolingEveryNIters: Int = 0
    /// M744 — cooling sleep duration in seconds. Range [5, 60].
    @Published var hybridBenchCoolingSleepSeconds: Double = 10.0
    /// M744 — track cooling sleep fires for live dashboard.
    @Published private(set) var hybridBenchCoolingSleepCount: Int = 0
    /// M745 chapter 一百九十八 — live thermal state surface for
    /// dashboard widget. Updated per-iter from
    /// `SampleHostBenchThermalGate.currentDeviceState()`. Lets
    /// operator see current thermal in real time during 10h
    /// instead of grepping JSONL post-hoc.
    @Published private(set) var hybridBenchLastThermalRaw: String = "unknown"
    /// M745 — count of iters spent at each thermal level.
    /// Lets dashboard show "% at serious", etc.
    @Published private(set) var hybridBenchThermalNominalIters: Int = 0
    @Published private(set) var hybridBenchThermalFairIters: Int = 0
    @Published private(set) var hybridBenchThermalSeriousIters: Int = 0
    @Published private(set) var hybridBenchThermalCriticalIters: Int = 0
    @Published private(set) var hybridBenchIsRunning: Bool = false
    @Published private(set) var hybridBenchIterations: Int = 0
    @Published private(set) var hybridBenchAFMOk: Int = 0
    @Published private(set) var hybridBenchGemmaOk: Int = 0
    @Published private(set) var hybridBenchAFMFallbackToGemmaOk: Int = 0
    @Published private(set) var hybridBenchGemmaFallbackToAFMOk: Int = 0
    @Published private(set) var hybridBenchBothFailed: Int = 0
    @Published private(set) var hybridBenchRouterHits: Int = 0
    @Published private(set) var hybridBenchRouterMisses: Int = 0
    // M628 chapter 一百七十八 — dispatch policy live counters.
    // Tracks how often substrate's permit mode causes LLM skip /
    // both-call / local-only / draft-only path. UI surfaces these
    // so user sees substrate-LLM coupling in real time.
    @Published private(set) var hybridBenchSubstrateSkipBlock: Int = 0
    @Published private(set) var hybridBenchSubstrateSkipReplace: Int = 0
    @Published private(set) var hybridBenchSubstrateSkipDelay: Int = 0
    @Published private(set) var hybridBenchSubstrateBothLLMs: Int = 0
    @Published private(set) var hybridBenchSubstrateLocalOnly: Int = 0
    @Published private(set) var hybridBenchSubstrateDraftOnly: Int = 0
    // M630 chapter 一百七十八 — closed-loop tracking. How often
    // post-LLM substrate observation shifts permit mode (i.e.
    // LLM produced something that would have been blocked).
    @Published private(set) var hybridBenchPostLLMShifted: Int = 0

    /// M676 chapter 一百八十六 — B15 (MEDIUM) fix:
    /// counter partition sanity — sum of all per-iter outcome
    /// counters MUST equal `hybridBenchIterations`. If they
    /// drift, either there's a missing increment in some
    /// dispatch branch OR a double-increment somewhere.
    /// UI surfaces this for live diagnostic.
    ///
    /// Outcome counters tracked: AFMOk + GemmaOk + AFMFallback +
    /// GemmaFallback + BothFailed (LLM-result tally) + 3 skip
    /// counters (skipBlock + skipReplace + skipDelay).
    /// `bothLLMs` and `localOnly` paths fold into AFMOk +
    /// GemmaOk and BothFailed, so their separate counters
    /// (hybridBenchSubstrateBothLLMs / LocalOnly / DraftOnly)
    /// are independent observability — NOT part of the
    /// outcome partition.
    var hybridBenchAccountedTotal: Int {
        return hybridBenchAFMOk
            + hybridBenchGemmaOk
            + hybridBenchAFMFallbackToGemmaOk
            + hybridBenchGemmaFallbackToAFMOk
            + hybridBenchBothFailed
            + hybridBenchSubstrateSkipBlock
            + hybridBenchSubstrateSkipReplace
            + hybridBenchSubstrateSkipDelay
    }

    /// True iff outcome counters partition the iter count.
    /// `hybridBenchAccountedTotal == hybridBenchIterations`.
    /// `bothLLMs` outcomes increment 2 counters (AFMOk +
    /// GemmaOk both succeed) so this can be > iterations under
    /// chapter 178's bothLLMs branch — that's a known
    /// non-strict partition. UI displays sign of drift.
    var hybridBenchPartitionDelta: Int {
        return hybridBenchAccountedTotal - hybridBenchIterations
    }

    // M635 chapter 一百七十九 — 2nd CoreML head agreement counter.
    // How often ChengluPermitPredict's class matches substrate's
    // actual .block decision. High agreement = model is a faithful
    // policy cache; disagreement = doctrine drift signal.
    @Published private(set) var hybridBenchPermitPredictHits: Int = 0
    @Published private(set) var hybridBenchPermitPredictMisses: Int = 0
    // M642 chapter 一百八十 — running mean absolute error of
    // Length + Latency regression heads vs actual LLM outputs.
    // Updated per-iter when LLM body returns; nil samples skipped.
    // These ARE expected to be non-zero (regression heads are
    // not 100% accurate; chapter 176 train MAE was ~479 chars
    // and ~2091 ms) — bench just records empirical residuals.
    // M669 chapter 一百八十五 — B8: Welford online running mean.
    // M689 chapter 一百八十八 — B8 retire (HIGH closed):
    // removed legacy `*Sum` (kept Count for UI sample-count
    // display + Running for the actual mean). Welford alone
    // delivers the same metric with stable precision over 144K
    // samples; Sum was redundant + drifted over 2^26 magnitude.
    // Backward compat: JSONL row never had Sum/Count fields
    // (those were @Published runtime-only), so retiring them
    // doesn't break analysis tooling.
    @Published private(set) var hybridBenchLengthMAECount: Int = 0
    @Published private(set) var hybridBenchLengthMAERunning: Double = 0
    @Published private(set) var hybridBenchLatencyMAECount: Int = 0
    @Published private(set) var hybridBenchLatencyMAERunningMs: Double = 0
    // M661 chapter 一百八十三 — 5th head agreement counters.
    @Published private(set) var hybridBenchVerbosityCorrect: Int = 0
    @Published private(set) var hybridBenchVerbosityWrong: Int = 0
    @Published private(set) var hybridBenchOutputPath: String = ""
    @Published private(set) var hybridBenchStartTime: Date?
    @Published private(set) var hybridBenchLastError: String?
    // M727 chapter 一百九十三 — live anomaly counters surfaced
    // for the dashboard widget. Updated per-iter from
    // SampleHostBenchAnomalyWatcher.snapshot(). Distinct from
    // anomalyFlags-on-row (which is per-iter) — these are
    // cumulative for the whole bench.
    @Published private(set) var hybridBenchStuckSubstrateCount: Int = 0
    @Published private(set) var hybridBenchStuckLLMCount: Int = 0
    @Published private(set) var hybridBenchPauseSkippedCount: Int = 0
    @Published private(set) var hybridBenchAdversarialFiredCount: Int = 0
    @Published private(set) var hybridBenchDriftAlarmCount: Int = 0
    /// M726 chapter 一百九十三 — resume snapshot from a previous
    /// (possibly crashed) bench. Populated by `loadResumableCheckpoint()`
    /// at app launch. nil = no checkpoint or last bench finished
    /// cleanly. UI banner offers `clearResumableCheckpoint()` or
    /// allows starting a new bench (which auto-clears the stale
    /// checkpoint via fresh write).
    @Published private(set) var hybridBenchResumableCheckpoint:
        SampleHostBenchCheckpoint?
    @Published private(set) var hybridGemmaLoadStatus: String = "idle"
    @Published private(set) var hybridSinglePromptStatus: String = "idle"
    @Published private(set) var hybridSinglePromptOutput: String = ""
    @Published private(set) var hybridSinglePromptRoute: String = ""
    @Published private(set) var hybridSinglePromptProb: Double = 0
    // M659 chapter 一百八十三 — single-prompt inline all-head
    // predictions. Populated when runHybridSinglePrompt fires;
    // surface 5 head outputs alongside the LLM body so user sees
    // meridian network predictions BEFORE waiting for LLM.
    @Published private(set) var hybridSinglePromptBlockProb: Double?
    @Published private(set) var hybridSinglePromptLengthChars: Double?
    @Published private(set) var hybridSinglePromptLatencyMs: Double?
    @Published private(set) var hybridSinglePromptVerbosityProb: Double?
    private var hybridBenchTask: Task<Void, Never>?
    // M627 chapter 177 deep-review fix #3 — Stop→Start race.
    // Each start bumps generation + captures myGen. Old task at
    // exit only writes hybridBenchIsRunning=false if its myGen
    // still matches; otherwise a newer start has already run and
    // we must not clobber its true. Also defends against the old
    // task's final JSONL write racing the new task's runner.
    private var hybridBenchGeneration: Int = 0

    /// M690 chapter 一百八十八 — B5-extended (HIGH) helper:
    /// apply a mutating closure ONLY if the caller's generation
    /// matches the current bench. Stale tasks (Stop→Start race
    /// after they cancelled but before they exited mid-iter) get
    /// no-op'd here instead of writing to fresh task's counters.
    ///
    /// Use:
    /// ```swift
    /// applyIfActive(myGen) {
    ///     self.hybridBenchAFMOk += 1
    /// }
    /// ```
    ///
    /// vs pre-fix:
    /// ```swift
    /// self.hybridBenchAFMOk += 1  // pollutes new gen on race
    /// ```
    func applyIfActive(
        _ myGen: Int,
        _ mutate: () -> Void
    ) {
        guard hybridBenchGeneration == myGen else { return }
        mutate()
    }

    #if canImport(BASMLXAdapter)
    private var gemmaAdapter: MLXOrganAdapter?
    // M627 chapter 177 deep-review fix #2 — gate concurrent loads
    // via in-flight Task. Two callGemma invocations during await
    // suspension would both start loading the 4-bit model + LoRA
    // (~3.4 GB, hundreds of MB resident wasted). Now they share.
    private var gemmaLoadInFlight: Task<MLXOrganAdapter, Error>?
    // M627 deep-review fix #4 — track LoRA load success separately
    // from adapter init so a failed LoRA load doesn't poison the
    // session: status tells the truth + future calls can retry.
    private var gemmaLoraLoaded: Bool = false
    #endif

    private var benchTask: Task<Void, Never>?
    private let benchRunner = SampleHostBenchRunner()

    private let runtime: BASHostRuntime
    private static let workflowBehavior = BASHostWorkflowBehaviorConfiguration(
        modeIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASDecisionMode.primaryID,
            BASHostWorkflowProfile.comparative.rawValue: BASDecisionMode.comparativeID,
            BASHostWorkflowProfile.reflective.rawValue: BASDecisionMode.reflectiveID
        ],
        templateIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: ["samplehost.template.pulse-lens"],
            BASHostWorkflowProfile.comparative.rawValue: ["samplehost.template.contrast-lens"],
            BASHostWorkflowProfile.reflective.rawValue: ["samplehost.template.signal-lens"]
        ],
        memorySourceIDsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASMemorySource.pattern.rawValue,
            BASHostWorkflowProfile.comparative.rawValue: BASMemorySource.archive.rawValue,
            BASHostWorkflowProfile.reflective.rawValue: BASMemorySource.reflection.rawValue
        ],
        interactiveRetrievalModeByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: "compact",
            BASHostWorkflowProfile.comparative.rawValue: "balanced",
            BASHostWorkflowProfile.reflective.rawValue: "full"
        ],
        providerObservationNarrativesByKindID: [
            BASDecisionMode.primaryID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Pulse Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Pulse Lens pass.",
                deterministicFallbackBase: "No provider returned a Pulse Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Pulse Lens pass",
                providerConsistencySource: "provider Pulse Lens pass"
            ),
            BASDecisionMode.comparativeID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Contrast Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Contrast Lens pass.",
                deterministicFallbackBase: "No provider returned a Contrast Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Contrast Lens pass",
                providerConsistencySource: "provider Contrast Lens pass"
            ),
            BASDecisionMode.reflectiveID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the Signal Lens pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the Signal Lens pass.",
                deterministicFallbackBase: "No provider returned a Signal Lens result, so SampleHost kept the deterministic draft.",
                cachedConsistencySource: "cached Signal Lens pass",
                providerConsistencySource: "provider Signal Lens pass"
            ),
            BASSemanticTaskKind.selectionID: BASAppleProviderObservationNarrative(
                templatePinnedDetail: "Template mode is pinned, so no model provider was used for the candidate selection pass.",
                admissionSkippedDetailPrefix: "Admission controller skipped the candidate selection pass.",
                deterministicFallbackBase: "No provider returned a candidate selection result, so SampleHost kept the deterministic ordering.",
                cachedConsistencySource: "cached candidate selection pass",
                providerConsistencySource: "provider candidate selection pass"
            )
        ],
        memorySourceIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: BASMemorySource.cue.rawValue,
            BASHostSessionKind.reopen.rawValue: BASMemorySource.archive.rawValue,
            BASHostSessionKind.notification.rawValue: BASMemorySource.cue.rawValue
        ],
        retrievalModeIDsBySessionKindID: [
            BASHostSessionKind.ambient.rawValue: "guarded",
            BASHostSessionKind.reopen.rawValue: "balanced",
            BASHostSessionKind.handoff.rawValue: "compact",
            BASHostSessionKind.widget.rawValue: "compact",
            BASHostSessionKind.notification.rawValue: "guarded"
        ],
        failureGuardIDsByRiskLevelID: [
            BASHostRiskLevel.high.rawValue: ["samplehost.guard/elevated-risk"]
        ],
        hostNamespace: "samplehost"
    )
    private static let lifecycleBehavior = BASHostLifecycleBehaviorConfiguration(
        bootstrapBehavior: BASAppleLifecycleBootstrapBehavior(
            actionsByPhaseID: [
                BASAppleLifecycleBootstrapPhase.initialAppearance.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.launch.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .consumePendingLaunchRequest)
                ],
                BASAppleLifecycleBootstrapPhase.sceneActive.rawValue: [
                    BASAppleLifecycleBootstrapAction(kind: .refreshMemoryProjection),
                    BASAppleLifecycleBootstrapAction(
                        kind: .refreshCurrentBrain,
                        bootstrapTriggerID: BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
                    ),
                    BASAppleLifecycleBootstrapAction(kind: .restoreActiveWorkspace)
                ]
            ],
            activeRefreshDefaultModeID: BASDecisionMode.primary.identifier,
            activeRefreshDefaultRetrievalModeID: "balanced"
        ),
        currentBrainBootstrapBehavior: BASCurrentBrainBootstrapBehavior(
            defaultModeID: BASDecisionMode.primaryID,
            defaultTriggerID: BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue,
            defaultRiskLevelID: BASRiskLevel.low.rawValue,
            defaultSourceSurfaceID: BASInteractionSurface.app.rawValue,
            modeIDAliasesByID: [
                "pulse-lens": BASDecisionMode.primaryID,
                "contrast-lens": BASDecisionMode.comparativeID,
                "signal-lens": BASDecisionMode.reflectiveID
            ],
            triggerIDAliasesByID: [
                "alert": BASCurrentBrainBootstrapTrigger.notification.rawValue,
                "resume": BASCurrentBrainBootstrapTrigger.sceneActive.rawValue
            ],
            riskLevelIDAliasesByID: [
                "elevated": BASRiskLevel.high.rawValue,
                "guarded": BASRiskLevel.medium.rawValue
            ],
            sourceSurfaceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASInteractionSurface.watch.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASInteractionSurface.widget.rawValue
            ],
            enforcedSourceSurfaceByTriggerID: [
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASInteractionSurface.notification.rawValue
            ],
            defaultMemorySourceID: BASMemorySource.archive.rawValue,
            memorySourceIDAliasesByID: [
                "archive": BASMemorySource.archive.rawValue,
                "reflection-notes": BASMemorySource.reflection.rawValue,
                "signal-cache": BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByTriggerID: [
                BASCurrentBrainBootstrapTrigger.sceneActive.rawValue: BASMemorySource.pattern.rawValue,
                BASCurrentBrainBootstrapTrigger.watchHandoff.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.notification.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.widget.rawValue: BASMemorySource.cue.rawValue,
                BASCurrentBrainBootstrapTrigger.explicitRefresh.rawValue: BASMemorySource.archive.rawValue,
                BASCurrentBrainBootstrapTrigger.sessionBootstrap.rawValue: BASMemorySource.pattern.rawValue
            ],
            memorySourceOverridesByModeID: [
                BASDecisionMode.comparative.identifier: BASMemorySource.archive.rawValue,
                BASDecisionMode.reflective.identifier: BASMemorySource.reflection.rawValue
            ],
            unknownRequestedModeFallbackPolicy: .useConfiguredDefault,
            unknownRequestedTriggerFallbackPolicy: .useConfiguredDefault,
            bootstrapAdvisorBehavior: BASBrainBootstrapAdvisorBehavior(
                highRiskSignalGroups: [
                    ["send", "publish", "post", "reply"],
                    ["buy", "upgrade", "subscribe", "checkout"]
                ],
                nightFallbackRiskLevelByModeID: [
                    BASDecisionMode.primary.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.comparative.identifier: BASRiskLevel.medium.rawValue,
                    BASDecisionMode.reflective.identifier: BASRiskLevel.high.rawValue
                ],
                defaultRiskLevelByModeID: [
                    BASDecisionMode.reflective.identifier: BASRiskLevel.medium.rawValue
                ]
            )
        ),
        predictiveInterventionBehavior: BASApplePredictiveInterventionBehavior(
            lowRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Hold this in the Pulse Lens a little longer.",
                detail: "SampleHost prefers a short pause before committing this move.",
                preferredModeID: BASDecisionMode.primary.identifier
            ),
            mediumRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Run this through Contrast Lens first.",
                detail: "SampleHost wants one cleaner comparison pass before you act.",
                preferredModeID: BASDecisionMode.comparative.identifier
            ),
            highRisk: BASApplePredictiveInterventionRiskBehavior(
                title: "Switch into Signal Lens before you move.",
                detail: "SampleHost sees elevated risk and wants a calmer signal-reading pass first.",
                preferredModeID: BASDecisionMode.reflective.identifier
            ),
            preferredModeIDsByCurrentModeID: [
                BASDecisionMode.reflective.identifier: BASDecisionMode.reflective.identifier
            ],
            mediumRiskNegativeRecentThreshold: 1,
            highRiskNegativeRecentThreshold: 2,
            nightWindowReason: "SampleHost treats this time window as lower-fidelity decision time.",
            negativeRecentReason: "Recent rushed passes under similar conditions ended poorly.",
            failureGuardReasonsByID: [
                "samplehost.guard/elevated-risk": "SampleHost already has a guard up for elevated-risk conditions."
            ],
            defaultReason: "SampleHost prefers a steadier lane here."
        ),
        projectionRefreshLimits: BASAppleMemoryProjectionRefreshLimits(
            recordLimit: 48,
            candidateLimit: 20,
            checkEventLimit: 64,
            comparativeRecordLimit: 20,
            reflectiveRecordLimit: 20
        )
    )
    private static let cognitionBehavior = BASHostCognitionBehaviorConfiguration(
        reactionWeightsByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASReactionWeights(
                briefLanguage: 0.60,
                warmDirectTone: 0.50,
                lowCognitiveLoad: 0.56,
                interruptiveActionBias: 0.58,
                boundaryNamingBias: 0.32,
                tradeoffClarityBias: 0.40
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASReactionWeights(
                briefLanguage: 0.46,
                warmDirectTone: 0.52,
                lowCognitiveLoad: 0.44,
                interruptiveActionBias: 0.34,
                boundaryNamingBias: 0.48,
                tradeoffClarityBias: 0.72
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASReactionWeights(
                briefLanguage: 0.48,
                warmDirectTone: 0.64,
                lowCognitiveLoad: 0.52,
                interruptiveActionBias: 0.22,
                boundaryNamingBias: 0.68,
                tradeoffClarityBias: 0.40
            )
        ],
        identityProfilesByProfileID: [
            BASHostWorkflowProfile.primary.rawValue: BASIdentityProfile(
                role: .boundedGuide,
                posture: .coaching,
                initiative: .guided,
                confidenceCeiling: 0.68,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost keeps the lane narrow and practical."
            ),
            BASHostWorkflowProfile.comparative.rawValue: BASIdentityProfile(
                role: .tradeoffGuide,
                posture: .reflective,
                initiative: .guided,
                confidenceCeiling: 0.72,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost compares pressures without deciding for you."
            ),
            BASHostWorkflowProfile.reflective.rawValue: BASIdentityProfile(
                role: .reflectiveWitness,
                posture: .reflective,
                initiative: .passive,
                confidenceCeiling: 0.66,
                canAdvise: true,
                canExecuteActions: false,
                canEscalateToCloud: false,
                relationshipBoundary: "SampleHost reflects the pattern without taking center stage."
            )
        ],
        substrateBehavior: BASCognitionBehavior(
            sessionBias: BASSessionBiasBehavior(
                defaultBiasesByModeID: [
                    BASDecisionMode.primary.identifier: ["Keep the lane narrow before expanding it."],
                    BASDecisionMode.comparative.identifier: ["Hold the active pressures in view without collapsing them."],
                    BASDecisionMode.reflective.identifier: ["Surface the signal before making it actionable."]
                ],
                briefLanguageSignals: ["brief", "tight", "concise"],
                nightBias: "SampleHost treats late sessions as lower-fidelity decision windows.",
                nightLowLoadBias: "SampleHost lowers cognitive load when energy is thin.",
                lowCognitiveLoadSignals: ["lighter", "shorter guidance", "overloaded"],
                interruptiveActionSignals: ["pause", "hold", "step away"],
                interruptiveActionBias: "SampleHost prefers one regulating move before extra analysis.",
                boundaryNamingSignals: ["limit", "edge", "boundary"],
                boundaryNamingBias: "SampleHost names the limit before it reframes it.",
                tradeoffClaritySignals: ["tradeoff", "constraint", "cost", "benefit"],
                tradeoffClarityBias: "SampleHost keeps the trade-off explicit before polishing language."
            ),
            memoryTrust: BASMemoryTrustBehavior(
                baseScoresBySourceID: [
                    BASMemorySource.cue.rawValue: 0.72,
                    BASMemorySource.pattern.rawValue: 0.78,
                    BASMemorySource.reflection.rawValue: 0.84,
                    BASMemorySource.archive.rawValue: 0.88
                ],
                sourceDecayMultipliersBySourceID: [
                    BASMemorySource.cue.rawValue: 1.08,
                    BASMemorySource.pattern.rawValue: 1.04,
                    BASMemorySource.reflection.rawValue: 0.94,
                    BASMemorySource.archive.rawValue: 1.12
                ]
            )
        )
    )
    private static let sampleHostPresentation = BASHostPresentationConfiguration(
        workflowTitles: BASHostWorkflowTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens"
        ),
        sessionTitles: BASHostSessionTitles(
            primary: "Pulse Lens",
            comparative: "Contrast Lens",
            reflective: "Signal Lens",
            initialAppearance: "SampleHost Bootstrap",
            sceneActive: "SampleHost Refresh"
        ),
        followUpActions: BASHostFollowUpActions(
            primary: ["Spot the impulse", "Name one next move"],
            comparative: ["Frame the competing pulls", "Choose one bounded comparison"],
            reflective: ["Name the deeper signal", "Choose one grounded reflection"],
            highRiskEscalation: ["Add one more confirmation step"]
        ),
        lifecycle: BASHostLifecyclePresentation(
            initialAppearancePromptFallback: "Load the substrate before the host asks it to speak.",
            sceneActivePromptFallback: "Refresh the current brain and restore the shell."
        ),
        notices: BASHostNoticeTemplates(
            enteredWorkflow: "{surface} entered the {workflow} lane in SampleHost.",
            runtimeProfile: "SampleHost runtime profile {runtimeProfile} is active.",
            reopenFollowUpAction: "Reopen with the {workflow} lane",
            emptyPromptGoalFallback: "Keep the host steady before acting."
        ),
        predictiveIntervention: BASHostPredictiveInterventionPresentation(
            mediumRiskTitle: "Pause for one slower pass.",
            mediumRiskDetail: "SampleHost wants one more comparison step here.",
            highRiskTitle: "Add one more checkpoint.",
            highRiskDetail: "SampleHost sees elevated risk and wants stronger confirmation.",
            reopenRiskDetail: "This reopen path needs a little more structure in SampleHost.",
            fallbackReopenSuggestionDetail: "A prior hold suggests restoring friction first.",
            defaultReason: "SampleHost prefers a slower lane here."
        )
    )
    private static let runtimeTuning: BASEBrainRuntimeSynthesisPolicy = {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic.withSchemaVersion(
            "samplehost.runtime-synthesis.v1"
        )
        tuning.wakeIntent.highRiskGuardThreshold = 0.69
        tuning.stateTransitions.quarantineFailureGuardThreshold = 3
        tuning.stateTransitions.runModeRules = tuning.stateTransitions.synthesizedRunModeRules(
            wakeIntent: tuning.wakeIntent
        )
        tuning.lease.restrictedEnergyQuota = 0.46
        tuning.maintenance.standardBatteryFloor = 0.36
        tuning.sovereignExecution.deadStopOnExtremeBlockedPermit = false
        tuning.context.emotionalLoadDriftingIncrement = 0.09
        tuning.triSelf.directPathSuperegoPenalty = 0.46
        tuning.risk.defaultForecastUncertainty = 0.24
        return tuning
    }()

    init(
        runtime: BASHostRuntime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "samplehost.default-runtime",
                policyProfileID: "samplehost.default-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: SampleHostModel.lifecycleBehavior,
                workflowBehavior: SampleHostModel.workflowBehavior,
                cognitionBehavior: SampleHostModel.cognitionBehavior,
                presentation: SampleHostModel.sampleHostPresentation,
                runtimeTuning: SampleHostModel.runtimeTuning,
                runtimePolicyLineage: BASRuntimePolicyLineage(
                    bundleVersion: "samplehost.runtime-policy-bundle.v1",
                    providerRoutingRegistryVersion: "samplehost.provider-routing-registry.v1",
                    providerRoutingPolicyID: "samplehost.provider-routing.v1",
                    runtimeTuningRegistryVersion: "samplehost.runtime-tuning-registry.v1",
                    runtimeTuningPolicyID: "samplehost.runtime-tuning.v1",
                    resolutionSourceID: "sample_host_default"
                ),
                hostRhythmProfile: .generic
            )
        )
    ) {
        var initialError: String?
        self.runtime = runtime
        self.result = Self.perform(
            using: runtime,
            errorSink: { initialError = $0 },
            request: {
                try runtime.bootstrap(
                    BASHostLifecycleRequest(
                        phase: .initialAppearance,
                        sessionKind: .ambient,
                        preferredProfile: .primary,
                        sourceSurface: .application,
                        promptSeed: "Load the substrate before the host asks it to speak.",
                        riskLevel: .low
                    )
                )
            }
        )
        self.lastError = initialError

        // M573 auto-start: chapter 一百四十七 SampleHost build is the
        // bench-enabled variant. Auto-start the bench loop on launch
        // so the iPhone produces real-device data without requiring
        // a button tap. User can still tap "Stop" via the bench panel
        // if they want to halt it.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s grace
            self?.startBench()
        }
    }

    func bootstrap() {
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.bootstrap(
                    BASHostLifecycleRequest(
                        phase: .sceneActive,
                        sessionKind: .ambient,
                        preferredProfile: .primary,
                        sourceSurface: .application,
                        promptSeed: "Refresh the current brain and restore the shell.",
                        riskLevel: .low
                    )
                )
            }
        )
    }

    func start(_ profile: BASHostWorkflowProfile) {
        let prompts: [BASHostWorkflowProfile: String] = [
            .primary: "Should I do this right now?",
            .comparative: "What tradeoff am I refusing to name?",
            .reflective: "What is the honest story here?"
        ]
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: profile,
                        surface: .application,
                        prompt: prompts[profile] ?? "Hold this decision for one more beat.",
                        title: "\(SampleHostModel.sampleHostPresentation.workflowTitles.title(for: profile)) from SampleHost",
                        riskLevel: profile == .reflective ? .medium : .low
                    )
                )
            }
        )
    }

    func reopen() {
        result = Self.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.reopen(
                    BASHostReopenRequest(
                        workflowProfile: .comparative,
                        title: "Reopen this held decision",
                        detail: "SampleHost is proving the reopen path through BASHostKit.",
                        promptSeed: "Take one slower pass before committing.",
                        riskLevel: .high,
                        reopenHint: "Reopen with more structure",
                        templateHint: "Use a cooling template before acting.",
                        interventionHistorySummary: "High-risk reopen requests should restore more friction."
                    )
                )
            }
        )
    }

    // MARK: - M573 (chapter 一百四十七 part 2) — iPhone real-device bench loop

    /// Toggle bench. If running, stops gracefully. If stopped,
    /// kicks off a Task that drives BASHostRuntime.startSession()
    /// in a loop and appends per-iteration JSONL rows to the app's
    /// Documents/iphone-bench/iterations.jsonl file.
    func toggleBench() {
        if benchIsRunning {
            benchTask?.cancel()
        } else {
            startBench()
        }
    }

    private func startBench() {
        benchIsRunning = true
        benchIterationsCompleted = 0
        benchAuditCodesTotal = 0
        benchStartTime = Date()
        benchLastError = nil
        benchOutputPath = SampleHostBenchHelpers
            .benchOutputURL().path

        // M573 (chapter 一百四十七 part 2 b) — keep screen on while
        // bench runs so iOS doesn't suspend the foreground app.
        // User must keep iPhone plugged to power for sustained 8h
        // run; iOS still suspends if user backgrounds the app.
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

        // M574 (chapter 一百四十九) — 1-hour bench cap.
        // **M604 chapter 一百七十四**: extended to 2h cap per user
        // "真机 跑2小时冒烟 ... 极大提高benchmark". Doubles
        // combinatorial prompt coverage from chapter 一百四十九's
        // 56,585 iterations / 100% coverage to ~113K iter
        // exercising substrate's 14 observation bundles + 7 typed
        // projection fields + 11 named per-layer coverage codes
        // (chapter 一百七十三 smoke pattern) ~113K times each.
        let maxDurationSeconds: TimeInterval = 7200

        let runtime = self.runtime
        let runner = self.benchRunner

        let benchStartedAt = Date()
        benchTask = Task { @MainActor [weak self] in
            var iter = 0
            while !Task.isCancelled {
                // 8h cap — gracefully halt
                if Date().timeIntervalSince(benchStartedAt)
                    > maxDurationSeconds
                {
                    break
                }
                // M574 (chapter 一百四十九) + chapter 一百五十 fix:
                // combinatorial prompt generator with coprime stride
                // scatter walk (defect #2 fix). Each iter gets a
                // unique prompt across 40,320-slot space, but adjacent
                // iter values produce distant signatures (all 8 tones
                // visited in first 8 iter vs only 1 with linear walk).
                //
                // **M604 chapter 一百七十四**: cycle 5 mutation variants
                // every iter via `mutationSeed = iter % 5`. Each
                // base prompt runs through all 5 surface perturbations
                // (none / hesitation / urgency / context-frame /
                // qualifier) over a 5-iter window. Empirical goal
                // (user "通过冒烟找到最合适程序化生成"): discover
                // which stride×mutation combos surface defects via
                // 2h bench observation. Stride doctrine: stride
                // changes every 11,300 iter (≈ 10min on iPhone 17e
                // 15 iter/sec sustained) cycling through 5 coprime
                // primes [5041, 5039, 5051, 5077, 7919] for full
                // multi-trial coverage of combinatorial subspaces.
                let strideRotation = [5041, 5039, 5051, 5077, 7919]
                let strideIndex = (iter / 11_300)
                    % strideRotation.count
                let chosenStride = strideRotation[strideIndex]
                let mutationSeed = iter % 5
                let g = SampleHostBenchPromptCatalog
                    .generateScatteredWithMutation(
                        iter: iter,
                        stride: chosenStride,
                        mutationSeed: mutationSeed)
                let prompt = g.prompt
                let signature = g.signature
                let t0 = Date()
                var auditCount = 0
                var permitMode = "unknown"
                var bodyLength = 0
                var status = "ok"
                var errorMessage: String?
                do {
                    // Map stake to risk level (combinatorial)
                    let riskLevel: BASHostRiskLevel
                    switch signature.stake {
                    case "low", "modest":
                        riskLevel = .low
                    case "high", "very-high":
                        riskLevel = .medium
                    case "irreversible",
                         "non-reversible-after-act":
                        riskLevel = .high
                    default:
                        riskLevel = .medium
                    }
                    let result = try runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: prompt,
                            title: "iphone-bench-\(iter)",
                            riskLevel: riskLevel))
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit
                            .mode.rawValue
                        let body = turn.thoughtFold
                            .compactSlots["body"]
                            ?? turn.thoughtFold
                                .compactSlots["summary"]
                            ?? ""
                        bodyLength = body.count
                    }
                } catch {
                    status = "error"
                    errorMessage = "\(error)"
                }
                let dur = Date().timeIntervalSince(t0)
                let row = SampleHostBenchRow(
                    timestamp: SampleHostBenchHelpers
                        .iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    bodyLength: bodyLength,
                    durationSeconds: dur,
                    status: status,
                    errorMessage: errorMessage,
                    stride: chosenStride,
                    mutationSeed: mutationSeed)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self?.benchLastError =
                        "write failed: \(error)"
                }
                iter += 1
                self?.benchIterationsCompleted = iter
                self?.benchAuditCodesTotal += auditCount
                // Flush every 50 iterations
                if iter % 50 == 0 {
                    await runner.flush()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                await Task.yield()
            }
            await runner.flush()
            await runner.close()
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
            self?.benchIsRunning = false
        }
    }

    // MARK: - shared helpers

    private static func perform(
        using runtime: BASHostRuntime,
        errorSink: (String?) -> Void,
        request: () throws -> BASHostSessionResult
    ) -> BASHostSessionResult {
        do {
            errorSink(nil)
            return try request()
        } catch {
            errorSink(String(describing: error))
            return fallbackResult(using: runtime)
        }
    }

    private static func fallbackResult(using runtime: BASHostRuntime) -> BASHostSessionResult {
        (try? runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Recover the host shell after an integration error.",
                title: "Integration Recovery",
                riskLevel: .low
            )
        )) ?? BASHostSessionResult(
            requestKind: .interactive,
            workflowProfile: .primary,
            currentBrain: BASHostCurrentBrain(
                workflowProfile: .primary,
                workflowTitle: "Primary",
                roleID: "samplehost.recovery",
                identityPosture: .reflective,
                identityInitiative: .guided,
                confidenceCeiling: 0.5,
                relationshipBoundary: "Fallback shell",
                boundaryHeadline: "SampleHost is holding a safe fallback state.",
                boundaryMode: .localOnlyAdvisory,
                boundaryConstraints: [.lockSensitiveMemory],
                calibrationStatus: .stable,
                calibrationAlerts: [],
                riskFlags: [],
                dominantGoals: ["Recover from host integration failure."],
                activeConstraints: ["integration-fallback"],
                retrievalTags: ["fallback"],
                verificationSummary: "samplehost/fallback",
                activeTemplateCount: 0,
                failureGuardCount: 0,
                evolutionPendingReviewCount: 0,
                evolutionRollbackReady: true
            ),
            projection: BASHostProjectionSummary(
                recordCount: 0,
                candidateCount: 0,
                recentEventCount: 0,
                activeTemplateIDs: [],
                failureGuardIDs: []
            ),
            activeSessionTitle: "Integration Recovery",
            notices: ["SampleHost recovered from an integration configuration error."],
            followUpActions: [],
            consoleSnapshot: BASHostConsoleSnapshot(
                overallSummary: "SampleHost recovered from an integration configuration error.",
                reports: []
            )
        )
    }

    // MARK: - M609 chapter 一百七十六 §176.13 — direct AFM foreground test
    //
    // The chapter 174 bench has bodyLength=0 in all 119K rows because
    // BASHostRuntime's L2 organ stage is stubbed (no AFM adapter
    // registered). chapter 176 §176.12 (I20 walkback) confirmed Mac
    // CLI cannot invoke AFM at all due to macOS 26 modelmanagerd
    // foreground-only architectural policy. iPhone is the only
    // realistic path: SampleHost.app foreground UI directly creates
    // a `LanguageModelSession` (FoundationModels framework) and
    // calls `respond(to:)`. This bypasses BAS substrate entirely
    // — pure AFM end-to-end smoke test.

    func runAFMTestNow() {
        guard !afmIsRunning else { return }
        afmIsRunning = true
        afmTestStatus = "starting…"
        afmTestOutput = ""
        afmTestDurationMs = 0
        let prompt = afmTestPrompt
        Task { @MainActor [weak self] in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                do {
                    let session = LanguageModelSession()
                    self?.afmTestStatus = "calling AFM…"
                    let started = Date()
                    let response = try await session.respond(to: prompt)
                    let elapsed = Date().timeIntervalSince(started)
                    self?.afmTestOutput = response.content
                    self?.afmTestDurationMs = elapsed * 1000
                    self?.afmTestStatus =
                        "ok — \(String(format: "%.0f", elapsed * 1000)) ms / \(response.content.count) chars"
                } catch {
                    self?.afmTestOutput = ""
                    self?.afmTestStatus = "error: \(error)"
                }
            } else {
                self?.afmTestStatus =
                    "AFM unavailable — needs iOS 26+ / macOS 26+"
            }
            #else
            self?.afmTestStatus =
                "AFM unavailable — FoundationModels framework not imported"
            #endif
            self?.afmIsRunning = false
        }
    }

    func updateAFMTestPrompt(_ newPrompt: String) {
        afmTestPrompt = newPrompt
    }

    // MARK: - M610 chapter 一百七十六 §176.14 — AFM 8h long-running bench
    //
    // User trigger (2026-05-05): "我想连续跑 afm 8小时" + "进化算法
    // 加强 程序化生成 极致 找到 所有 缺陷 bug 不足" + "我希望 大部分
    // 固定 数值 都可以 改成 完全 flexible 程序化 生成 而不是 死数值".
    //
    // Per-iter flow:
    //   1. Generate scattered+mutation prompt (chapter 173 corpus,
    //      coprime stride proven full-orbit)
    //   2. Run BASHostRuntime.startSession (substrate routing — gets
    //      14-layer audit codes + permit decision)
    //   3. If permit allows AND skipBlocked=true → call AFM directly
    //      via LanguageModelSession.respond(to:) for body
    //   4. Record both substrate decision + AFM body to JSONL
    //
    // All 7 numeric params are @Published flexibles per user "大部分
    // 固定数值 改 flexible 程序化生成":
    //   - duration (1.0..24.0 hours, default 8.0)
    //   - stride rotation (CSV, must be coprime to 40320, default 5)
    //   - rotation period (1000..50_000 iter, default 11_300)
    //   - mutation seed count (1..5, default 5)
    //   - JSONL rotation (1..100 MB, default 15)
    //   - AFM timeout (5..120s, default 30)
    //   - skip blocked (Bool, default true — don't waste AFM calls)
    //
    // Doctrine pin: doctrine-fixed values (sum-to-one weights / coprime
    // stride math / 4-tier orderings) NOT exposed as flexible —
    // they're not magic numbers, they're invariants (chapter 175 E
    // class). Only TRUE magic numbers exposed.

    func startAFMBench() {
        guard !afmBenchIsRunning else { return }
        // Sanitize and parse stride list once
        let strideRotation = afmBenchStrideRotationCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && gcd($0, 40_320) == 1 }
        guard !strideRotation.isEmpty else {
            afmBenchLastError = "stride rotation empty / no coprime entries"
            return
        }
        let durationSec = afmBenchDurationHours * 3600.0
        let rotationPeriod = max(1, afmBenchRotationPeriodIter)
        let mutationCount = max(1, min(5, afmBenchMutationSeedCount))
        let rotationBytes = max(1, afmBenchJSONLRotationMB) * 1024 * 1024
        let afmTimeoutSec = max(5, min(120, afmBenchAFMTimeoutSec))
        let skipBlocked = afmBenchSkipBlocked

        afmBenchIsRunning = true
        afmBenchIterations = 0
        afmBenchAFMSuccessCount = 0
        afmBenchAFMSkippedCount = 0
        afmBenchAFMErrorCount = 0
        afmBenchLastError = nil
        afmBenchStartTime = Date()
        afmBenchOutputPath = SampleHostBenchHelpers
            .afmBenchOutputDirURL().path

        let runtime = self.runtime
        afmBenchTask = Task { @MainActor [weak self] in
            let startedAt = Date()
            var iter = 0
            let runner = SampleHostAFMBenchJSONLRunner(
                rotationBytes: rotationBytes)
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) > durationSec {
                    break
                }
                let strideIndex = (iter / rotationPeriod)
                    % strideRotation.count
                let chosenStride = strideRotation[strideIndex]
                let mutationSeed = iter % mutationCount
                let g = SampleHostBenchPromptCatalog
                    .generateScatteredWithMutation(
                        iter: iter,
                        stride: chosenStride,
                        mutationSeed: mutationSeed)
                let prompt = g.prompt
                let signature = g.signature

                // Substrate routing
                let t0 = Date()
                var auditCount = 0
                var permitMode = "unknown"
                var afmBody: String = ""
                var afmStatus: String = "skipped"
                var afmDurationMs: Double = 0
                var errorMessage: String?
                let riskLevel: BASHostRiskLevel
                switch signature.stake {
                case "low", "modest":         riskLevel = .low
                case "high", "very-high":     riskLevel = .medium
                case "irreversible",
                     "non-reversible-after-act": riskLevel = .high
                default:                      riskLevel = .medium
                }
                do {
                    let result = try runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: prompt,
                            riskLevel: riskLevel))
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit.mode.rawValue
                    }
                } catch {
                    errorMessage = "substrate: \(error)"
                }

                // AFM body call (skip if permit blocks AND skipBlocked)
                let permitBlocks = permitMode == "block"
                    || permitMode == "delay"
                let shouldCallAFM = !(skipBlocked && permitBlocks)
                if shouldCallAFM {
                    #if canImport(FoundationModels)
                    if #available(iOS 26.0, macOS 26.0, *) {
                        let afmStarted = Date()
                        do {
                            let session = LanguageModelSession()
                            let response = try await session
                                .respond(to: prompt)
                            afmBody = response.content
                            afmStatus = "ok"
                            self?.afmBenchAFMSuccessCount += 1
                        } catch {
                            afmStatus = "afm-error"
                            errorMessage = (errorMessage ?? "")
                                + " afm: \(error)"
                            self?.afmBenchAFMErrorCount += 1
                        }
                        afmDurationMs = Date()
                            .timeIntervalSince(afmStarted) * 1000
                    } else {
                        afmStatus = "afm-unavailable-os"
                        self?.afmBenchAFMSkippedCount += 1
                    }
                    #else
                    afmStatus = "afm-unavailable-framework"
                    self?.afmBenchAFMSkippedCount += 1
                    #endif
                } else {
                    self?.afmBenchAFMSkippedCount += 1
                }

                let dur = Date().timeIntervalSince(t0)
                let row = SampleHostAFMBenchRow(
                    timestamp: SampleHostBenchHelpers.iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    stride: chosenStride,
                    mutationSeed: mutationSeed,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    afmStatus: afmStatus,
                    afmBody: afmBody,
                    afmBodyLength: afmBody.count,
                    afmDurationMs: afmDurationMs,
                    totalDurationSeconds: dur,
                    errorMessage: errorMessage)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self?.afmBenchLastError = "jsonl: \(error)"
                }
                iter += 1
                self?.afmBenchIterations = iter
                // Cooperative cancel; yield to UI for status updates
                if iter % 8 == 0 { await Task.yield() }
            }
            await runner.close()
            self?.afmBenchIsRunning = false
        }
    }

    func stopAFMBench() {
        afmBenchTask?.cancel()
        afmBenchTask = nil
        afmBenchIsRunning = false
    }

    func updateAFMBenchDurationHours(_ newValue: Double) {
        afmBenchDurationHours = max(0.1, min(24.0, newValue))
    }

    func updateAFMBenchStrideCSV(_ newValue: String) {
        afmBenchStrideRotationCSV = newValue
    }

    func updateAFMBenchRotationPeriod(_ newValue: Int) {
        afmBenchRotationPeriodIter = max(1_000, min(100_000, newValue))
    }

    func updateAFMBenchMutationCount(_ newValue: Int) {
        afmBenchMutationSeedCount = max(1, min(5, newValue))
    }

    func updateAFMBenchSkipBlocked(_ newValue: Bool) {
        afmBenchSkipBlocked = newValue
    }
}

// M797 chapter 二百十六 — `SampleHostAFMBenchRow` + helpers
// extension + `SampleHostAFMBenchJSONLRunner` extracted to
// dedicated file `SampleHostBenchJSONLRunners.swift` (alongside
// the symmetric hybrid runner).

// M800 chapter 二百十九 — `gcd(_:_:)` pure helper extracted to
// dedicated file `SampleHostBenchHelpers.swift` (promoted from
// `private` to module-internal so cross-file callers share the
// doctrine without duplicating).

// MARK: - M619 chapter 一百七十七 §177 — Hybrid bench row + runner

// M796 chapter 二百十五 — `HybridBenchTuning` + `HybridBenchConfig`
// + `SmokeMode` + 3 named presets extracted to dedicated file
// `SampleHostHybridBenchConfig.swift` (single-source-of-truth for
// bench-config invariant per chapter 二百十一 doctrine).

/// M711 chapter 一百九十一 — 14-layer smoke profile.
/// Maps each BAS substrate layer (L1 lifecycle wake → L14
/// reflection) to a `(signature, risk, workflow)` tuple that's
/// most likely to exercise that layer's distinctive behavior.
/// Bench in `.fourteenLayer` mode cycles through all 14 each
/// `mutationSeedCount * 14` iters so a 2h run with ~36K iters
/// gets ~2,500 samples per layer.
// M794 chapter 二百十三 — `FourteenLayerSmokeProfile` enum +
// Profile struct + layers[] + profile(forIter:) + profile(for-
// LayerIndex:) + Equatable consolidated to dedicated file
// `SampleHostFourteenLayerSmokeProfile.swift`. Pre-this-batch the
// type was split across 3 files (this file's main body + Safety-
// Kit extension + IterContext Equatable conformance). Now single-
// source-of-truth (chapter 二百十一 doctrine).

// M795 chapter 二百十四 — `SampleHostHybridBenchRow` schema +
// `SAMPLE_HOST_HYBRID_BENCH_ROW_SCHEMA_VERSION` constant extracted
// to dedicated file `SampleHostHybridBenchRow.swift`. Future
// schema bumps go to one file (single-source-of-truth doctrine,
// chapter 二百十一).

// M792 chapter 二百十一 — `SampleHostHybridDispatchPolicy` and
// `SampleHostHybridDispatchCanned` extracted to dedicated file
// `SampleHostHybridDispatchPolicy.swift`. Bench loop calls
// `derive(permitMode:forceSingleLLM:)` (single source of truth
// for chapter 一百七十八 mapping + chapter 二百八 .rawLLM bypass).

// M797 chapter 二百十六 — hybrid bench helpers extension +
// `SampleHostHybridBenchJSONLRunner` extracted to dedicated file
// `SampleHostBenchJSONLRunners.swift` (alongside symmetric AFM
// runner).

// MARK: - M619 chapter 一百七十七 §177 — Hybrid bench methods on SampleHostModel

extension SampleHostModel {
    /// Single-prompt hybrid test (UI panel). Predicts route via
    /// CoreML, calls chosen LLM, falls back to other on error.
    ///
    /// **M627 deep-review note #12** — by design this single-prompt
    /// path does NOT take the v0.2 confidence-aware uncertain-zone
    /// dual-LLM branch (chosen→fallback only). Rationale: the UI
    /// panel is a "tap once + see it work" smoke probe. Always
    /// calling both LLMs would double the latency that the user
    /// is staring at, for marginal benefit on a single sample.
    /// Bench path (`startHybridBench`) still uses dual-LLM voting
    /// in the uncertain zone for the real signal collection.
    /// Hardcoded features (agentic / creative / modest / …) are
    /// also intentional: it's a smoke test, not signature-driven
    /// inference. Bench rows derive features from the actual
    /// generated prompt's signature.
    func runHybridSinglePrompt() {
        let prompt = afmTestPrompt
        let features = ChengluPromptFeatures(
            tone: "agentic",
            domain: "creative",
            stake: "modest",
            timeframe: "minutes",
            confidant: "decision-system",
            askShape: "single-action",
            mutationSeed: 0)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.hybridSinglePromptStatus = "predicting…"
            // M659 chapter 一百八十三 — call ALL heads for the
            // single-prompt path so UI surfaces full meridian
            // before LLM fires (router stays the load-bearing
            // decision; other 4 outputs are observability hints).
            let decision = ChengluPreflightInference.shared
                .predictOrNil(features: features)
            let multiHead = ChengluMultiHeadInference.shared
                .predictOrNil(features: features)
            // Reset previous inline values
            self.hybridSinglePromptBlockProb = nil
            self.hybridSinglePromptLengthChars = nil
            self.hybridSinglePromptLatencyMs = nil
            self.hybridSinglePromptVerbosityProb = nil
            if let mh = multiHead {
                self.hybridSinglePromptBlockProb = mh.blockProbability
                self.hybridSinglePromptLengthChars =
                    mh.predictedBodyLength
                self.hybridSinglePromptLatencyMs =
                    mh.predictedDurationMs
                self.hybridSinglePromptVerbosityProb =
                    mh.verbosityProbability
            }
            guard let d = decision else {
                self.hybridSinglePromptStatus = "router unavailable"
                return
            }
            self.hybridSinglePromptProb = d.afmSuccessProbability
            self.hybridSinglePromptRoute = d.route.rawValue
            self.hybridSinglePromptStatus =
                "router: \(d.route.rawValue) (prob \(String(format: "%.3f", d.afmSuccessProbability))) calling…"
            // Try chosen LLM
            do {
                if d.route == .afm {
                    let body = try await self.callAFM(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok afm (predicted) \(body.count) chars"
                } else {
                    let body = try await self.callGemma(prompt: prompt)
                    self.hybridSinglePromptOutput = body
                    self.hybridSinglePromptStatus =
                        "ok gemma (predicted) \(body.count) chars"
                }
            } catch {
                // Fallback to the other LLM
                self.hybridSinglePromptStatus =
                    "first try failed (\(d.route.rawValue)), trying fallback…"
                do {
                    let body: String
                    if d.route == .afm {
                        body = try await self.callGemma(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok gemma fallback \(body.count) chars (router miss)"
                    } else {
                        body = try await self.callAFM(prompt: prompt)
                        self.hybridSinglePromptStatus =
                            "ok afm fallback \(body.count) chars (router miss)"
                    }
                    self.hybridSinglePromptOutput = body
                } catch {
                    self.hybridSinglePromptStatus =
                        "both failed: \(error)"
                    self.hybridSinglePromptOutput = ""
                }
            }
        }
    }

    /// M780 chapter 二百七 — DEEP-REVIEW FIX C2 helper.
    /// Increment timeoutCount via applyIfActive when error is a
    /// LLM-timeout. Stale-generation tasks see no-op. Called from
    /// every bench-loop catch where callAFMWithTimeout /
    /// callGemmaWithTimeout might have thrown.
    @MainActor
    fileprivate func recordTimeoutIfApplicable(
        _ error: Error, generation: Int
    ) {
        if case SampleHostBenchLLMTimeoutError.timeoutExceeded = error {
            applyIfActive(generation) {
                self.hybridBenchLLMTimeoutCount += 1
            }
        }
    }

    /// M735 chapter 一百九十五 — wrap callAFM with per-iter
    /// timeout. Bench loop uses this in the .singleLLM confident
    /// path so a hung AFM call (~30s+) doesn't freeze the whole
    /// 10h run; it bails after `seconds` and lets the fallback
    /// path try Gemma.
    ///
    /// Doctrine: TIMEOUT IS BAIL-OUT, not session-killer. Throws
    /// `SampleHostBenchLLMTimeoutError.timeoutExceeded` so the
    /// bench-loop catch can record a clean failure. `hybridBenchLLMTimeoutCount`
    /// is incremented so the dashboard shows live timeout rate.
    @MainActor
    fileprivate func callAFMWithTimeout(
        prompt: String, seconds: Double
    ) async throws -> String {
        let llmTask = Task { [weak self] () async throws -> String in
            guard let self else {
                throw NSError(domain: "model-deinit", code: -1)
            }
            return try await self.callAFM(prompt: prompt)
        }
        let timeoutTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(0.001, seconds) * 1_000_000_000))
            llmTask.cancel()
        }
        do {
            let body = try await llmTask.value
            timeoutTask.cancel()
            return body
        } catch {
            timeoutTask.cancel()
            if llmTask.isCancelled {
                // M780 chapter 二百七 — DEEP-REVIEW FIX C2:
                // counter mutation moved to bench-loop catch
                // wrapped in applyIfActive(myGen). Helper is
                // pure error path; caller handles state.
                throw SampleHostBenchLLMTimeoutError
                    .timeoutExceeded(seconds: seconds)
            }
            throw error
        }
    }

    /// M735 chapter 一百九十五 — Gemma equivalent of
    /// `callAFMWithTimeout`. Same doctrine.
    @MainActor
    fileprivate func callGemmaWithTimeout(
        prompt: String, seconds: Double
    ) async throws -> String {
        let llmTask = Task { [weak self] () async throws -> String in
            guard let self else {
                throw NSError(domain: "model-deinit", code: -1)
            }
            return try await self.callGemma(prompt: prompt)
        }
        let timeoutTask = Task {
            try? await Task.sleep(
                nanoseconds: UInt64(max(0.001, seconds) * 1_000_000_000))
            llmTask.cancel()
        }
        do {
            let body = try await llmTask.value
            timeoutTask.cancel()
            return body
        } catch {
            timeoutTask.cancel()
            if llmTask.isCancelled {
                // M780 chapter 二百七 — DEEP-REVIEW FIX C2:
                // counter mutation moved to bench-loop catch
                // wrapped in applyIfActive(myGen). Helper is
                // pure error path; caller handles state.
                throw SampleHostBenchLLMTimeoutError
                    .timeoutExceeded(seconds: seconds)
            }
            throw error
        }
    }

    /// Call AFM with a prompt. Throws on error/guardrail.
    private func callAFM(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return response.content
        }
        #endif
        throw NSError(domain: "AFMUnavailable", code: -1)
    }

    /// Call Gemma 4 E2B (MLX) with a prompt. Lazy-loads on first
    /// call + applies LoRA M247 chat-template adapter (chapter 176
    /// §176.10 — 3.6× better convergence + learned [RISK]/[NEEDS_PERMIT]
    /// markers). Throws on error.
    ///
    /// M627 deep-review fix #2 + #4: load is gated through a single
    /// in-flight Task so concurrent callers share, and LoRA load
    /// status is tracked separately from adapter readiness so a
    /// failed LoRA doesn't poison subsequent retries.
    private func callGemma(prompt: String) async throws -> String {
        #if canImport(BASMLXAdapter)
        let adapter = try await ensureGemmaAdapter()
        let request = BASOrganRequest(
            requestID: "hybrid-prompt",
            role: .scout,
            preset: .scout,
            instruction: prompt)
        let draft = try await adapter.draft(request)
        return draft.body
        #else
        throw NSError(
            domain: "GemmaUnavailable",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "BASMLXAdapter not built"])
        #endif
    }

    #if canImport(BASMLXAdapter)
    /// Singleton-load gate — concurrent callers share one in-flight
    /// Task instead of racing on `if gemmaAdapter == nil` (review #2).
    private func ensureGemmaAdapter() async throws -> MLXOrganAdapter {
        if let existing = gemmaAdapter { return existing }
        if let inFlight = gemmaLoadInFlight {
            return try await inFlight.value
        }
        let task = Task { [weak self] () throws -> MLXOrganAdapter in
            // Off-actor work — we don't capture self's actor here.
            let adapter = MLXOrganAdapter(
                model: MLXModelCatalog.gemma4_E2B_4bit)
            try await adapter.loadModel()
            await MainActor.run { [weak self] in
                self?.hybridGemmaLoadStatus = "model loaded, loading LoRA M247…"
            }
            // v0.3 — load LoRA M247 adapter from app bundle
            var loraOK = false
            if let loraURL = Bundle.main.url(
                forResource: "qinao_curriculum_lora_m247",
                withExtension: "safetensors")
            {
                do {
                    try await adapter.loadAdapter(from: loraURL)
                    loraOK = true
                } catch {
                    // Non-fatal — bare Gemma still works (review #4)
                    await MainActor.run { [weak self] in
                        self?.hybridGemmaLoadStatus =
                            "lora-load-failed: \(error)"
                    }
                }
            }
            try await adapter.prewarm()
            await MainActor.run { [weak self] in
                self?.gemmaLoraLoaded = loraOK
                self?.hybridGemmaLoadStatus = loraOK
                    ? "ready (with LoRA M247)"
                    : "ready (bare Gemma, NO LoRA)"
            }
            return adapter
        }
        gemmaLoadInFlight = task
        hybridGemmaLoadStatus = "loading model…"
        do {
            let adapter = try await task.value
            gemmaAdapter = adapter
            gemmaLoadInFlight = nil
            return adapter
        } catch {
            gemmaLoadInFlight = nil  // Allow retry next call
            throw error
        }
    }
    #endif

    /// Update prompt text for single-prompt hybrid test.
    /// (Reuses afmTestPrompt setter.)

    /// Start long-running hybrid bench (8h default).
    func startHybridBench() {
        guard !hybridBenchIsRunning else { return }
        let strideRotation = hybridBenchStrideRotationCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 && gcd($0, 40_320) == 1 }
        guard !strideRotation.isEmpty else {
            hybridBenchLastError = "stride CSV empty / no coprime entries"
            return
        }
        let durationSec = hybridBenchDurationHours * 3600.0
        let rotationPeriod = max(1, hybridBenchRotationPeriodIter)
        let mutationCount = max(1, min(5, hybridBenchMutationSeedCount))
        let rotationBytes = max(1, hybridBenchJSONLRotationMB) * 1024 * 1024

        // M627 deep-review fix #3 — defensively cancel any
        // previous task before starting (Stop→Start race guard).
        // The previous task may still be in its loop (finishing
        // an iter); cancellation propagates so it bails out.
        hybridBenchTask?.cancel()
        hybridBenchGeneration += 1
        let myGen = hybridBenchGeneration

        hybridBenchIsRunning = true
        hybridBenchIterations = 0
        hybridBenchAFMOk = 0
        hybridBenchGemmaOk = 0
        hybridBenchAFMFallbackToGemmaOk = 0
        hybridBenchGemmaFallbackToAFMOk = 0
        hybridBenchBothFailed = 0
        hybridBenchRouterHits = 0
        hybridBenchRouterMisses = 0
        // M628/M630 chapter 一百七十八 reset
        hybridBenchSubstrateSkipBlock = 0
        hybridBenchSubstrateSkipReplace = 0
        hybridBenchSubstrateSkipDelay = 0
        hybridBenchSubstrateBothLLMs = 0
        hybridBenchSubstrateLocalOnly = 0
        hybridBenchSubstrateDraftOnly = 0
        hybridBenchPostLLMShifted = 0
        // M635 chapter 一百七十九 reset
        hybridBenchPermitPredictHits = 0
        hybridBenchPermitPredictMisses = 0
        // M642 chapter 一百八十 reset + M669 Welford running
        // M689 chapter 一百八十八 — B8 retire: Sum properties gone.
        hybridBenchLengthMAECount = 0
        hybridBenchLengthMAERunning = 0
        hybridBenchLatencyMAECount = 0
        hybridBenchLatencyMAERunningMs = 0
        // M661 chapter 一百八十三 reset
        hybridBenchVerbosityCorrect = 0
        hybridBenchVerbosityWrong = 0
        // M727 chapter 一百九十三 reset live anomaly counters
        hybridBenchStuckSubstrateCount = 0
        hybridBenchStuckLLMCount = 0
        hybridBenchPauseSkippedCount = 0
        hybridBenchAdversarialFiredCount = 0
        hybridBenchDriftAlarmCount = 0
        // M735 chapter 一百九十五 reset
        hybridBenchLLMTimeoutCount = 0
        // M744 chapter 一百九十八 reset
        hybridBenchCoolingSleepCount = 0
        // M745 chapter 一百九十八 reset thermal counters
        hybridBenchLastThermalRaw = "unknown"
        hybridBenchThermalNominalIters = 0
        hybridBenchThermalFairIters = 0
        hybridBenchThermalSeriousIters = 0
        hybridBenchThermalCriticalIters = 0
        hybridBenchLastError = nil
        hybridBenchStartTime = Date()
        hybridBenchOutputPath = SampleHostBenchHelpers
            .hybridBenchOutputDirURL().path

        let runtime = self.runtime
        // M718 chapter 一百九十二 — anomaly watcher (fresh per-bench).
        // M731 chapter 一百九十四 — windowSize from @Published flex.
        // M735 chapter 一百九十五 — LLM timeout from @Published flex.
        let anomalyWindowCaptured = self.hybridBenchAnomalyWindowSize
        let driftThresholdCaptured = self.hybridBenchDriftSigmaThreshold
        let mutationProbCaptured = self.hybridBenchMutationProbability
        let checkpointEveryNCaptured = self.hybridBenchCheckpointEveryNIters
        let llmTimeoutCaptured = self.hybridBenchLLMTimeoutSeconds
        let pauseOnSeriousCaptured = self.hybridBenchPauseOnSerious
        let coolingEveryNCaptured = self.hybridBenchCoolingEveryNIters
        let coolingSleepSecondsCaptured = self.hybridBenchCoolingSleepSeconds
        // M776 chapter 二百六 — benign smokeMode auto-forces
        // .primary workflow. Chapter 205 verified .benign + default
        // .reflective = STILL 100% substrate-skip (delay 87.5% /
        // block 12.5%) because .reflective always defaults to
        // .delay. Benign mode IS for training-data accumulation;
        // .reflective + .benign is a contradictory operator config.
        // Auto-force .primary removes the user-error path.
        let workflowProfileCaptured: BASHostWorkflowProfile = {
            if self.hybridBenchSmokeMode == .benign {
                return .primary  // training-data accumulation
            }
            return self.hybridBenchWorkflowProfile
        }()
        let anomalyWatcher = SampleHostBenchAnomalyWatcher(
            windowSize: anomalyWindowCaptured)
        // M721 chapter 一百九十二 — drift monitor on length-MAE
        // residual (Welford std-dev). Per-iter sigma vs. running
        // mean attached to row + flagged when > 3-sigma.
        let lengthDriftMonitor = SampleHostBenchDriftMonitor()
        let latencyDriftMonitor = SampleHostBenchDriftMonitor()
        let benchStartIso = SampleHostBenchHelpers.iso8601(Date())
        let strideCSVCaptured = strideRotation
            .map(String.init).joined(separator: ",")
        let mutationCountCaptured = mutationCount
        let durationHoursCaptured = durationSec / 3600.0
        // M722 chapter 一百九十二 — write checkpoint every N iters.
        // M731 chapter 一百九十四 — N from @Published flex.
        let checkpointEveryN: Int = checkpointEveryNCaptured
        hybridBenchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startedAt = Date()
            var iter = 0
            let runner = SampleHostHybridBenchJSONLRunner(
                rotationBytes: rotationBytes)
            // chapter 二百九 / M790 — adaptive thermal cooldown.
            // Persists across iters of THIS bench task; a fresh
            // Stop→Start cycle gets a brand-new task and a fresh
            // cooldown (zero streak), preserving chapter 二百七
            // generation-guard doctrine.
            var cooldown = SampleHostThermalCooldown()
            while !Task.isCancelled {
                if Date().timeIntervalSince(startedAt) > durationSec {
                    break
                }
                // M791 chapter 二百十 — per-iter context derive is
                // delegated to `SampleHostBenchIterContext.derive(...)`,
                // a pure value type covering chapter 一百九十一 (14-
                // layer override), 一百九十二 (heavy-tailed pressure +
                // adversarial mutator), 二百五 (benign catalog), 二百
                // 八 (.rawLLM no-override) doctrines. Bench loop reads
                // back the typed context fields for the row build.
                let smokeMode = self.hybridBenchSmokeMode
                let iterContext = SampleHostBenchIterContext.derive(
                    iter: iter,
                    rotationPeriod: rotationPeriod,
                    strideRotation: strideRotation,
                    mutationCount: mutationCount,
                    smokeMode: smokeMode,
                    mutationProbability: mutationProbCaptured)
                let chosenStride = iterContext.chosenStride
                let mutationSeed = iterContext.mutationSeed
                let layerProfile = iterContext.layerProfile
                let pressureProfile = iterContext.pressureProfile
                let adversarialKind = iterContext.adversarialKind
                let prompt = iterContext.prompt
                let signature = iterContext.signature

                // M703 chapter 一百九十 — capture pressure context
                // BEFORE substrate work (so it reflects situation
                // at iter START, not perturbation iter caused).
                // M717 chapter 一百九十二 — single-source via
                // `SampleHostBenchThermalGate.currentDeviceState()`.
                let device = SampleHostBenchThermalGate.currentDeviceState()
                let thermalRaw = device.thermal
                let batteryRaw = device.battery
                let lowPower = device.lowPower
                let batteryStateRaw = device.batteryState
                let hourCaptured = Calendar.current.component(
                    .hour, from: Date())

                // M745 chapter 一百九十八 — update live thermal
                // surface + per-state iter counts for dashboard.
                applyIfActive(myGen) {
                    self.hybridBenchLastThermalRaw = thermalRaw
                    switch thermalRaw {
                    case "nominal":
                        self.hybridBenchThermalNominalIters += 1
                    case "fair":
                        self.hybridBenchThermalFairIters += 1
                    case "serious":
                        self.hybridBenchThermalSeriousIters += 1
                    case "critical":
                        self.hybridBenchThermalCriticalIters += 1
                    default: break
                    }
                }

                // M717 chapter 一百九十二 — thermal/battery gate.
                // If gate says pause, emit a paused-row WITHOUT
                // running substrate or LLM. Sleep 30s then re-loop.
                // Doctrine: gate is INSIDE the iter loop, so the
                // bench duration timer keeps running; effectively
                // we lose iters during pause but never burn the
                // device or get throttled mid-LLM call.
                let gateDecision = SampleHostBenchThermalGate.decide(
                    thermalRaw: thermalRaw,
                    batteryLevel: batteryRaw,
                    lowPowerMode: lowPower,
                    batteryStateRaw: batteryStateRaw,
                    pauseOnSerious: pauseOnSeriousCaptured)
                // chapter 二百九 / M790 — observe BEFORE branching so
                // any `.run` iter resets pauseStreak to 0 (the next
                // pause starts fresh at the 30s ladder rung).
                cooldown.observe(decision: gateDecision)
                if case .pause(let reason) = gateDecision {
                    // M727 chapter 一百九十三 — live counter
                    applyIfActive(myGen) {
                        self.hybridBenchPauseSkippedCount += 1
                    }
                    _ = reason  // (used in row construction below)
                    // Emit paused-row so JSONL captures the gap
                    // (downstream replay can spot the pause window).
                    let pausedRow = SampleHostHybridBenchRow(
                        timestamp: SampleHostBenchHelpers.iso8601(Date()),
                        iteration: iter,
                        seed: iter,
                        stride: chosenStride,
                        mutationSeed: mutationSeed,
                        signature: signature,
                        prompt: "",
                        auditCodeCount: 0,
                        permitMode: "paused-by-thermal-gate",
                        routerVersion: "n/a",
                        routerPredictedRoute: "n/a",
                        routerProbability: 0,
                        firstTriedLLM: "none",
                        firstTriedStatus: "paused-by-thermal-gate",
                        firstTriedBody: "",
                        firstTriedDurationMs: 0,
                        fallbackTriedLLM: nil,
                        fallbackStatus: nil,
                        fallbackBody: nil,
                        fallbackDurationMs: nil,
                        actualRoute: "paused-\(reason)",
                        routerHit: false,
                        totalDurationSeconds: 0,
                        errorMessage: nil,
                        dispatchPolicy: nil,
                        dispatchTaken: nil,
                        draftOnly: nil,
                        llmSkipped: true,
                        postLLMPermitMode: nil,
                        postLLMAuditCodeCount: nil,
                        postLLMShifted: nil,
                        permitPredictBlockProb: nil,
                        permitPredictClass: nil,
                        permitPredictAgreement: nil,
                        permitPredictDetailedAgreement: nil,
                        routerOverridden: true,
                        lengthPredicted: nil,
                        lengthError: nil,
                        latencyPredictedMs: nil,
                        latencyErrorMs: nil,
                        verbosityProbability: nil,
                        verbosityCorrect: nil,
                        thermalState: thermalRaw,
                        batteryLevel: batteryRaw,
                        lowPowerMode: lowPower,
                        hourOfDay: hourCaptured,
                        smokeMode: smokeMode.rawValue,
                        targetLayer: layerProfile?.layerIndex,
                        targetLayerName: layerProfile?.layerName,
                        anomalyFlags: [
                            "thermal-gate-paused:\(reason)",
                            "cooldown:\(cooldown.ladderLabel())",
                            "cooldown-streak:\(cooldown.pauseStreak)",
                        ],
                        pressureProfile: pressureProfile,
                        adversarialKind: adversarialKind?.rawValue,
                        driftSigma: nil,
                        pauseSkipped: true)
                    do {
                        try await runner.appendRow(pausedRow)
                    } catch {
                        self.hybridBenchLastError = "jsonl-paused: \(error)"
                    }
                    iter += 1
                    if self.hybridBenchGeneration != myGen { break }
                    if self.hybridBenchGeneration == myGen {
                        self.hybridBenchIterations = iter
                    }
                    // chapter 二百九 / M790 — adaptive cooldown ladder
                    // (30s / 60s / 120s / 300s ceiling) replaces the
                    // fixed 30s sleep. chapter 二百八 2h bench surfaced
                    // 93% pause rate (236/253 iters) because iPhone
                    // 17e holds `.serious` thermal for minutes-to-hours;
                    // fixed 30s sleep just polled wastefully and burned
                    // battery. Adaptive ladder lets the device actually
                    // radiate heat between thermal re-checks while
                    // keeping a 5-min ceiling so a cooled ambient
                    // unlocks the bench within reasonable latency.
                    // Yield back if cancelled (Task.sleep is throwing
                    // on cancellation).
                    try? await Task.sleep(
                        nanoseconds: cooldown.sleepNanoseconds())
                    continue
                }

                // Substrate routing
                let t0 = Date()
                var auditCount = 0
                var permitMode = "unknown"
                let riskLevel: BASHostRiskLevel
                // M774 chapter 二百五 — benign mode forces low risk.
                // Even though benign signature has stake="low" already,
                // explicit override is doctrine-clearer + future-proof
                // against signature drift.
                if smokeMode == .benign {
                    riskLevel = .low
                } else {
                    switch signature.stake {
                    case "low", "modest": riskLevel = .low
                    case "high", "very-high": riskLevel = .medium
                    case "irreversible", "non-reversible-after-act":
                        riskLevel = .high
                    default: riskLevel = .medium
                    }
                }
                do {
                    // M691 chapter 一百八十八 — B3-extended (HIGH):
                    // run substrate.startSession off-MainActor via
                    // Task.detached. BASHostRuntime is Sendable
                    // (`public struct BASHostRuntime: Sendable`),
                    // so cross-actor capture is type-system safe.
                    // Bench loop's @MainActor isolation is needed
                    // only for @Published mutations + UI binds;
                    // substrate eval has no @Published touch.
                    // Pre-fix: every iter blocked main thread for
                    // substrate eval (~50-100ms). Post-fix:
                    // background thread. UI stays responsive.
                    // M767 chapter 二百四 — workflowProfile from
                    // @Published flex (captured at start). Default
                    // .reflective (chapter 178+ baseline); .primary
                    // for LLM-data accumulation runs.
                    let request = BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: workflowProfileCaptured,
                        surface: .application,
                        prompt: prompt,
                        riskLevel: riskLevel)
                    let result = try await Task.detached(
                        priority: .userInitiated
                    ) {
                        try runtime.startSession(request)
                    }.value
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit.mode.rawValue
                    }
                } catch {
                    permitMode = "substrate-error"
                }

                // Router predict
                let features = ChengluPromptFeatures(
                    tone: signature.tone,
                    domain: signature.domain,
                    stake: signature.stake,
                    timeframe: signature.timeframe,
                    confidant: signature.confidant,
                    askShape: signature.askShape,
                    mutationSeed: mutationSeed)
                let decision = ChengluPreflightInference.shared
                    .predictOrNil(features: features)
                let routerRoute = decision?.route ?? .afm
                let routerProb = decision?.afmSuccessProbability ?? 0.5
                let routerVersion = decision?.modelVersion ?? "missing"
                // v0.2 — confidence-aware: in uncertain zone, call
                // BOTH LLMs and pick longer body. Outside uncertain
                // zone, use chosen LLM with fallback safety net.
                let routerConfidence = decision?.confidence ?? .high

                // M628 chapter 一百七十八 — derive substrate
                // dispatch policy BEFORE calling LLM. Substrate's
                // permit mode shapes WHETHER + HOW we call LLM.
                // M792 chapter 二百十一 — single-source derive:
                // chapter 一百七十八 permit-mode mapping +
                // chapter 二百八 .rawLLM bypass (ADR-006: bench
                // observability ONLY, data never feeds production
                // permit decisions).
                let dispatchPolicy =
                    SampleHostHybridDispatchPolicy.derive(
                        permitMode: permitMode,
                        forceSingleLLM: smokeMode == .rawLLM)

                // M649 chapter 一百八十一 — try MultiHead FIRST
                // (1 inference call, 4 outputs). Fall back to
                // separate per-head models if MultiHead missing.
                let multiHead = ChengluMultiHeadInference
                    .shared.predictOrNil(features: features)

                // M635 chapter 一百七十九 — 2nd CoreML head.
                // Permit predict: prefer MultiHead's block_prob;
                // fall back to standalone PermitPredict head if
                // MultiHead unavailable.
                let permitPredictBlockProb: Double?
                let permitPredictClass: String?
                if let mh = multiHead {
                    permitPredictBlockProb = mh.blockProbability
                    permitPredictClass = mh.blockProbability >= 0.5
                        ? "block" : "non-block"
                } else {
                    let permitDecision = ChengluPermitPredictInference
                        .shared.predictOrNil(features: features)
                    permitPredictBlockProb =
                        permitDecision?.blockProbability
                    permitPredictClass =
                        permitDecision?.predictedClass.rawValue
                }
                // Agreement: predicted class matches substrate's
                // actual .block decision. nil if model unavailable.
                let permitPredictAgreement: Bool? = {
                    guard let cls = permitPredictClass
                    else { return nil }
                    let actualIsBlock = (permitMode == "block")
                    let predictedIsBlock = (cls == "block")
                    return actualIsBlock == predictedIsBlock
                }()
                // M675 chapter 一百八十六 — B7 fix (HIGH):
                // record the 2-tuple "predicted-class:actual-permit"
                // so analyses get the 9-way confusion matrix info.
                // Example values: "block:block" / "non-block:delay"
                // / "non-block:answer" / "block:replace".
                let permitPredictDetailedAgreement: String? = {
                    guard let cls = permitPredictClass
                    else { return nil }
                    return "\(cls):\(permitMode)"
                }()
                if let agree = permitPredictAgreement {
                    if agree {
                        applyIfActive(myGen) { self.hybridBenchPermitPredictHits += 1 }
                    } else {
                        applyIfActive(myGen) { self.hybridBenchPermitPredictMisses += 1 }
                    }
                }

                // M638-M641 chapter 一百八十 — 3rd + 4th CoreML
                // heads. M649 chapter 一百八十一 — prefer
                // MultiHead, fall back to separate heads.
                let lengthPredicted: Double?
                let latencyPredictedMs: Double?
                if let mh = multiHead {
                    lengthPredicted = mh.predictedBodyLength
                    latencyPredictedMs = mh.predictedDurationMs
                } else {
                    let lengthDecision = ChengluRegressionHeadInference
                        .lengthHead.predictOrNil(features: features)
                    let latencyDecision = ChengluRegressionHeadInference
                        .latencyHead.predictOrNil(features: features)
                    lengthPredicted = lengthDecision?.predicted
                    latencyPredictedMs = latencyDecision?.predicted
                }

                // Call chosen LLM
                var firstTriedLLM = routerRoute.rawValue
                var firstStatus = "ok"
                var firstBody = ""
                var firstDurationMs: Double = 0
                var fallbackLLM: String?
                var fallbackStatus: String?
                var fallbackBody: String?
                var fallbackDurationMs: Double?
                var actualRoute = ""
                var routerHit = true
                // M666 chapter 一百八十五 — B1 (CRITICAL):
                // routerOverridden=true means substrate bypassed
                // router prediction (skip / bothLLMs / localOnly).
                // Default false; set true in the override branches
                // below. routerHits/Misses counters now tally only
                // when overridden==false, so `genuine router
                // accuracy` analysis filters by this field.
                var routerOverridden: Bool = false
                var errorMessage: String?
                var dispatchTaken: String = dispatchPolicy.rawValue
                var llmSkipped: Bool = false
                var draftOnlyFlag: Bool = false

                let firstStart = Date()

                // M628 — substrate-skip path: when permit is
                // .block / .replace / .delay, do NOT call LLM.
                // Return canned response. This is THE 真实 path
                // for "substrate decides we shouldn't ask LLM".
                if dispatchPolicy.skipsLLM {
                    let canned = dispatchPolicy.cannedResponse ?? ""
                    firstTriedLLM = "none-substrate-skip"
                    firstBody = canned
                    firstStatus = "ok-substrate-skip"
                    // M671 chapter 一百八十五 — B11 (MEDIUM) fix:
                    // skip-path duration is meaningless (just the
                    // canned-string assignment latency). Set to 0
                    // explicitly so JSONL analysis can grep
                    // `firstTriedDurationMs == 0 && llmSkipped` to
                    // identify skip rows cleanly.
                    firstDurationMs = 0
                    actualRoute = "skipped-by-substrate-\(dispatchPolicy.rawValue.dropFirst("skip-".count))"
                    llmSkipped = true
                    dispatchTaken = dispatchPolicy.rawValue
                    // M666 chapter 一百八十五 — B1 (CRITICAL):
                    // skip path bypasses router; mark overridden
                    // so router-accuracy analysis filters this
                    // row out. Pre-fix: routerHits += 1 here
                    // contaminated genuine router-hit signal.
                    routerOverridden = true
                    switch dispatchPolicy {
                    case .skipBlock:
                        applyIfActive(myGen) { self.hybridBenchSubstrateSkipBlock += 1 }
                    case .skipReplace:
                        applyIfActive(myGen) { self.hybridBenchSubstrateSkipReplace += 1 }
                    case .skipDelay:
                        applyIfActive(myGen) { self.hybridBenchSubstrateSkipDelay += 1 }
                    default: break
                    }
                } else if dispatchPolicy == .bothLLMs {
                    // M628 — substrate explicitly wants both LLMs
                    // (compare / escalate). Force dual-call
                    // regardless of router prediction.
                    var afmBodyMaybe: String?
                    var gemmaBodyMaybe: String?
                    var afmErr: Error?
                    var gemmaErr: Error?
                    let afmStart = Date()
                    do {
                        // M746 chapter 一百九十八 — bothLLMs path
                        // also gets per-iter timeout protection.
                        afmBodyMaybe = try await self.callAFMWithTimeout(
                            prompt: prompt, seconds: llmTimeoutCaptured)
                    } catch {
                        afmErr = error
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                    }
                    let afmMs = Date().timeIntervalSince(afmStart) * 1000
                    let gemmaStart = Date()
                    do {
                        gemmaBodyMaybe = try await self.callGemmaWithTimeout(
                            prompt: prompt, seconds: llmTimeoutCaptured)
                    } catch {
                        gemmaErr = error
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                    }
                    let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

                    firstTriedLLM = "afm"
                    firstBody = afmBodyMaybe ?? ""
                    firstStatus = afmErr == nil ? "ok" : "afm-error"
                    firstDurationMs = afmMs
                    if let g = gemmaBodyMaybe {
                        fallbackLLM = "gemma"
                        fallbackBody = g
                        fallbackStatus = gemmaErr == nil ? "ok-substrate-both" : "gemma-error"
                    }
                    fallbackDurationMs = gemmaMs
                    let bothFailed =
                        afmBodyMaybe == nil && gemmaBodyMaybe == nil
                    actualRoute = bothFailed
                        ? "substrate-both-failed"
                        : "substrate-both-\(dispatchPolicy.rawValue)"
                    if bothFailed {
                        applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                        // M666 — substrate forced both LLMs;
                        // routerHits/Misses doesn't apply.
                        routerHit = false
                    } else {
                        if afmBodyMaybe != nil {
                            applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                        }
                        if gemmaBodyMaybe != nil {
                            applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                        }
                    }
                    if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
                    if gemmaErr != nil {
                        errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
                    }
                    // M666 chapter 一百八十五 — B1: bothLLMs
                    // overrides router prediction. Don't pollute
                    // routerHits/Misses with these rows.
                    routerOverridden = true
                    applyIfActive(myGen) { self.hybridBenchSubstrateBothLLMs += 1 }
                } else if dispatchPolicy == .localOnly {
                    // M628 — substrate flagged no-cloud. Force
                    // Gemma path, never AFM. M666 chapter 一百
                    // 八十五 B1 fix: localOnly is substrate
                    // override; don't tally routerHits/Misses.
                    // M746 chapter 一百九十八 — apply timeout.
                    do {
                        firstBody = try await self.callGemmaWithTimeout(
                            prompt: prompt, seconds: llmTimeoutCaptured)
                        firstTriedLLM = "gemma"
                        firstStatus = "ok-substrate-local-only"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        actualRoute = "local-only-gemma-ok"
                        applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                    } catch {
                        // M780 chapter 二百七 — record timeout count.
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                        firstTriedLLM = "gemma"
                        firstStatus = "gemma-error"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        errorMessage = "gemma local-only: \(error)"
                        actualRoute = "local-only-gemma-failed"
                        applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                        routerHit = false
                    }
                    routerOverridden = true
                    applyIfActive(myGen) { self.hybridBenchSubstrateLocalOnly += 1 }
                } else {
                    // M628 — `.singleLLM` or `.draftOnly` falls
                    // through to original router-driven logic.
                    // For `.draftOnly` we additionally tag the
                    // row so downstream UI can flag the output
                    // as not-yet-committed.
                    if dispatchPolicy == .draftOnly {
                        draftOnlyFlag = true
                        applyIfActive(myGen) { self.hybridBenchSubstrateDraftOnly += 1 }
                    }
                    if routerConfidence == .uncertain {
                    // v0.2 — uncertain zone: call BOTH LLMs, pick
                    // longer body (simple heuristic, will swap to
                    // ShadowEvaluator-based picker in chapter 一百八十).
                    var afmBodyMaybe: String?
                    var gemmaBodyMaybe: String?
                    var afmErr: Error?
                    var gemmaErr: Error?
                    let afmStart = Date()
                    do {
                        // M746 chapter 一百九十八 — uncertain-zone
                        // dual-call also wrapped with timeout.
                        afmBodyMaybe = try await self.callAFMWithTimeout(
                            prompt: prompt, seconds: llmTimeoutCaptured)
                    } catch {
                        afmErr = error
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                    }
                    let afmMs = Date().timeIntervalSince(afmStart) * 1000
                    let gemmaStart = Date()
                    do {
                        gemmaBodyMaybe = try await self.callGemmaWithTimeout(
                            prompt: prompt, seconds: llmTimeoutCaptured)
                    } catch {
                        gemmaErr = error
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                    }
                    let gemmaMs = Date().timeIntervalSince(gemmaStart) * 1000

                    // Pick longer non-empty body (simple heuristic)
                    let pickedAFM: Bool
                    if let a = afmBodyMaybe, let g = gemmaBodyMaybe {
                        pickedAFM = a.count >= g.count
                    } else if afmBodyMaybe != nil {
                        pickedAFM = true
                    } else if gemmaBodyMaybe != nil {
                        pickedAFM = false
                    } else {
                        pickedAFM = true  // both failed
                    }
                    if pickedAFM {
                        firstTriedLLM = "afm"
                        firstBody = afmBodyMaybe ?? ""
                        firstStatus = afmErr == nil ? "ok" : "afm-error"
                        firstDurationMs = afmMs
                        if let other = gemmaBodyMaybe {
                            fallbackLLM = "gemma"
                            fallbackBody = other
                            fallbackStatus = "ok-uncertain-side"
                        }
                        fallbackDurationMs = gemmaMs
                        actualRoute = "uncertain-both-pick-afm"
                    } else {
                        firstTriedLLM = "gemma"
                        firstBody = gemmaBodyMaybe ?? ""
                        firstStatus = gemmaErr == nil ? "ok" : "gemma-error"
                        firstDurationMs = gemmaMs
                        if let other = afmBodyMaybe {
                            fallbackLLM = "afm"
                            fallbackBody = other
                            fallbackStatus = "ok-uncertain-side"
                        }
                        fallbackDurationMs = afmMs
                        actualRoute = "uncertain-both-pick-gemma"
                    }
                    let bothFailed =
                        afmBodyMaybe == nil && gemmaBodyMaybe == nil
                    if afmBodyMaybe != nil && gemmaBodyMaybe == nil {
                        applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                    } else if gemmaBodyMaybe != nil && afmBodyMaybe == nil {
                        applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                    } else if bothFailed {
                        applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                        // M627 review #6: actualRoute lied as
                        // "uncertain-both-pick-afm" when both bodies
                        // are empty. Correct semantic:
                        actualRoute = "uncertain-both-failed"
                    } else {
                        // Both succeeded (best case)
                        if pickedAFM {
                            applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                        } else {
                            applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                        }
                    }
                    if afmErr != nil { errorMessage = "afm: \(afmErr!)" }
                    if gemmaErr != nil {
                        errorMessage = (errorMessage ?? "") + " gemma: \(gemmaErr!)"
                    }
                    // M627 review #5: only count router-hit when
                    // at least one body returned. Both-failed
                    // increments routerMisses instead.
                    if bothFailed {
                        applyIfActive(myGen) { self.hybridBenchRouterMisses += 1 }
                        routerHit = false
                    } else {
                        applyIfActive(myGen) { self.hybridBenchRouterHits += 1 }
                    }
                } else {
                    // Confident — original single-LLM-with-fallback path
                    // M735 chapter 一百九十五 — wrap with timeout
                    // for 10h hang resistance.
                    do {
                        if routerRoute == .afm {
                            firstBody = try await self.callAFMWithTimeout(
                                prompt: prompt,
                                seconds: llmTimeoutCaptured)
                        } else {
                            firstBody = try await self.callGemmaWithTimeout(
                                prompt: prompt,
                                seconds: llmTimeoutCaptured)
                        }
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        actualRoute = "\(routerRoute.rawValue)-predicted-ok"
                        if routerRoute == .afm {
                            applyIfActive(myGen) { self.hybridBenchAFMOk += 1 }
                        } else {
                            applyIfActive(myGen) { self.hybridBenchGemmaOk += 1 }
                        }
                        applyIfActive(myGen) { self.hybridBenchRouterHits += 1 }
                    } catch {
                        // M780 chapter 二百七 — record timeout count.
                        self.recordTimeoutIfApplicable(
                            error, generation: myGen)
                        firstStatus = "\(routerRoute.rawValue)-error"
                        firstDurationMs =
                            Date().timeIntervalSince(firstStart) * 1000
                        errorMessage = "first: \(error)"
                        routerHit = false
                        applyIfActive(myGen) { self.hybridBenchRouterMisses += 1 }
                        let fbStart = Date()
                        do {
                            let other: String
                            if routerRoute == .afm {
                                other = try await self.callGemmaWithTimeout(
                                    prompt: prompt,
                                    seconds: llmTimeoutCaptured)
                                fallbackLLM = "gemma"
                                fallbackStatus = "ok"
                                fallbackBody = other
                                actualRoute = "afm-fallback-to-gemma-ok"
                                applyIfActive(myGen) { self.hybridBenchAFMFallbackToGemmaOk += 1 }
                            } else {
                                other = try await self.callAFMWithTimeout(
                                    prompt: prompt,
                                    seconds: llmTimeoutCaptured)
                                fallbackLLM = "afm"
                                fallbackStatus = "ok"
                                fallbackBody = other
                                actualRoute = "gemma-fallback-to-afm-ok"
                                applyIfActive(myGen) { self.hybridBenchGemmaFallbackToAFMOk += 1 }
                            }
                            fallbackDurationMs =
                                Date().timeIntervalSince(fbStart) * 1000
                        } catch {
                            // M780 chapter 二百七 — fallback timeout
                            self.recordTimeoutIfApplicable(
                                error, generation: myGen)
                            fallbackLLM = routerRoute == .afm ? "gemma" : "afm"
                            fallbackStatus = "error"
                            errorMessage = (errorMessage ?? "") + " fb: \(error)"
                            actualRoute = "both-failed"
                            applyIfActive(myGen) { self.hybridBenchBothFailed += 1 }
                            fallbackDurationMs =
                                Date().timeIntervalSince(fbStart) * 1000
                        }
                    }
                }
                }
                // M628 — close of outer else for .singleLLM/.draftOnly

                // M630 chapter 一百七十八 — CLOSED LOOP post-LLM
                // observation. After LLM responds (or skip-canned),
                // run substrate observation pass on the response
                // body. If substrate's permit shifts (e.g. body
                // would have been blocked), we know LLM crossed a
                // line invisible to pre-call substrate.
                //
                // Doctrine pin: substrate is THE arbiter — even
                // its own LLM's body is subject to substrate
                // re-audit. This is "shadow evaluator lite":
                // ShadowEvaluator full ML model lives in chapter
                // 一百八十+; this one is single substrate-pass.
                //
                // Cost: doubles substrate calls per iter. Trade:
                // empirical visibility into "did the LLM say
                // something substrate wouldn't have permitted".
                var postLLMPermitMode: String? = nil
                var postLLMAuditCount: Int? = nil
                var postLLMShifted: Bool? = nil
                // M685 chapter 一百八十七 — B4 (MEDIUM) fix:
                // also observe `bothLLMs` Gemma body if AFM
                // returned empty / errored. servedBody (defined
                // below as the actually-rendered body for
                // residuals) IS the right input for substrate
                // post-LLM observation. Pre-fix: AFM-empty +
                // Gemma-success in `.bothLLMs` branch left
                // postLLMShifted = nil (skipped) even though
                // Gemma's body was substrate-relevant.
                //
                // Skip iters (llmSkipped) still skip — substrate
                // already gave canned response, no LLM speech to
                // re-audit.
                let observableBody: String = {
                    if !firstBody.isEmpty { return firstBody }
                    return fallbackBody ?? ""
                }()
                if !observableBody.isEmpty && !llmSkipped {
                    // M676 chapter 一百八十五 — B6 (HIGH): cap
                    // body at HybridBenchTuning.postLLMBody...
                    // chars to avoid pathological substrate eval
                    // on Gemma's occasional 20K-char outputs +
                    // mitigate prompt-injection risk where LLM
                    // body could contain text substrate
                    // misinterprets as user intent.
                    // M710 chapter 一百九十一 — read from
                    // @Published so user can adjust live.
                    let cap = self.hybridBenchPostLLMTruncationChars
                    let truncatedBody: String
                    if observableBody.count > cap {
                        truncatedBody =
                            String(observableBody.prefix(cap))
                            + "...[truncated]"
                    } else {
                        truncatedBody = observableBody
                    }
                    let observeText =
                        "Original: \(prompt)\n\nResponse: \(truncatedBody)"
                    // M691 chapter 一百八十八 — B3-extended:
                    // post-LLM substrate observation also off-main.
                    // M767 chapter 二百四 — workflowProfile from flex.
                    let observeRequest = BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: workflowProfileCaptured,
                        surface: .application,
                        prompt: observeText,
                        riskLevel: riskLevel)
                    let observedResult: BASHostSessionResult? =
                        try? await Task.detached(
                            priority: .userInitiated
                        ) {
                            try runtime.startSession(observeRequest)
                        }.value
                    if let observed = observedResult?.eBrainTurn {
                        postLLMPermitMode = observed.actionPermit
                            .mode.rawValue
                        postLLMAuditCount = observed
                            .sovereignAuditEntry?.signalRefs.count ?? 0
                        postLLMShifted =
                            postLLMPermitMode != permitMode
                        if postLLMShifted == true {
                            applyIfActive(myGen) { self.hybridBenchPostLLMShifted += 1 }
                        }
                    }
                }

                let dur = Date().timeIntervalSince(t0)

                // M642 chapter 一百八十 — compute regression
                // residuals against actual LLM outputs (firstBody
                // length + firstDurationMs). Skipped iters
                // (llmSkipped == true) have no real LLM output to
                // compare against — skip residual computation.
                //
                // M670 chapter 一百八十五 — B9 (HIGH): in
                // bothLLMs branch, firstBody = AFM body (often
                // empty when AFM errors). Use the actually-served
                // body for residuals. `servedBody` is whichever
                // body actually has content; falls back to
                // fallbackBody when firstBody is empty.
                let servedBody: String = {
                    if !firstBody.isEmpty { return firstBody }
                    return fallbackBody ?? ""
                }()
                var lengthError: Double? = nil
                var latencyErrorMs: Double? = nil
                // M661 chapter 一百八十三 — 5th head residual
                // (verbosity binary correct/wrong).
                var verbosityCorrect: Bool? = nil
                let verbosityProb = multiHead?.verbosityProbability
                if !llmSkipped, !servedBody.isEmpty {
                    if let pred = lengthPredicted {
                        let actual = Double(servedBody.count)
                        let err = actual - pred
                        lengthError = err
                        // M669 chapter 一百八十五 — B8 Welford
                        // running mean (numerically stable over
                        // 144K samples). Sum/Count kept for
                        // backward compat in JSONL analysis.
                        // M689 ch188 — B8 retire: only Count + Running.
                        // M696 ch189 — wrap multi-line Welford
                        // recurrence in applyIfActive too.
                        applyIfActive(myGen) {
                            self.hybridBenchLengthMAECount += 1
                            let n = Double(
                                self.hybridBenchLengthMAECount)
                            self.hybridBenchLengthMAERunning +=
                                (abs(err)
                                 - self.hybridBenchLengthMAERunning)
                                / n
                        }
                    }
                    if let pred = latencyPredictedMs {
                        let err = firstDurationMs - pred
                        latencyErrorMs = err
                        applyIfActive(myGen) {
                            self.hybridBenchLatencyMAECount += 1
                            let n = Double(
                                self.hybridBenchLatencyMAECount)
                            self.hybridBenchLatencyMAERunningMs +=
                                (abs(err)
                                 - self.hybridBenchLatencyMAERunningMs)
                                / n
                        }
                    }
                    if let prob = verbosityProb {
                        // M710 chapter 一百九十一 — read live config
                        let actualLong = servedBody.count
                            > self.hybridBenchVerbosityThresholdChars
                        let predictedLong = prob
                            >= self.hybridBenchSigmoidClassThreshold
                        let correct = actualLong == predictedLong
                        verbosityCorrect = correct
                        if correct {
                            applyIfActive(myGen) { self.hybridBenchVerbosityCorrect += 1 }
                        } else {
                            applyIfActive(myGen) { self.hybridBenchVerbosityWrong += 1 }
                        }
                    }
                }

                // M718 chapter 一百九十二 — anomaly observation.
                // Watcher takes permitMode + body emptiness + the
                // 4 regression outputs (length / latency / verbosity
                // / blockProb) for NaN detection.
                let anomalyFlags = await anomalyWatcher.observe(
                    permitMode: permitMode,
                    bodyIsEmpty: servedBody.isEmpty,
                    regressionOutputs: [
                        lengthPredicted,
                        latencyPredictedMs,
                        verbosityProb,
                        permitPredictBlockProb,
                    ])
                // M727 chapter 一百九十三 — sync live counters
                // from watcher snapshot (cumulative; cheap to read).
                let watcherSnap = await anomalyWatcher.snapshot()
                applyIfActive(myGen) {
                    self.hybridBenchStuckSubstrateCount =
                        watcherSnap.stuckSubstrates
                    self.hybridBenchStuckLLMCount =
                        watcherSnap.stuckLLMs
                }
                if adversarialKind != nil {
                    applyIfActive(myGen) {
                        self.hybridBenchAdversarialFiredCount += 1
                    }
                }

                // M721 chapter 一百九十二 — drift sigma. Compute
                // BEFORE updating monitor (so this iter's residual
                // is sigma'd against history). Update after.
                var driftSigma: Double? = nil
                if let lerr = lengthError {
                    let s = lengthDriftMonitor.sigmaAbove(abs(lerr))
                    if lengthDriftMonitor.count >= 100 {
                        driftSigma = s
                    }
                    lengthDriftMonitor.update(abs(lerr))
                }
                if let lerr = latencyErrorMs {
                    latencyDriftMonitor.update(abs(lerr))
                }
                // 3-sigma threshold: tag in anomalyFlags for grep.
                // M731 chapter 一百九十四 — threshold from @Published.
                var allFlags = anomalyFlags
                if let s = driftSigma, s > driftThresholdCaptured {
                    allFlags.append(
                        "drift:length-mae:\(String(format: "%.1f", s))-sigma")
                    applyIfActive(myGen) {
                        self.hybridBenchDriftAlarmCount += 1
                    }
                }

                let row = SampleHostHybridBenchRow(
                    timestamp: SampleHostBenchHelpers.iso8601(Date()),
                    iteration: iter,
                    seed: iter,
                    stride: chosenStride,
                    mutationSeed: mutationSeed,
                    signature: signature,
                    prompt: prompt,
                    auditCodeCount: auditCount,
                    permitMode: permitMode,
                    routerVersion: routerVersion,
                    routerPredictedRoute: routerRoute.rawValue,
                    routerProbability: routerProb,
                    firstTriedLLM: firstTriedLLM,
                    firstTriedStatus: firstStatus,
                    firstTriedBody: firstBody,
                    firstTriedDurationMs: firstDurationMs,
                    fallbackTriedLLM: fallbackLLM,
                    fallbackStatus: fallbackStatus,
                    fallbackBody: fallbackBody,
                    fallbackDurationMs: fallbackDurationMs,
                    actualRoute: actualRoute,
                    routerHit: routerHit,
                    totalDurationSeconds: dur,
                    errorMessage: errorMessage,
                    dispatchPolicy: dispatchPolicy.rawValue,
                    dispatchTaken: dispatchTaken,
                    draftOnly: draftOnlyFlag,
                    llmSkipped: llmSkipped,
                    postLLMPermitMode: postLLMPermitMode,
                    postLLMAuditCodeCount: postLLMAuditCount,
                    postLLMShifted: postLLMShifted,
                    permitPredictBlockProb: permitPredictBlockProb,
                    permitPredictClass: permitPredictClass,
                    permitPredictAgreement: permitPredictAgreement,
                    permitPredictDetailedAgreement: permitPredictDetailedAgreement,
                    routerOverridden: routerOverridden,
                    lengthPredicted: lengthPredicted,
                    lengthError: lengthError,
                    latencyPredictedMs: latencyPredictedMs,
                    latencyErrorMs: latencyErrorMs,
                    verbosityProbability: verbosityProb,
                    verbosityCorrect: verbosityCorrect,
                    thermalState: thermalRaw,
                    batteryLevel: batteryRaw,
                    lowPowerMode: lowPower,
                    hourOfDay: hourCaptured,
                    smokeMode: smokeMode.rawValue,
                    targetLayer: layerProfile?.layerIndex,
                    targetLayerName: layerProfile?.layerName,
                    anomalyFlags: allFlags.isEmpty ? nil : allFlags,
                    pressureProfile: pressureProfile,
                    adversarialKind: adversarialKind?.rawValue,
                    driftSigma: driftSigma,
                    pauseSkipped: false)
                do {
                    try await runner.appendRow(row)
                } catch {
                    self.hybridBenchLastError = "jsonl: \(error)"
                }
                // M722 chapter 一百九十二 — checkpoint every N iters.
                // Atomic write via SampleHostBenchCheckpointStore so
                // a crash mid-bench loses ≤ checkpointEveryN iters.
                if (iter + 1) % checkpointEveryN == 0 {
                    let snap = await anomalyWatcher.snapshot()
                    let cp = SampleHostBenchCheckpoint(
                        generation: myGen,
                        iter: iter + 1,
                        startTimeIso: benchStartIso,
                        lastUpdatedIso: SampleHostBenchHelpers
                            .iso8601(Date()),
                        outputPath: SampleHostBenchHelpers
                            .hybridBenchOutputDirURL().path,
                        smokeMode: smokeMode.rawValue,
                        durationHours: durationHoursCaptured,
                        mutationSeedCount: mutationCountCaptured,
                        strideCSV: strideCSVCaptured,
                        afmOk: self.hybridBenchAFMOk,
                        gemmaOk: self.hybridBenchGemmaOk,
                        bothFailed: self.hybridBenchBothFailed,
                        stuckSubstrates: snap.stuckSubstrates,
                        stuckLLMs: snap.stuckLLMs)
                    try? await SampleHostBenchCheckpointStore
                        .shared.write(cp)
                }
                iter += 1
                // M627 deep-review fix #3 — only update iter
                // counter if we're still the active generation.
                // Stale tasks (cancelled by newer start) must not
                // clobber the new bench's published counters.
                // M668 chapter 一百八十五 — B5 (HIGH) fix:
                // CHECK GENERATION POST-ITER. If a Stop→Start
                // race created a newer task, all the per-iter
                // counter writes above (AFMOk / GemmaOk /
                // RouterHits / SubstrateSkip* / etc.) belong to
                // an OLD task whose results are stale.
                // Compensate by resetting the counters to ZERO
                // for the new task's gen mark — the fresh task
                // already zeroed them and will re-increment.
                // We can't undo the +=1's already done; but we
                // can document via lastError that drift occurred.
                // Detection-only: cleanup is the new task's job
                // (ResetAll on start does this).
                if self.hybridBenchGeneration != myGen {
                    // Stale task; bail out NOW so post-loop close
                    // runs but no further row is appended/written.
                    break
                }
                if self.hybridBenchGeneration == myGen {
                    self.hybridBenchIterations = iter
                }
                // M667 chapter 一百八十五 — B3 (CRITICAL): yield
                // every iter (was every 8). Sync substrate calls
                // (×2 per iter via M630 closed loop) block
                // @MainActor for ~50-100ms each; yielding more
                // often lets UI updates + scrolling proceed.
                // M710 chapter 一百九十一 — read live config
                if iter % max(1, self.hybridBenchYieldEveryNIters) == 0 {
                    await Task.yield()
                }
                // M744 chapter 一百九十八 — active cooling sleep.
                // When operator has enabled (coolingEveryN > 0)
                // AND iter is divisible AND device is at .serious
                // or worse, sleep coolingSleepSeconds. Lets the
                // phone radiate heat between iter clusters.
                // Doctrine: cooling is OPT-IN (default 0 disabled);
                // device-state read directly so the cooling decision
                // reflects CURRENT thermal not iter-start thermal.
                if coolingEveryNCaptured > 0
                    && iter % coolingEveryNCaptured == 0
                    && iter > 0
                {
                    let nowDevice = SampleHostBenchThermalGate
                        .currentDeviceState()
                    if nowDevice.thermal == "serious"
                        || nowDevice.thermal == "critical"
                    {
                        applyIfActive(myGen) {
                            self.hybridBenchCoolingSleepCount += 1
                        }
                        let nanos = UInt64(
                            max(0.001, coolingSleepSecondsCaptured)
                            * 1_000_000_000)
                        try? await Task.sleep(nanoseconds: nanos)
                    }
                }
            }
            await runner.close()
            // M733 chapter 一百九十四 — write shard manifest at
            // clean-finish for fast replay summary.
            if self.hybridBenchGeneration == myGen {
                let outDir = SampleHostBenchHelpers
                    .hybridBenchOutputDirURL()
                let shardCount = sampleHostBenchCountShards(in: outDir)
                let manifest = SampleHostBenchShardManifest(
                    benchID: benchStartIso,
                    startTimeIso: benchStartIso,
                    endTimeIso: SampleHostBenchHelpers
                        .iso8601(Date()),
                    totalIters: iter,
                    totalShards: shardCount,
                    smokeMode: self.hybridBenchSmokeMode.rawValue,
                    durationHours: durationHoursCaptured,
                    mutationSeedCount: mutationCountCaptured,
                    strideCSV: strideCSVCaptured,
                    afmOk: self.hybridBenchAFMOk,
                    gemmaOk: self.hybridBenchGemmaOk,
                    bothFailed: self.hybridBenchBothFailed,
                    routerHits: self.hybridBenchRouterHits,
                    routerMisses: self.hybridBenchRouterMisses,
                    stuckSubstrates: self.hybridBenchStuckSubstrateCount,
                    stuckLLMs: self.hybridBenchStuckLLMCount,
                    pauseSkipped: self.hybridBenchPauseSkippedCount,
                    adversarialFired: self.hybridBenchAdversarialFiredCount,
                    driftAlarms: self.hybridBenchDriftAlarmCount,
                    anomalyWindowSize: anomalyWindowCaptured,
                    driftSigmaThreshold: driftThresholdCaptured,
                    mutationProbability: mutationProbCaptured,
                    checkpointEveryNIters: checkpointEveryNCaptured)
                try? await SampleHostBenchShardManifestStore
                    .shared.write(manifest)
            }
            // M722 chapter 一百九十二 — clean-finish checkpoint
            // wipe so a fresh launch does not see a stale snap.
            // (Crash-mid-bench leaves checkpoint untouched, which
            // is exactly what we want for a future M723 resume UI.)
            if self.hybridBenchGeneration == myGen {
                await SampleHostBenchCheckpointStore.shared.clear()
            }
            // M627 deep-review fix #3 — only flip isRunning if
            // we're still the active generation. If a newer start
            // already bumped generation + set isRunning=true, our
            // exit must not flip it back to false.
            if self.hybridBenchGeneration == myGen {
                self.hybridBenchIsRunning = false
            }
        }
    }

    func stopHybridBench() {
        // M627 deep-review fix #3 — keep the task ref so we don't
        // lose the cancellation handle. Setting isRunning=false
        // here lets UI react immediately; the task itself will
        // see Task.isCancelled, exit its loop, close the JSONL
        // runner, and (via generation check) skip the final
        // isRunning=false write so a fast restart isn't clobbered.
        // M779 chapter 二百七 — DEEP-REVIEW FIX C3: bump generation
        // here too. Pre-fix: stop only cancels; stale task may
        // still be mid-iter (mid-LLM call, mid-substrate eval) and
        // its `applyIfActive(myGen)` writes succeed BEFORE
        // cancellation observation. Post-fix: gen++ here means
        // ANY post-stop `applyIfActive(myGen)` from the stale task
        // sees gen mismatch and skips. Pure stop semantics.
        hybridBenchGeneration += 1
        hybridBenchTask?.cancel()
        hybridBenchTask = nil
        hybridBenchIsRunning = false
    }

    func updateHybridBenchDurationHours(_ newValue: Double) {
        hybridBenchDurationHours = max(0.1, min(24.0, newValue))
    }

    func updateHybridBenchStrideCSV(_ newValue: String) {
        hybridBenchStrideRotationCSV = newValue
    }

    func updateHybridBenchRotationPeriod(_ newValue: Int) {
        hybridBenchRotationPeriodIter = max(1_000, min(100_000, newValue))
    }

    func updateHybridBenchMutationCount(_ newValue: Int) {
        hybridBenchMutationSeedCount = max(1, min(5, newValue))
    }

    // M731 chapter 一百九十四 — bound-enforcing setters for the
    // chapter-192 safety-kit flex constants. Doctrine: bench
    // loop reads the @Published value live but ranges must stay
    // within sane operating envelope so mid-bench adjustments
    // don't break invariants (e.g. windowSize = 0 → infinite loop).
    func updateAnomalyWindowSize(_ v: Int) {
        hybridBenchAnomalyWindowSize = max(10, min(1000, v))
    }
    func updateDriftSigmaThreshold(_ v: Double) {
        hybridBenchDriftSigmaThreshold = max(1.0, min(10.0, v))
    }
    func updateMutationProbability(_ v: Double) {
        hybridBenchMutationProbability = max(0.0, min(1.0, v))
    }
    func updateCheckpointEveryNIters(_ v: Int) {
        hybridBenchCheckpointEveryNIters = max(100, min(100_000, v))
    }
    /// M735 chapter 一百九十五 — per-iter LLM timeout setter.
    /// Bounds: [5s, 300s = 5min]. 60s default. Bounds protect
    /// against pathological 0-second (always timeout) and
    /// unreasonably-long (defeats purpose) settings.
    func updateLLMTimeoutSeconds(_ v: Double) {
        hybridBenchLLMTimeoutSeconds = max(5.0, min(300.0, v))
    }
    /// M744 chapter 一百九十八 — cooling-every-N-iters setter.
    /// Bounds: [0, 100_000]. 0 = disabled. 1000 = every ~55s on
    /// 18 iter/sec iPhone.
    func updateCoolingEveryNIters(_ v: Int) {
        hybridBenchCoolingEveryNIters = max(0, min(100_000, v))
    }
    /// M744 chapter 一百九十八 — cooling sleep seconds setter.
    /// Bounds: [5, 60]. 10s default lets thermal recover slowly.
    func updateCoolingSleepSeconds(_ v: Double) {
        hybridBenchCoolingSleepSeconds = max(5.0, min(60.0, v))
    }

    /// M726 chapter 一百九十三 — resume detector. Read latest
    /// checkpoint from disk; if it exists AND `lastUpdatedIso`
    /// is within the last 24 hours, surface it for UI prompt.
    /// Stale checkpoints (> 24h old) are auto-cleared.
    /// Doctrine: resume PROMPTS user, never auto-restarts. The
    /// checkpoint contains stride / smokeMode / iter — UI banner
    /// shows "previous bench reached iter N before crash" so the
    /// operator decides whether to start fresh or carry forward.
    func loadResumableCheckpoint() async {
        let cp = await SampleHostBenchCheckpointStore.shared.read()
        guard let cp = cp else {
            hybridBenchResumableCheckpoint = nil
            return
        }
        // Parse lastUpdatedIso — if older than 24h, auto-clear
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let fallback = ISO8601DateFormatter()
        let last = formatter.date(from: cp.lastUpdatedIso)
            ?? fallback.date(from: cp.lastUpdatedIso)
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        if let last = last, last < cutoff {
            await SampleHostBenchCheckpointStore.shared.clear()
            hybridBenchResumableCheckpoint = nil
            return
        }
        hybridBenchResumableCheckpoint = cp
    }

    /// M726 — UI button: dismiss resume banner without starting.
    /// Clears checkpoint from disk so a future launch sees clean state.
    func clearResumableCheckpoint() async {
        await SampleHostBenchCheckpointStore.shared.clear()
        hybridBenchResumableCheckpoint = nil
    }

    /// M748 chapter 一百九十九 — restore config from checkpoint
    /// then start a fresh bench. "Resume" semantic: same smokeMode /
    /// duration / mutation count / stride as the crashed bench.
    /// Counter state DOES NOT restore (too risky — would corrupt
    /// the new bench's anomaly windows + Welford running means).
    /// New bench writes new JSONL shards; old shards remain on
    /// disk for replay. Banner clears.
    ///
    /// Doctrine: "resume settings, fresh state". Operator carrying
    /// forward thoughtfully-tuned settings without re-typing them.
    func resumeBenchFromCheckpoint() async {
        guard let cp = hybridBenchResumableCheckpoint else { return }
        // Restore typed settings
        if let mode = HybridBenchConfig.SmokeMode(
            rawValue: cp.smokeMode)
        {
            hybridBenchSmokeMode = mode
        }
        updateHybridBenchDurationHours(cp.durationHours)
        updateHybridBenchMutationCount(cp.mutationSeedCount)
        updateHybridBenchStrideCSV(cp.strideCSV)
        // Clear banner (settings now restored)
        await clearResumableCheckpoint()
        // Start fresh bench with restored settings
        startHybridBench()
    }
}
