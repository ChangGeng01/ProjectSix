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
    @Published var result: BASHostSessionResult
    @Published var lastError: String?
    @Published var benchIsRunning: Bool = false
    @Published var benchIterationsCompleted: Int = 0
    @Published var benchAuditCodesTotal: Int = 0
    @Published var benchStartTime: Date?
    @Published var benchLastError: String?
    @Published var benchOutputPath: String = ""
    // M609 chapter 一百七十六 §176.13 — direct AFM test (foreground UI invocation)
    @Published var afmTestStatus: String = "idle"
    @Published var afmTestOutput: String = ""
    @Published var afmTestPrompt: String = "Suggest one calming evening habit in one sentence."
    @Published var afmTestDurationMs: Double = 0
    @Published var afmIsRunning: Bool = false

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
    @Published var afmBenchIsRunning: Bool = false
    @Published var afmBenchIterations: Int = 0
    @Published var afmBenchAFMSuccessCount: Int = 0
    @Published var afmBenchAFMSkippedCount: Int = 0
    @Published var afmBenchAFMErrorCount: Int = 0
    @Published var afmBenchOutputPath: String = ""
    @Published var afmBenchStartTime: Date?
    @Published var afmBenchLastError: String?
    var afmBenchTask: Task<Void, Never>?

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
    @Published var hybridBenchLLMTimeoutCount: Int = 0
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
    @Published var hybridBenchCoolingSleepCount: Int = 0
    /// M745 chapter 一百九十八 — live thermal state surface for
    /// dashboard widget. Updated per-iter from
    /// `SampleHostBenchThermalGate.currentDeviceState()`. Lets
    /// operator see current thermal in real time during 10h
    /// instead of grepping JSONL post-hoc.
    @Published var hybridBenchLastThermalRaw: String = "unknown"
    /// M745 — count of iters spent at each thermal level.
    /// Lets dashboard show "% at serious", etc.
    @Published var hybridBenchThermalNominalIters: Int = 0
    @Published var hybridBenchThermalFairIters: Int = 0
    @Published var hybridBenchThermalSeriousIters: Int = 0
    @Published var hybridBenchThermalCriticalIters: Int = 0
    @Published var hybridBenchIsRunning: Bool = false
    @Published var hybridBenchIterations: Int = 0
    @Published var hybridBenchAFMOk: Int = 0
    @Published var hybridBenchGemmaOk: Int = 0
    @Published var hybridBenchAFMFallbackToGemmaOk: Int = 0
    @Published var hybridBenchGemmaFallbackToAFMOk: Int = 0
    @Published var hybridBenchBothFailed: Int = 0
    @Published var hybridBenchRouterHits: Int = 0
    @Published var hybridBenchRouterMisses: Int = 0
    // M628 chapter 一百七十八 — dispatch policy live counters.
    // Tracks how often substrate's permit mode causes LLM skip /
    // both-call / local-only / draft-only path. UI surfaces these
    // so user sees substrate-LLM coupling in real time.
    @Published var hybridBenchSubstrateSkipBlock: Int = 0
    @Published var hybridBenchSubstrateSkipReplace: Int = 0
    @Published var hybridBenchSubstrateSkipDelay: Int = 0
    @Published var hybridBenchSubstrateBothLLMs: Int = 0
    @Published var hybridBenchSubstrateLocalOnly: Int = 0
    @Published var hybridBenchSubstrateDraftOnly: Int = 0
    // M630 chapter 一百七十八 — closed-loop tracking. How often
    // post-LLM substrate observation shifts permit mode (i.e.
    // LLM produced something that would have been blocked).
    @Published var hybridBenchPostLLMShifted: Int = 0

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
    @Published var hybridBenchPermitPredictHits: Int = 0
    @Published var hybridBenchPermitPredictMisses: Int = 0
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
    @Published var hybridBenchLengthMAECount: Int = 0
    @Published var hybridBenchLengthMAERunning: Double = 0
    @Published var hybridBenchLatencyMAECount: Int = 0
    @Published var hybridBenchLatencyMAERunningMs: Double = 0
    // M661 chapter 一百八十三 — 5th head agreement counters.
    @Published var hybridBenchVerbosityCorrect: Int = 0
    @Published var hybridBenchVerbosityWrong: Int = 0
    @Published var hybridBenchOutputPath: String = ""
    @Published var hybridBenchStartTime: Date?
    @Published var hybridBenchLastError: String?
    // M727 chapter 一百九十三 — live anomaly counters surfaced
    // for the dashboard widget. Updated per-iter from
    // SampleHostBenchAnomalyWatcher.snapshot(). Distinct from
    // anomalyFlags-on-row (which is per-iter) — these are
    // cumulative for the whole bench.
    @Published var hybridBenchStuckSubstrateCount: Int = 0
    @Published var hybridBenchStuckLLMCount: Int = 0
    @Published var hybridBenchPauseSkippedCount: Int = 0
    @Published var hybridBenchAdversarialFiredCount: Int = 0
    @Published var hybridBenchDriftAlarmCount: Int = 0
    /// M726 chapter 一百九十三 — resume snapshot from a previous
    /// (possibly crashed) bench. Populated by `loadResumableCheckpoint()`
    /// at app launch. nil = no checkpoint or last bench finished
    /// cleanly. UI banner offers `clearResumableCheckpoint()` or
    /// allows starting a new bench (which auto-clears the stale
    /// checkpoint via fresh write).
    @Published var hybridBenchResumableCheckpoint:
        SampleHostBenchCheckpoint?
    @Published var hybridGemmaLoadStatus: String = "idle"
    @Published var hybridSinglePromptStatus: String = "idle"
    @Published var hybridSinglePromptOutput: String = ""
    @Published var hybridSinglePromptRoute: String = ""
    @Published var hybridSinglePromptProb: Double = 0
    // M659 chapter 一百八十三 — single-prompt inline all-head
    // predictions. Populated when runHybridSinglePrompt fires;
    // surface 5 head outputs alongside the LLM body so user sees
    // meridian network predictions BEFORE waiting for LLM.
    @Published var hybridSinglePromptBlockProb: Double?
    @Published var hybridSinglePromptLengthChars: Double?
    @Published var hybridSinglePromptLatencyMs: Double?
    @Published var hybridSinglePromptVerbosityProb: Double?
    var hybridBenchTask: Task<Void, Never>?
    // M627 chapter 177 deep-review fix #3 — Stop→Start race.
    // Each start bumps generation + captures myGen. Old task at
    // exit only writes hybridBenchIsRunning=false if its myGen
    // still matches; otherwise a newer start has already run and
    // we must not clobber its true. Also defends against the old
    // task's final JSONL write racing the new task's runner.
    var hybridBenchGeneration: Int = 0

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
    // M815 chapter 二百三十三 — promoted from `private var` to
    // module-internal so the extracted LLM helpers extension file
    // (SampleHostLLMHelpers.swift) can access the gemma adapter
    // cache without requiring a same-file declaration.
    var gemmaAdapter: MLXOrganAdapter?
    // M627 chapter 177 deep-review fix #2 — gate concurrent loads
    // via in-flight Task. Two callGemma invocations during await
    // suspension would both start loading the 4-bit model + LoRA
    // (~3.4 GB, hundreds of MB resident wasted). Now they share.
    var gemmaLoadInFlight: Task<MLXOrganAdapter, Error>?
    // M627 deep-review fix #4 — track LoRA load success separately
    // from adapter init so a failed LoRA load doesn't poison the
    // session: status tells the truth + future calls can retry.
    var gemmaLoraLoaded: Bool = false
    #endif

    var benchTask: Task<Void, Never>?
    let benchRunner = SampleHostBenchRunner()

    let runtime: BASHostRuntime
    // M813 chapter 二百三十一 — 5 BAS-host config bundles
    // (workflowBehavior / lifecycleBehavior / cognitionBehavior /
    // presentation / runtimeTuning) extracted to dedicated
    // `SampleHostBASHostConfigBundles.swift` namespace enum.

    init(
        runtime: BASHostRuntime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "samplehost.default-runtime",
                policyProfileID: "samplehost.default-policy",
                prefersPureLocal: true,
                defaultDeviceState: BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: SampleHostBASHostConfigBundles.lifecycleBehavior,
                workflowBehavior: SampleHostBASHostConfigBundles.workflowBehavior,
                cognitionBehavior: SampleHostBASHostConfigBundles.cognitionBehavior,
                presentation: SampleHostBASHostConfigBundles.presentation,
                runtimeTuning: SampleHostBASHostConfigBundles.runtimeTuning,
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
        self.result = SampleHostBASHostInvocation.perform(
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
        result = SampleHostBASHostInvocation.perform(
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
        result = SampleHostBASHostInvocation.perform(
            using: runtime,
            errorSink: { lastError = $0 },
            request: {
                try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: profile,
                        surface: .application,
                        prompt: prompts[profile] ?? "Hold this decision for one more beat.",
                        title: "\(SampleHostBASHostConfigBundles.presentation.workflowTitles.title(for: profile)) from SampleHost",
                        riskLevel: profile == .reflective ? .medium : .low
                    )
                )
            }
        )
    }

    func reopen() {
        result = SampleHostBASHostInvocation.perform(
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
    // M818 chapter 二百三十六 — `toggleBench` + `startBench`
    // (legacy bench, chapter 一百四十七 / M573 part 2 era) extracted
    // to dedicated extension file `SampleHostLegacyBenchEntry.swift`.

    // MARK: - shared helpers

    // M814 chapter 二百三十二 — `perform(using:errorSink:request:)` +
    // `fallbackResult(using:)` static helpers extracted to dedicated
    // file `SampleHostBASHostInvocation.swift`. Callers now use
    // `SampleHostBASHostInvocation.perform(...)` etc.

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

    // M816 chapter 二百三十四 — `runAFMTestNow` + `updateAFMTestPrompt`
    // extracted to dedicated extension file
    // `SampleHostSinglePromptTests.swift`.


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

    // M819 chapter 二百三十七 — `startAFMBench` + `stopAFMBench`
    // (chapter 一百七十六 §176.14) extracted to dedicated extension
    // file `SampleHostAFMBenchEntry.swift`.


    // M804 chapter 二百二十三 — 5 AFM-bench setters extracted to
    // dedicated extension file `SampleHostAFMBenchSettings.swift`.
    // Bounds reused from chapter 二百二十二 typed bundle.
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
    // M816 chapter 二百三十四 — `runHybridSinglePrompt` extracted
    // to dedicated extension file `SampleHostSinglePromptTests.swift`.


    // M815 chapter 二百三十三 — 6 LLM helpers (recordTimeoutIf-
    // Applicable / callAFMWithTimeout / callGemmaWithTimeout /
    // callAFM / callGemma / ensureGemmaAdapter) extracted to
    // dedicated extension file `SampleHostLLMHelpers.swift`.
    // Access barriers promoted (private(set) → @Published var
    // for status surface; private var → internal var for gemma
    // adapter cache) so the extension can reach state directly.


    /// Update prompt text for single-prompt hybrid test.
    /// (Reuses afmTestPrompt setter.)

    /// Start long-running hybrid bench (8h default).
    // M820 chapter 二百三十八 — `startHybridBench` (~1150 LOC bench
    // loop body) + `stopHybridBench` extracted to dedicated extension
    // file `SampleHostHybridBenchEntry.swift`. LARGEST single carve-
    // out in the architectural deconstruction arc (chapters 二百九 →
    // 二百三十八).


    // M803 chapter 二百二十二 — 11 hybrid-bench setters extracted
    // to dedicated extension file `SampleHostHybridBenchSettings
    // .swift`. Bounds doctrine consolidated in `SampleHostHybrid-
    // BenchBounds` typed enum (single-source-of-truth per chapter
    // 二百十一 doctrine).

    // M817 chapter 二百三十五 — 3 checkpoint lifecycle methods
    // (loadResumableCheckpoint / clearResumableCheckpoint /
    // resumeBenchFromCheckpoint) extracted to dedicated extension
    // file `SampleHostCheckpointLifecycle.swift`.
}
