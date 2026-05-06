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

}
