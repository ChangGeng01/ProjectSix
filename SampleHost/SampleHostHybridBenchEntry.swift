// MARK: - SampleHostHybridBenchEntry
//
// chapter 二百三十八 / M820 — extracted from SampleHostModel.swift.
//
// Hybrid 8-hour bench (chapter 一百七十七 §177 / M619) entry methods —
// the LARGEST single carve-out in the architectural deconstruction
// arc. ~1172 LOC of bench loop body + stop helper + safety-kit
// integration + closed-loop substrate observation + 5 CoreML head
// invocation + chapter 二百九 cooldown + chapter 二百八 .rawLLM
// dispatch override + adversarial mutator + checkpoint write.
//
//   - startHybridBench()  — async Task driving the hybrid bench
//                            (substrate routing → router predict →
//                            AFM/Gemma dispatch → fallback → row
//                            build → JSONL append → checkpoint)
//   - stopHybridBench()   — cancels task + bumps generation
//                            (chapter 二百七 / M779 doctrine)
//
// Pre-this-batch: ~1172 LOC of inline methods on SampleHostModel.
// Cross-file extension was structurally blocked by extensive
// `@Published private(set) var` writes (~80 fields touched)
// and `private var hybridBenchTask` / `hybridBenchGeneration` /
// `runtime` access barriers.
//
// chapter 二百三十三 (M815) access promotion + chapter 二百三十六
// (M818) bench-task-runner promotion unblocked.
//
// Doctrine pins (preserved verbatim from original — every chapter
// 178/181/182/188/190/191/192/193/194/195/197/198/204/205/207/
// 208/209/210/211/220 doc-comment):
//   - 不变量 #1 先醒再答 — substrate decides FIRST
//   - 不变量 #2 神经不掌权 — permit single-mouth at L11/L14
//   - 不变量 #3 私有经验不进权重 — bench data feeds offline retrain
//   - Red line 7 HINT-ONLY observability — anomaly + drift watchers
//     never decide
//   - chapter 二百八 / ADR-006 — .rawLLM bypasses substrate gate
//     for OBSERVABILITY ONLY; data NEVER feeds production permit
//   - chapter 二百九 / M790 — adaptive thermal cooldown ladder
//     (30s/60s/120s/300s ceiling)
//   - chapter 二百二十 / M801 — typed paused-row factory
//   - chapter 二百二十一 / M802 — single-source risk derive

import Foundation
import BASHostKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Build chapter tag (chapter 三百五二 / M839)

/// Single-source-of-truth for the build chapter tag used by:
///   - The hybrid bench panel header (visible to operator)
///   - The shard manifest's `buildChapter` field (persisted to disk)
///
/// Chapter 一百八十五 anti-magic-number: tag must match the M-number
/// of the most recent commit that materially altered hybrid bench
/// runtime behavior。Bump when shipping changes that affect data
/// recorded in JSONL or aggregated in manifest。
enum SampleHostHybridBenchEntry {
    static let buildChapterTag: String = "M839"
}

extension SampleHostModel {
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

        // Chapter 三百五一 / M838: keep screen on for the whole
        // 8h hybrid bench。Without this, iOS auto-locks → app
        // suspends → bench halts mid-iter (LLM token generation
        // gets killed, substrate gate stalls)。Mirrors the
        // SampleHostLegacyBenchEntry.swift:64 + chapter 三百五〇 /
        // M837 SampleHostChengluStressRunner pattern。
        // Restored in the matching block at end-of-run (~line 738)
        // and in stopHybridBench()。
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif

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
                    // M801 chapter 二百二十 — typed paused-row factory.
                    // Replaces ~58 LOC inline construction (chapter 一百
                    // 九十二 thermal gate + chapter 二百九 cooldown ladder
                    // doctrine bundled into one call site).
                    let pausedRow = SampleHostHybridBenchRow.pausedByThermalGate(
                        iter: iter,
                        chosenStride: chosenStride,
                        mutationSeed: mutationSeed,
                        signature: signature,
                        smokeMode: smokeMode,
                        layerProfile: layerProfile,
                        pressureProfile: pressureProfile,
                        adversarialKind: adversarialKind,
                        thermalRaw: thermalRaw,
                        batteryRaw: batteryRaw,
                        lowPower: lowPower,
                        hourOfDay: hourCaptured,
                        reason: reason,
                        cooldownLadderLabel: cooldown.ladderLabel(),
                        cooldownStreak: cooldown.pauseStreak)
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
                // M774 chapter 二百五 — benign mode forces low risk.
                // M802 chapter 二百二十一 — single-source derive
                // (was 14-LOC inline switch + override; now 1-line).
                let riskLevel = SampleHostBenchRiskDerivation
                    .riskLevel(
                        signatureStake: signature.stake,
                        smokeMode: smokeMode)
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
                    // SIGBUS fix (2026-07-11): startSession constructs the 53-field
                    // EBrainTurnResult value type through a deep bundle-unpacking init chain.
                    // On the cooperative thread pool's SMALL stack (Task.detached) that debug-
                    // build chain overflows → EXC_BAD_ACCESS at the M1502 init. Run it on a
                    // dedicated Thread with an explicit 8 MB stack. (Structural root: the giant
                    // value type; a library-level fix would box fields — tracked separately.)
                    let result = try await withCheckedThrowingContinuation {
                        (cont: CheckedContinuation<BASHostSessionResult, Error>) in
                        let worker = Thread {
                            do { cont.resume(returning: try runtime.startSession(request)) }
                            catch { cont.resume(throwing: error) }
                        }
                        worker.stackSize = 8 << 20   // 8 MB — main-thread-class stack
                        worker.start()
                    }
                    if let turn = result.eBrainTurn {
                        if let entry = turn.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = turn.actionPermit.mode.rawValue
                    }
                } catch {
                    permitMode = "substrate-error"
                }

                // M822 chapter 二百四十 — 5-head CoreML inference
                // bundle (was ~100 LOC inline; now 1-line predict +
                // 7-line typed read-back). Bundle handles MultiHead-
                // FIRST + per-head fallback (chapter 一百八十一 / M649).
                let features = ChengluPromptFeatures(
                    tone: signature.tone,
                    domain: signature.domain,
                    stake: signature.stake,
                    timeframe: signature.timeframe,
                    confidant: signature.confidant,
                    askShape: signature.askShape,
                    mutationSeed: mutationSeed)
                let coreML = SampleHostBenchCoreMLBundle.predict(
                    features: features)
                let routerRoute = coreML.routerRoute
                let routerProb = coreML.routerProb
                let routerVersion = coreML.routerVersion
                let routerConfidence = coreML.routerConfidence
                let multiHead = coreML.multiHead

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
                        forceSingleLLM: smokeMode == .rawLLM,
                        forceGemma: smokeMode == .forceGemma)

                // chapter 二百四十 — typed read-back of permit-
                // predict + agreement (chapter 一百七十九 / M635 +
                // chapter 一百八十六 / M675 doctrine in bundle helpers).
                let permitPredictBlockProb = coreML.permitPredictBlockProb
                let permitPredictClass = coreML.permitPredictClass
                let permitPredictAgreement =
                    coreML.permitPredictAgreement(
                        actualPermitMode: permitMode)
                let permitPredictDetailedAgreement =
                    coreML.permitPredictDetailedAgreement(
                        actualPermitMode: permitMode)
                if let agree = permitPredictAgreement {
                    if agree {
                        applyIfActive(myGen) { self.hybridBenchPermitPredictHits += 1 }
                    } else {
                        applyIfActive(myGen) { self.hybridBenchPermitPredictMisses += 1 }
                    }
                }

                // chapter 二百四十 — typed read-back of length +
                // latency predictions (chapter 一百八十 / M638-M641
                // doctrine in bundle).
                let lengthPredicted = coreML.lengthPredicted
                let latencyPredictedMs = coreML.latencyPredictedMs

                // M826 chapter 二百四十四 — LLM dispatch logic
                // (~340 LOC of switch-on-dispatchPolicy with 6
                // branches: .skipsLLM canned / .bothLLMs dual /
                // .localOnly Gemma-only / .singleLLM uncertain-zone
                // dual-LLM longer-pick / .singleLLM confident with
                // fallback / .draftOnly variant) extracted to typed
                // value bundle + extension method. chapter 一百
                // 七十八 / M628 + chapter 一百八十五 / M666 (B1 fix)
                // + chapter 一百九十五 / M735 timeout doctrine in
                // `SampleHostBenchLLMDispatcher`.
                let dispatchResult = await self.dispatchLLMs(
                    dispatchPolicy: dispatchPolicy,
                    routerRoute: routerRoute,
                    routerConfidence: routerConfidence,
                    prompt: prompt,
                    timeoutSeconds: llmTimeoutCaptured,
                    generation: myGen)
                let firstTriedLLM = dispatchResult.firstTriedLLM
                let firstStatus = dispatchResult.firstStatus
                let firstBody = dispatchResult.firstBody
                let firstDurationMs = dispatchResult.firstDurationMs
                let fallbackLLM = dispatchResult.fallbackLLM
                let fallbackStatus = dispatchResult.fallbackStatus
                let fallbackBody = dispatchResult.fallbackBody
                let fallbackDurationMs = dispatchResult.fallbackDurationMs
                let actualRoute = dispatchResult.actualRoute
                let routerHit = dispatchResult.routerHit
                let routerOverridden = dispatchResult.routerOverridden
                let errorMessage = dispatchResult.errorMessage
                let dispatchTaken = dispatchResult.dispatchTaken
                let llmSkipped = dispatchResult.llmSkipped
                let draftOnlyFlag = dispatchResult.draftOnlyFlag


                // M824 chapter 二百四十二 — CLOSED LOOP post-LLM
                // observation extracted to typed value bundle +
                // extension method (chapter 一百七十八 / M630
                // doctrine in `SampleHostBenchPostLLMObserver`).
                let postLLMObs = await self.observePostLLM(
                    runtime: runtime,
                    workflowProfile: workflowProfileCaptured,
                    riskLevel: riskLevel,
                    prompt: prompt,
                    firstBody: firstBody,
                    fallbackBody: fallbackBody,
                    llmSkipped: llmSkipped,
                    prePermitMode: permitMode,
                    bodyTruncationChars: self.hybridBenchPostLLMTruncationChars,
                    generation: myGen)
                let postLLMPermitMode = postLLMObs.postLLMPermitMode
                let postLLMAuditCount = postLLMObs.postLLMAuditCount
                let postLLMShifted = postLLMObs.postLLMShifted

                let dur = Date().timeIntervalSince(t0)

                // M825 chapter 二百四十三 — regression residuals
                // (length / latency / verbosity correctness)
                // extracted to typed value bundle + extension method.
                // chapter 一百八十 / M642 + chapter 一百八十三 / M661
                // doctrine in `SampleHostBenchRegressionResiduals`.
                //
                // M670 chapter 一百八十五 — B9 (HIGH): in bothLLMs
                // branch, firstBody = AFM body (often empty when AFM
                // errors). Use the actually-served body for residuals.
                let servedBody: String = {
                    if !firstBody.isEmpty { return firstBody }
                    return fallbackBody ?? ""
                }()
                let verbosityProb = multiHead?.verbosityProbability
                let residuals = self.computeRegressionResiduals(
                    llmSkipped: llmSkipped,
                    servedBody: servedBody,
                    firstDurationMs: firstDurationMs,
                    lengthPredicted: lengthPredicted,
                    latencyPredictedMs: latencyPredictedMs,
                    verbosityProbability: verbosityProb,
                    verbosityThresholdChars: self.hybridBenchVerbosityThresholdChars,
                    sigmoidClassThreshold: self.hybridBenchSigmoidClassThreshold,
                    generation: myGen)
                let lengthError = residuals.lengthError
                let latencyErrorMs = residuals.latencyErrorMs
                let verbosityCorrect = residuals.verbosityCorrect

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
            // bench end for fast replay summary。
            //
            // **Chapter 三百五二 / M839 fix**: manifest write is
            // now OUTSIDE the gen guard so cancelled runs ALSO
            // get a manifest written (with phase: "cancelled").
            // Pre-M839 behavior: gen-guard skipped manifest on
            // cancel → user pressed Stop → 56 min of bench data
            // had no manifest summary,operator had to walk all
            // JSONL rows to aggregate counts。
            //
            // The race-safety story (M779 chapter 二百七 origin):
            // gen-guard prevents stale isRunning=false writes
            // when a fast restart bumps generation。Manifest
            // write doesn't have the same race because:
            //   - Cancelled task's manifest write fires within
            //     seconds of the cancel observation (mid-LLM call
            //     finishes,loop sees Task.isCancelled,exits)
            //   - New task's manifest write only fires at end of
            //     ITS run (typically 8h later)
            //   - So cancelled writes first,new task overwrites
            //     8h later — manifest always reflects "last run
            //     that finished",matching user intent。
            let wasCancelled = Task.isCancelled
            let manifestPhase: String =
                wasCancelled ? "cancelled" : "completed"
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
                checkpointEveryNIters: checkpointEveryNCaptured,
                phase: manifestPhase,
                buildChapter: SampleHostHybridBenchEntry
                    .buildChapterTag,
                cancelled: wasCancelled)
            try? await SampleHostBenchShardManifestStore
                .shared.write(manifest)
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
            // Chapter 三百五一 / M838: restore screen-lock。Pair
            // with the `= true` set in startHybridBench()。
            // Idempotent — `stopHybridBench()` may also restore,
            // setting it false twice is harmless。
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
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
        // Chapter 三百五一 / M838: restore screen-lock immediately
        // on stop。The task's own restore (in defer-equivalent at
        // ~line 738) also fires when it exits the loop,but
        // setting it false here gives instant visual feedback +
        // covers the case where task is mid-LLM-call and takes
        // seconds to observe cancellation。Idempotent。
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = false
        #endif
    }

}
