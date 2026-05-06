// MARK: - SampleHostLegacyBenchEntry
//
// chapter 二百三十六 / M818 — extracted from SampleHostModel.swift.
//
// Legacy bench entry methods (chapter 一百四十七 / M573 part 2 era —
// the earliest bench format with simple iterations.jsonl output):
//
//   - toggleBench()  — UI button: start or stop legacy bench
//   - startBench()   — async Task driving BASHostRuntime.startSession()
//                       in a 2h-bounded loop with M574/chapter 一百七十四
//                       coprime stride scatter walk + 5-variant mutation
//
// Pre-this-batch: ~155 LOC of inline methods on SampleHostModel.
// Cross-file extension was structurally blocked by `@Published
// private(set) var` writes; chapter 二百三十三 (M815) access promotion
// unblocked.
//
// Doctrine pins:
//   - chapter 一百四十七 §147 / M573: legacy bench format (simple
//     iterations.jsonl). Pre-AFM-bench, pre-hybrid-bench.
//   - chapter 一百四十九 / M574: 1-hour cap → chapter 一百七十四
//     /M604 doubled to 2h cap (113K iters at 15 iter/s).
//   - chapter 一百五十 defect #2 fix: coprime stride 5041 scatter walk.
//   - chapter 一百七十四 / M604: 5-variant mutation per iter.
//   - chapter 一百八十二 / M654 stride rotation: 11_300 iter ≈ 10 min on
//     iPhone 17e.
//   - chapter 二百二十一 / M802: stake → risk single-source derive.
//   - 不变量 #1-#3 + Red line 7: ✓ pure UI/loop, decisions stay at
//     substrate L11/L14.

import Foundation
import BASHostKit
#if canImport(UIKit)
import UIKit
#endif

extension SampleHostModel {
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

    func startBench() {
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
                    // M802 chapter 二百二十一 — single-source risk
                    // derive (was 11-LOC inline switch; now 1-line).
                    let riskLevel = SampleHostBenchRiskDerivation
                        .riskLevel(signatureStake: signature.stake)
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
}
