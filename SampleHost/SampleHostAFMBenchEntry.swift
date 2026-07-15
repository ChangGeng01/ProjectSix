// MARK: - SampleHostAFMBenchEntry
//
// chapter 二百三十七 / M819 — extracted from SampleHostModel.swift.
//
// AFM 8-hour long-running bench entry methods (chapter 一百七十六 §176.14):
//
//   - startAFMBench()  — async Task driving substrate routing +
//                         direct AFM body call per iter, JSONL
//                         output to iphone-afm-bench dir
//   - stopAFMBench()    — cancels task, clears running flag
//
// Pre-this-batch: ~152 LOC of inline methods on SampleHostModel.
// Cross-file extension was structurally blocked by `@Published
// private(set) var` writes; chapter 二百三十三 (M815) access
// promotion + chapter 二百三十六 (M818) bench-task-runner promotion
// unblocked.
//
// Doctrine pins:
//   - chapter 一百七十六 §176.14 / M610: substrate routes 14 layers
//     per turn (audit codes), then AFM body call (foreground policy).
//   - chapter 一百七十六 §176.13 / M609: AFM via FoundationModels
//     LanguageModelSession.respond(to:) directly from foreground UI.
//   - chapter 二百二十一 / M802: stake → risk single-source derive.
//   - 不变量 #1-#3 + Red line 7: ✓ pure bench loop, decisions stay
//     at substrate L11/L14.

import Foundation
import BASHostKit
#if canImport(FoundationModels)
import FoundationModels
#endif

extension SampleHostModel {
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
        // Chapter 三百四二 / M829: AFM timeout enforcement now
        // wired via `withTimeout(...)` (chapter 三百四一 / M828
        // backlog item closed)。UI setting clamped to [5, 120]s
        // and propagated to the bench loop's AFM call site。
        let afmTimeoutSec = TimeInterval(
            max(5, min(120, afmBenchAFMTimeoutSec)))
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
                // M802 chapter 二百二十一 — single-source risk
                // derive (was 7-LOC inline switch; now 1-line).
                let riskLevel = SampleHostBenchRiskDerivation
                    .riskLevel(signatureStake: signature.stake)
                do {
                    let result = try runtime.startSession(
                        BASHostSessionRequest(
                            kind: .interactive,
                            workflowProfile: .reflective,
                            surface: .application,
                            prompt: prompt,
                            riskLevel: riskLevel))
                    // context-IR: ACT/SHOW reads go through the slim response contract
                    if let response = result.turnResponse {
                        if let entry = response.sovereignAuditEntry {
                            auditCount = entry.signalRefs.count
                        }
                        permitMode = response.actionPermit.mode.rawValue
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
                            // Chapter 三百四二 / M829: AFM timeout
                            // enforcement via withTimeout wrapper。
                            // afmTimeoutSec is captured from the
                            // outer let (clamped [5, 120]s) and
                            // bounds AFM session.respond
                            // execution time。On timeout, throws
                            // AFMTimeoutError → caught below。
                            // Extract `.content` (Sendable String)
                            // inside the task body since the
                            // raw `Response<String>` type is not
                            // Sendable per Apple's API contract。
                            // INTENTIONAL raw `LanguageModelSession` — this benchmarks *raw* Apple
                            // Foundation Models latency/success. Do NOT route through
                            // `AppleFoundationOrganAdapter`: that would time adapter+FM, not raw FM, and
                            // corrupt the baseline. See Docs/CURRENCY_AUDIT_2026-06.md D3.
                            let content: String =
                                try await withTimeout(
                                    seconds: afmTimeoutSec
                                ) {
                                    let session =
                                        LanguageModelSession()
                                    let response =
                                        try await session
                                            .respond(to: prompt)
                                    return response.content
                                }
                            afmBody = content
                            afmStatus = "ok"
                            self?.afmBenchAFMSuccessCount += 1
                        } catch let timeoutErr
                            as AFMTimeoutError
                        {
                            // Chapter 三百四二 / M829: typed
                            // timeout-status emission for audit
                            // distinction from generic AFM errors。
                            afmStatus = "afm-timeout"
                            errorMessage = (errorMessage ?? "")
                                + "afm-timeout-after-" +
                                String(format: "%.1fs",
                                    timeoutErr.timeoutSeconds)
                            self?.afmBenchAFMErrorCount += 1
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
}
