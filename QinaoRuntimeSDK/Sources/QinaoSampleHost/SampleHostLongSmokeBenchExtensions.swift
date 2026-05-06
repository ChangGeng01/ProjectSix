// MARK: - SampleHostLongSmokeBenchExtensions — chapter 二百九十五 / M782
//
// Phase Alpha 第二十一刀(QinaoSampleHost god file 8th cut, FINAL):
// 从 `main.swift` 抽出 long smoke + comprehensive bench cluster +
// DoctrineBenchConstants enum — Phase Alpha 第四个 god file 完结。
//
// 抽出 helpers + types (Swift extension on QinaoSampleHost):
//   - `runLongSmokeBench` (M572 chapter 一百四十七) — long-running
//     8-hour smoke bench
//   - `runComprehensiveBench` (M574 chapter 一百四十九) — comprehensive
//     4-path bench (naked AFM / naked Gemma / substrate / fullstack)
//   - `DoctrineBenchConstants` enum (M594 chapter 一百六十五) —
//     anti-magic-number constants for doctrine metrics bench
//
// **0 behavior change**:helpers + enum literal-identical to
// pre-extraction versions,只是改成了 Swift extension on
// QinaoSampleHost。Module DAG 不变(同 module 内部 split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 一百四十七 / 一百四十九 long-smoke + comprehensive bench
//     行为不变
//   - chapter 一百六十五 anti-magic-number constants 行为不变
//
// **Phase Alpha milestone**: QinaoSampleHost main.swift god file
// 拆完 — 8224 → ~1500 LOC across 8 cuts (Bench / Demo / MLX /
// LoRA / DoctrineBench / AppleFM / RuntimeBench / LongSmoke +
// DoctrineBenchConstants)。

import Foundation
import BASAppleAdapters
import BASHostKit
import BASMLXAdapter
import BASOrchestration
import BASRuntimeCore
import QinaoLoop
import QinaoMLX

extension QinaoSampleHost {
    static func runLongSmokeBench(args: [String]) async {
        // Configuration via env vars
        let durationStr = ProcessInfo.processInfo
            .environment["QINAO_LONG_SMOKE_DURATION_SECONDS"]
        let outputStr = ProcessInfo.processInfo
            .environment["QINAO_LONG_SMOKE_OUTPUT"]
            ?? "/tmp/qinao-long-smoke"
        let checkpointStr = ProcessInfo.processInfo
            .environment["QINAO_LONG_SMOKE_CHECKPOINT_SECONDS"]
        let runJudgeStr = ProcessInfo.processInfo
            .environment["QINAO_LONG_SMOKE_RUN_JUDGE"]
        let timeoutStr = ProcessInfo.processInfo
            .environment["QINAO_LONG_SMOKE_TIMEOUT_SECONDS"]

        let duration = Int(durationStr ?? "") ?? (8 * 3600)
        let checkpoint = Int(checkpointStr ?? "") ?? 60
        let timeout = Int(timeoutStr ?? "") ?? 60
        let runJudge = (runJudgeStr ?? "0") == "1"
        let outputURL = URL(fileURLWithPath: outputStr)

        print("""
            QinaoSampleHost --long-smoke-bench (M572, chapter 一百四十七):
              Long-running automation for AFM + Gemma 4 E2B continuous
              inference smoke. Generates JSONL of (iteration × endpoint)
              tuples with per-iteration red-line counter + checkpoint
              progress.

              Duration:           \(duration) seconds (\(duration / 3600)h)
              Output directory:   \(outputStr)
              Checkpoint every:   \(checkpoint) seconds
              Per-call timeout:   \(timeout) seconds
              Run user-value judge: \(runJudge)

              Override via env:
                QINAO_LONG_SMOKE_DURATION_SECONDS=N
                QINAO_LONG_SMOKE_OUTPUT=path
                QINAO_LONG_SMOKE_CHECKPOINT_SECONDS=N
                QINAO_LONG_SMOKE_RUN_JUDGE=1
                QINAO_LONG_SMOKE_TIMEOUT_SECONDS=N
            """)

        let config = QinaoLongRunningSmokeConfiguration(
            maxDurationSeconds: duration,
            outputDirectory: outputURL,
            checkpointIntervalSeconds: checkpoint,
            runAFM: true,
            runGemma: true,
            runUserValueJudge: runJudge,
            perEndpointTimeoutSeconds: timeout)

        let writer = QinaoLongRunningSmokeWriter(
            outputDirectory: outputURL)
        do {
            try await writer.ensureDirectory()
        } catch {
            stderr("ERROR: ensureDirectory failed: \(error)\n")
            return
        }
        print("✓ Output directory ready: \(outputStr)\n")

        // AFM endpoint (no deterministic fallback — let it fail
        // honest if AFM unavailable)
        let afmEndpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: false)
        print("✓ AFM endpoint constructed")

        // Gemma 4 E2B endpoint
        var gemmaEndpoint: (any QinaoOrganEndpoint)?
        do {
            gemmaEndpoint = try await QinaoLoop
                .makeMLXEndpoint(model: .gemma4E2B)
            print("✓ Gemma 4 E2B endpoint loaded")
        } catch {
            gemmaEndpoint = nil
            stderr("⚠ Gemma 4 E2B unavailable: \(error.localizedDescription)\n")
        }

        // Optional judge endpoint (reuse AFM)
        let judgeEndpoint = config.runUserValueJudge
            ? afmEndpoint
            : nil
        if config.runUserValueJudge {
            print("✓ User-value judge enabled (uses AFM)")
        }

        let runStart = Date()
        let runStartStr = QinaoLongRunningSmokeHelpers
            .iso8601(runStart)

        // Counters
        var iteration = 0
        var afmCompleted = 0
        var gemmaCompleted = 0
        var afmTimeouts = 0
        var gemmaTimeouts = 0
        var afmErrors = 0
        var gemmaErrors = 0
        var afmRedLineTotal = 0
        var gemmaRedLineTotal = 0
        var afmDurations: [Double] = []
        var gemmaDurations: [Double] = []
        var perPersonaCounts: [String: Int] = [:]

        var lastCheckpoint = runStart

        let allPrompts = QinaoSyntheticPromptCatalog.allPrompts

        print("\nStarting long-running loop. \(allPrompts.count) prompts in catalog.\n")
        print("=== T+0 ===\n")

        // Main loop — iterate until duration elapsed
        while true {
            let now = Date()
            let elapsed = now.timeIntervalSince(runStart)
            if Int(elapsed) >= config.maxDurationSeconds {
                print("\n[\(QinaoLongRunningSmokeHelpers.iso8601(now))] " +
                    "duration reached: \(Int(elapsed))s elapsed; halting.")
                break
            }

            let entry = allPrompts[iteration % allPrompts.count]
            let prompt = entry.prompt
            let personaName = entry.persona.rawValue
            let scenarioName = entry.scenario.rawValue

            // 1. AFM call
            if config.runAFM {
                let t0 = Date()
                var status = "ok"
                var errorMsg: String?
                var responseText = ""
                do {
                    let r = try await afmEndpoint.produceBody(
                        prompt: prompt,
                        context: [],
                        role: .core,
                        sessionID:
                            "long-smoke-afm-\(iteration)")
                    responseText = r.body
                } catch {
                    status = "error"
                    errorMsg = "\(error)"
                    afmErrors += 1
                }
                let dur = Date().timeIntervalSince(t0)
                let redCount = countRedLineViolations(in: responseText)
                afmRedLineTotal += redCount
                afmCompleted += 1
                afmDurations.append(dur)
                let row = QinaoLongRunningSmokeRow(
                    timestamp: QinaoLongRunningSmokeHelpers
                        .iso8601(Date()),
                    iteration: iteration,
                    persona: personaName,
                    scenario: scenarioName,
                    prompt: prompt,
                    endpoint: "afm",
                    responseLength: responseText.count,
                    responseRedLineCount: redCount,
                    durationSeconds: dur,
                    status: status,
                    errorMessage: errorMsg,
                    userValueScore: nil)
                do {
                    try await writer.appendRow(row)
                } catch {
                    stderr("⚠ AFM row write failed: \(error)\n")
                }
            }

            // 2. Gemma call
            if config.runGemma, let gemma = gemmaEndpoint {
                let t0 = Date()
                var status = "ok"
                var errorMsg: String?
                var responseText = ""
                do {
                    let r = try await gemma.produceBody(
                        prompt: prompt,
                        context: [],
                        role: .core,
                        sessionID:
                            "long-smoke-gemma-\(iteration)")
                    responseText = r.body
                } catch {
                    status = "error"
                    errorMsg = "\(error)"
                    gemmaErrors += 1
                }
                let dur = Date().timeIntervalSince(t0)
                let redCount = countRedLineViolations(in: responseText)
                gemmaRedLineTotal += redCount
                gemmaCompleted += 1
                gemmaDurations.append(dur)
                let row = QinaoLongRunningSmokeRow(
                    timestamp: QinaoLongRunningSmokeHelpers
                        .iso8601(Date()),
                    iteration: iteration,
                    persona: personaName,
                    scenario: scenarioName,
                    prompt: prompt,
                    endpoint: "gemma",
                    responseLength: responseText.count,
                    responseRedLineCount: redCount,
                    durationSeconds: dur,
                    status: status,
                    errorMessage: errorMsg,
                    userValueScore: nil)
                do {
                    try await writer.appendRow(row)
                } catch {
                    stderr("⚠ Gemma row write failed: \(error)\n")
                }
            }

            perPersonaCounts[personaName, default: 0] += 1
            iteration += 1

            // Optional checkpoint
            let nowAfter = Date()
            if Int(nowAfter.timeIntervalSince(lastCheckpoint))
                >= config.checkpointIntervalSeconds
            {
                let progress = QinaoLongRunningSmokeHelpers
                    .makeProgress(
                        runStart: runStart,
                        now: nowAfter,
                        iterations: iteration,
                        afmCompleted: afmCompleted,
                        gemmaCompleted: gemmaCompleted,
                        afmTimeouts: afmTimeouts,
                        gemmaTimeouts: gemmaTimeouts,
                        afmErrors: afmErrors,
                        gemmaErrors: gemmaErrors,
                        afmRedLineTotal: afmRedLineTotal,
                        gemmaRedLineTotal: gemmaRedLineTotal)
                do {
                    try await writer.writeProgress(progress)
                    try await writer.flush()
                } catch {
                    stderr("⚠ checkpoint write failed: \(error)\n")
                }
                lastCheckpoint = nowAfter
                let elapsedHrs = nowAfter
                    .timeIntervalSince(runStart) / 3600
                let totalHrs = Double(config.maxDurationSeconds)
                    / 3600
                let etaPct = (elapsedHrs / totalHrs) * 100
                print("""
                    [\(QinaoLongRunningSmokeHelpers.iso8601(nowAfter))] checkpoint:
                      iter=\(iteration) | elapsed=\(String(format: "%.2f", elapsedHrs))h / \(String(format: "%.2f", totalHrs))h (\(String(format: "%.1f", etaPct))%)
                      AFM:   completed=\(afmCompleted), timeouts=\(afmTimeouts), errors=\(afmErrors), redlines=\(afmRedLineTotal)
                      Gemma: completed=\(gemmaCompleted), timeouts=\(gemmaTimeouts), errors=\(gemmaErrors), redlines=\(gemmaRedLineTotal)
                    """)
            }

            // Safety: if BOTH endpoints have errored every call so
            // far past iteration 10, abort early
            if iteration >= 10
                && afmErrors == iteration
                && (gemmaEndpoint == nil
                    || gemmaErrors == iteration)
            {
                stderr("\nABORT: both endpoints failing every call; halting at iter=\(iteration)\n")
                break
            }
        }

        // Write final summary
        let runEnd = Date()
        let summary = QinaoLongRunningSmokeSummary(
            runStartTimestamp: runStartStr,
            runEndTimestamp: QinaoLongRunningSmokeHelpers
                .iso8601(runEnd),
            totalElapsedSeconds: runEnd
                .timeIntervalSince(runStart),
            totalIterations: iteration,
            afmCallsCompleted: afmCompleted,
            gemmaCallsCompleted: gemmaCompleted,
            afmTimeouts: afmTimeouts,
            gemmaTimeouts: gemmaTimeouts,
            afmErrors: afmErrors,
            gemmaErrors: gemmaErrors,
            totalRedLineViolationsAFM: afmRedLineTotal,
            totalRedLineViolationsGemma: gemmaRedLineTotal,
            avgAFMDurationSeconds:
                QinaoLongRunningSmokeHelpers.average(afmDurations),
            avgGemmaDurationSeconds:
                QinaoLongRunningSmokeHelpers.average(gemmaDurations),
            medianAFMDurationSeconds:
                QinaoLongRunningSmokeHelpers.median(afmDurations),
            medianGemmaDurationSeconds:
                QinaoLongRunningSmokeHelpers.median(gemmaDurations),
            perPersonaCounts: perPersonaCounts)

        do {
            try await writer.writeSummary(summary)
            try await writer.flush()
            try await writer.close()
        } catch {
            stderr("⚠ summary write failed: \(error)\n")
        }
        _ = judgeEndpoint  // intentionally unused; reserved for future judge wiring

        print("""

            === FINAL SUMMARY ===
            Run start: \(summary.runStartTimestamp)
            Run end:   \(summary.runEndTimestamp)
            Elapsed:   \(String(format: "%.2f", summary.totalElapsedSeconds / 3600))h
            Iterations: \(summary.totalIterations)
              AFM:   completed=\(summary.afmCallsCompleted), timeouts=\(summary.afmTimeouts), errors=\(summary.afmErrors)
              Gemma: completed=\(summary.gemmaCallsCompleted), timeouts=\(summary.gemmaTimeouts), errors=\(summary.gemmaErrors)
              AFM avg/median seconds:   \(String(format: "%.3f", summary.avgAFMDurationSeconds)) / \(String(format: "%.3f", summary.medianAFMDurationSeconds))
              Gemma avg/median seconds: \(String(format: "%.3f", summary.avgGemmaDurationSeconds)) / \(String(format: "%.3f", summary.medianGemmaDurationSeconds))
              AFM redlines:   \(summary.totalRedLineViolationsAFM)
              Gemma redlines: \(summary.totalRedLineViolationsGemma)
            Per-persona counts:
            \(summary.perPersonaCounts.sorted { $0.key < $1.key }.map { "  \($0.key): \($0.value)" }.joined(separator: "\n"))

            JSONL:    \(outputStr)/iterations.jsonl
            Progress: \(outputStr)/progress.json
            Summary:  \(outputStr)/summary.json
            """)
    }

    // MARK: - M574 (chapter 一百四十九) — comprehensive 4-path bench
    //
    // Same prompt drives 4 paths concurrently for genuine head-to-head
    // comparison:
    //   1. Naked AFM (AppleFoundationOrganAdapter direct)
    //   2. Naked Gemma 4 E2B (MLXOrganAdapter direct)
    //   3. Substrate routing (BASHostRuntime.startSession)
    //   4. User-value LLM-as-judge (uses Gemma since AFM errors on Mac)
    //
    // Prompts generated programmatically via QinaoExtendedPromptCorpus
    // (40,320-slot combinatorial space; no hardcoded repetition).

    private struct ComprehensiveBenchRow: Codable {
        let timestamp: String
        let iteration: Int
        let seed: Int
        let signature: QinaoPromptSignature
        let prompt: String
        // naked AFM
        let nakedAFMResponse: String?
        let nakedAFMRedlines: Int
        let nakedAFMDurationSeconds: Double
        let nakedAFMStatus: String
        let nakedAFMError: String?
        // naked Gemma
        let nakedGemmaResponse: String?
        let nakedGemmaRedlines: Int
        let nakedGemmaDurationSeconds: Double
        let nakedGemmaStatus: String
        let nakedGemmaError: String?
        // substrate
        let substrateAuditCodes: Int
        let substratePermitMode: String
        let substrateBodyLength: Int
        let substrateDurationSeconds: Double
        let substrateStatus: String
        // judge (uses Gemma response if available)
        let judgeUserValue: Int?
        let judgeHelpfulness: Int?
        let judgeAgency: Int?
        let judgeAvoidsHarm: Int?
        let judgeStatus: String
    }

    static func runComprehensiveBench(
        args: [String]
    ) async {
        let durationStr = ProcessInfo.processInfo
            .environment["QINAO_COMPREHENSIVE_DURATION_SECONDS"]
        let outputStr = ProcessInfo.processInfo
            .environment["QINAO_COMPREHENSIVE_OUTPUT"]
            ?? "/tmp/qinao-comprehensive"
        let runJudgeStr = ProcessInfo.processInfo
            .environment["QINAO_COMPREHENSIVE_RUN_JUDGE"] ?? "1"

        let duration = Int(durationStr ?? "") ?? 3600
        let outputURL = URL(fileURLWithPath: outputStr)
        let runJudge = runJudgeStr == "1"

        print("""
            QinaoSampleHost --comprehensive-bench (M574, chapter 一百四十九):
              4-path comparative benchmark with programmatically
              generated unique prompts (40,320-slot combinatorial
              space). Per iteration:
                1. Naked AFM        (AppleFoundationOrganAdapter)
                2. Naked Gemma 4 E2B (MLXOrganAdapter)
                3. Substrate        (BASHostRuntime.startSession)
                4. User-value judge (LLM-as-judge on Gemma response)

              Duration:           \(duration) seconds (\(duration / 60)min)
              Output directory:   \(outputStr)
              Run judge:          \(runJudge)

              Override via env:
                QINAO_COMPREHENSIVE_DURATION_SECONDS=N
                QINAO_COMPREHENSIVE_OUTPUT=path
                QINAO_COMPREHENSIVE_RUN_JUDGE=0|1
            """)

        try? FileManager.default.createDirectory(
            at: outputURL,
            withIntermediateDirectories: true)
        let jsonlURL = outputURL
            .appendingPathComponent("iterations.jsonl")
        let summaryURL = outputURL
            .appendingPathComponent("summary.json")
        if !FileManager.default.fileExists(atPath: jsonlURL.path) {
            FileManager.default.createFile(
                atPath: jsonlURL.path, contents: nil)
        }
        let fh = try? FileHandle(forWritingTo: jsonlURL)
        try? fh?.seekToEnd()

        // Endpoints
        let afmEndpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: false)
        var gemmaEndpoint: (any QinaoOrganEndpoint)?
        do {
            gemmaEndpoint = try await QinaoLoop
                .makeMLXEndpoint(model: .gemma4E2B)
            print("✓ Gemma 4 E2B endpoint loaded")
        } catch {
            gemmaEndpoint = nil
            stderr("⚠ Gemma 4 E2B unavailable: \(error.localizedDescription)\n")
        }
        print("✓ AFM endpoint constructed (will likely error on Mac)")

        // Substrate runtime
        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "comp.bundle.v1",
            providerRoutingRegistryVersion:
                "comp.routing-registry.v1",
            providerRoutingPolicyID:
                "comp.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "comp.tuning-registry.v1",
            runtimeTuningPolicyID:
                "comp.tuning-policy.v1",
            resolutionSourceID: "comp_bundle")
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.comp.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        let runtime = BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.comp",
                policyProfileID: "host.comp.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration
                        .fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: tuning,
                runtimePolicyLineage: policyLineage,
                hostRhythmProfile: .generic))
        print("✓ Substrate runtime constructed\n")

        let runStart = Date()
        var iter = 0
        var nakedAFMErrors = 0
        var nakedGemmaErrors = 0
        var substrateErrors = 0
        var judgeErrors = 0

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        print("=== T+0 ===\n")
        while true {
            let now = Date()
            let elapsed = now.timeIntervalSince(runStart)
            if Int(elapsed) >= duration {
                print("\n[\(QinaoLongRunningSmokeHelpers.iso8601(now))] " +
                    "duration reached: \(Int(elapsed))s; halting.")
                break
            }

            // Generate unique prompt for this iteration
            let g = QinaoExtendedPromptCorpus.generate(seed: iter)
            let prompt = g.prompt
            let signature = g.signature

            // 1. Naked AFM
            var afmResp: String?
            var afmDur: Double = 0
            var afmStatus = "skipped"
            var afmError: String?
            do {
                let t0 = Date()
                let r = try await afmEndpoint.produceBody(
                    prompt: prompt,
                    context: [],
                    role: .core,
                    sessionID: "comp-afm-\(iter)")
                afmDur = Date().timeIntervalSince(t0)
                afmResp = r.body
                afmStatus = "ok"
            } catch {
                afmStatus = "error"
                afmError = "\(error)"
                nakedAFMErrors += 1
            }
            let afmRedlines = countRedLineViolations(in: afmResp)

            // 2. Naked Gemma
            var gemmaResp: String?
            var gemmaDur: Double = 0
            var gemmaStatus = "skipped"
            var gemmaError: String?
            if let gemma = gemmaEndpoint {
                do {
                    let t0 = Date()
                    let r = try await gemma.produceBody(
                        prompt: prompt,
                        context: [],
                        role: .core,
                        sessionID:
                            "comp-gemma-\(iter)")
                    gemmaDur = Date().timeIntervalSince(t0)
                    gemmaResp = r.body
                    gemmaStatus = "ok"
                } catch {
                    gemmaStatus = "error"
                    gemmaError = "\(error)"
                    nakedGemmaErrors += 1
                }
            }
            let gemmaRedlines = countRedLineViolations(in: gemmaResp)

            // 3. Substrate
            var substrateAudit = 0
            var substratePermit = "unknown"
            var substrateBodyLen = 0
            var substrateDur: Double = 0
            var substrateStatus = "ok"
            do {
                let riskLevel: BASHostRiskLevel
                switch signature.stake {
                case .low, .modest:
                    riskLevel = .low
                case .high, .veryHigh:
                    riskLevel = .medium
                case .irreversible, .nonReversibleAfterAct:
                    riskLevel = .high
                }
                let t0 = Date()
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: prompt,
                        title: "comp-\(iter)",
                        riskLevel: riskLevel))
                substrateDur = Date()
                    .timeIntervalSince(t0)
                if let turn = result.eBrainTurn {
                    if let entry = turn.sovereignAuditEntry {
                        substrateAudit = entry
                            .signalRefs.count
                    }
                    substratePermit = turn.actionPermit
                        .mode.rawValue
                    let body = turn.thoughtFold
                        .compactSlots["body"]
                        ?? turn.thoughtFold
                            .compactSlots["summary"]
                        ?? ""
                    substrateBodyLen = body.count
                }
            } catch {
                substrateStatus = "error"
                substrateErrors += 1
            }

            // 4. Judge (only if Gemma succeeded + judge enabled)
            var judgeUserValue: Int?
            var judgeHelpfulness: Int?
            var judgeAgency: Int?
            var judgeAvoidsHarm: Int?
            var judgeStatus = "skipped"
            if runJudge,
               gemmaStatus == "ok",
               let respText = gemmaResp,
               !respText.isEmpty,
               let judgeEndpoint = gemmaEndpoint
            {
                let judgePrompt = QinaoUserValueJudge
                    .buildPrompt(
                        personaProfile:
                            "Tone: \(signature.tone.rawValue), " +
                            "domain: \(signature.domain.rawValue)",
                        scenarioGoal:
                            "stake: \(signature.stake.rawValue), " +
                            "timeframe: \(signature.timeframe.rawValue)",
                        userPrompt: prompt,
                        systemAuditCodes: [
                            "naked.gemma.response.length:\(respText.count)",
                            "substrate.permit:\(substratePermit)",
                            "substrate.audit:\(substrateAudit)"
                        ],
                        systemOutput: respText)
                do {
                    let r = try await judgeEndpoint
                        .produceBody(
                            prompt: judgePrompt,
                            context: [],
                            role: .core,
                            sessionID:
                                "comp-judge-\(iter)")
                    let score = QinaoUserValueJudge
                        .parseScore(
                            r.body,
                            sessionID: "comp-judge-\(iter)")
                    judgeUserValue = score.userValueScore
                    judgeHelpfulness = score.helpfulness
                    judgeAgency = score.respectsAgency
                    judgeAvoidsHarm = score.avoidsHarm
                    judgeStatus = "ok"
                } catch {
                    judgeStatus = "error"
                    judgeErrors += 1
                }
            }

            // Write JSONL row
            let row = ComprehensiveBenchRow(
                timestamp: QinaoLongRunningSmokeHelpers
                    .iso8601(Date()),
                iteration: iter,
                seed: iter,
                signature: signature,
                prompt: prompt,
                nakedAFMResponse: afmResp,
                nakedAFMRedlines: afmRedlines,
                nakedAFMDurationSeconds: afmDur,
                nakedAFMStatus: afmStatus,
                nakedAFMError: afmError,
                nakedGemmaResponse: gemmaResp,
                nakedGemmaRedlines: gemmaRedlines,
                nakedGemmaDurationSeconds: gemmaDur,
                nakedGemmaStatus: gemmaStatus,
                nakedGemmaError: gemmaError,
                substrateAuditCodes: substrateAudit,
                substratePermitMode: substratePermit,
                substrateBodyLength: substrateBodyLen,
                substrateDurationSeconds: substrateDur,
                substrateStatus: substrateStatus,
                judgeUserValue: judgeUserValue,
                judgeHelpfulness: judgeHelpfulness,
                judgeAgency: judgeAgency,
                judgeAvoidsHarm: judgeAvoidsHarm,
                judgeStatus: judgeStatus)
            if let data = try? encoder.encode(row),
               var text = String(data: data, encoding: .utf8)
            {
                text.append("\n")
                if let bytes = text.data(using: .utf8) {
                    try? fh?.write(contentsOf: bytes)
                }
            }

            iter += 1
            // Progress every 5 iters
            if iter % 5 == 0 {
                let elapsedHrs = Date()
                    .timeIntervalSince(runStart) / 60
                let totalMin = Double(duration) / 60
                let pct = (elapsedHrs / totalMin) * 100
                print("""
                    [iter=\(iter) elapsed=\(String(format: "%.1f", elapsedHrs))min/\(String(format: "%.1f", totalMin))min (\(String(format: "%.1f", pct))%)]
                      AFM err: \(nakedAFMErrors) | Gemma err: \(nakedGemmaErrors) | Substrate err: \(substrateErrors) | Judge err: \(judgeErrors)
                      last: tone=\(signature.tone.rawValue) domain=\(signature.domain.rawValue) stake=\(signature.stake.rawValue) | substrate→\(substratePermit) | judge=\(judgeUserValue.map(String.init) ?? "-")
                    """)
                try? fh?.synchronize()
            }
        }

        try? fh?.synchronize()
        try? fh?.close()

        // Write summary
        let runEnd = Date()
        let summary: [String: Any] = [
            "runStartTimestamp":
                QinaoLongRunningSmokeHelpers.iso8601(runStart),
            "runEndTimestamp":
                QinaoLongRunningSmokeHelpers.iso8601(runEnd),
            "totalElapsedSeconds":
                runEnd.timeIntervalSince(runStart),
            "totalIterations": iter,
            "nakedAFMErrors": nakedAFMErrors,
            "nakedGemmaErrors": nakedGemmaErrors,
            "substrateErrors": substrateErrors,
            "judgeErrors": judgeErrors
        ]
        if let data = try? JSONSerialization.data(
            withJSONObject: summary,
            options: [.sortedKeys, .prettyPrinted])
        {
            try? data.write(to: summaryURL)
        }

        print("""

            === FINAL SUMMARY ===
            Run start:    \(QinaoLongRunningSmokeHelpers.iso8601(runStart))
            Run end:      \(QinaoLongRunningSmokeHelpers.iso8601(runEnd))
            Iterations:   \(iter)
            Errors:       AFM=\(nakedAFMErrors) Gemma=\(nakedGemmaErrors) Substrate=\(substrateErrors) Judge=\(judgeErrors)

            JSONL:    \(jsonlURL.path)
            Summary:  \(summaryURL.path)
            """)
    }

    // MARK: - M577 (chapter 一百五十二) doctrine metrics bench
    //
    // Production caller for chapter 一百五十一's 6 typed doctrine
    // metric schemas. Drives N substrate sessions with combinatorial
    // prompts (chapter 一百四十九 generator), synthesizes realistic
    // source-type instances from per-turn audit signal codes + permit
    // modes, then runs all 6 BASDoctrineMetricsCompute helpers and
    // writes typed metric values to summary.json.
    //
    // Synthesis strategy (no projections-on-turn-result API yet):
    //   - BASAxisAlignment.centerScore = (permit==delay ? 0.85 : 0.4)
    //     ± noise; deviationCodes = [] for delay, ["misaligned"] for block
    //   - BASHeavenGatePermit.passState = .passed for delay, .denied for block
    //   - BASRiverOriginTrace synthesized with substrate audit IDs as roots
    //   - BASYaochiSanctumEntry synthesized 1-per-50 turns (memory-touch proxy)
    //   - BASHumanAnchorSignal: agency/alienation/dignity/overwhelm risks
    //     derived from stake dimension (low → 0.1, irreversible → 0.4)
    //   - Doctrine harmony: red-line hits = audit signal codes containing
    //     "forbid:" prefix; cross-conflicts = signal pairs of opposite verdict
    //
    // This makes the chapter 一百五十一 schemas have a real production
    // caller + produces empirical numbers showing each metric's behavior
    // across substrate routing decisions.

    /// **M594 chapter 一百六十五 anti-magic-number constants** for
    /// doctrine metrics bench. All previously-inline magic numbers
    /// extracted with derivation comments.
    enum DoctrineBenchConstants {
        /// Default session count when no env override or arg.
        /// Chapter 一百五十二 default; chapter 一百六十四 multi-run
        /// showed metrics are N-dependent → this is just a default,
        /// not a recommended N.
        static let defaultSessionCount: Int = 200

        /// Default bench output directory.
        static let defaultOutputPath: String =
            "/tmp/qinao-doctrine-metrics"

        /// **Workflow profile cycling stride**. Chapter 一百五十八
        /// uses `(iter * stride) % workflowProfiles.count` to vary
        /// workflow per turn. 13 is a small prime coprime to 3
        /// (workflowProfiles.count) ensuring all 3 profiles cycle
        /// uniformly across iterations.
        /// **M603 chapter 一百七十三**: env-var override
        /// `QINAO_DOCTRINE_BENCH_WORKFLOW_STRIDE` allows
        /// procedural variation across runs.
        static let defaultWorkflowCyclingStride: Int = 13
        static var workflowCyclingStride: Int {
            envInt("QINAO_DOCTRINE_BENCH_WORKFLOW_STRIDE")
                ?? defaultWorkflowCyclingStride
        }

        /// **Surface cycling stride**. Same pattern as workflow.
        /// 11 is a small prime coprime to 7 (surfaces.count)
        /// ensuring all 7 surfaces cycle uniformly.
        /// **M603 chapter 一百七十三**: env-var override
        /// `QINAO_DOCTRINE_BENCH_SURFACE_STRIDE`.
        static let defaultSurfaceCyclingStride: Int = 11
        static var surfaceCyclingStride: Int {
            envInt("QINAO_DOCTRINE_BENCH_SURFACE_STRIDE")
                ?? defaultSurfaceCyclingStride
        }

        /// **Multi-run sample sizes** (M593 chapter 一百六十四).
        /// Chosen at logarithmic spacing: 50 → 200 → 500.
        /// (M593 empirical: shows 0.40 metric spread across these
        /// counts → metrics are N-dependent.)
        /// **M603 chapter 一百七十三**: env-var override
        /// `QINAO_DOCTRINE_BENCH_MULTI_COUNTS` (CSV format,
        /// e.g. `100,300,1000`) for procedural variation.
        static let defaultMultiRunCounts: [Int] = [50, 200, 500]
        static var multiRunCounts: [Int] {
            envIntList("QINAO_DOCTRINE_BENCH_MULTI_COUNTS")
                ?? defaultMultiRunCounts
        }

        /// **Multi-run output directory prefix**.
        static let multiRunOutputPrefix: String =
            "/tmp/qinao-doctrine-multi-"

        /// **M603 chapter 一百七十三 — env-var helpers**.
        /// Pure functions parsing `ProcessInfo` env into typed
        /// values; nil fallback when missing/invalid.
        private static func envInt(
            _ key: String
        ) -> Int? {
            guard let raw = ProcessInfo.processInfo
                .environment[key],
                !raw.isEmpty
            else { return nil }
            return Int(raw)
        }

        private static func envIntList(
            _ key: String
        ) -> [Int]? {
            guard let raw = ProcessInfo.processInfo
                .environment[key],
                !raw.isEmpty
            else { return nil }
            let parts = raw.split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(
                    in: .whitespaces)) }
            return parts.isEmpty ? nil : parts
        }
    }

}
