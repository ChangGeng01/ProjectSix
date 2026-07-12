// MARK: - SampleHostRuntimeBenchExtensions — chapter 二百九十四 / M781
//
// Phase Alpha 第二十刀(QinaoSampleHost god file 7th cut):从
// `main.swift` 抽出 production runtime + empirical-bench cluster
// 的 3 个 helper functions — Phase Alpha 第四个 god file 第七次拆分。
//
// 抽出 helpers (Swift extension on QinaoSampleHost):
//   - `runFullStackDemo` (M272+M279) — orchestrates every
//     M254-M270 seam in one demo flow (wiring proof, not eval)
//   - `runNakedVsSubstrateBench` (chapter 一百四十一) — naked LLM
//     vs full substrate path empirical comparison bench
//   - `runUserValueJudgeBench` (chapter 一百四十一) — LLM-as-judge
//     user-value scoring bench
//
// **0 behavior change**:helpers literal-identical to pre-extraction
// versions,只是改成了 Swift extension on QinaoSampleHost。Module
// DAG 不变(同 module 内部 split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 一百四十一 假设债 empirical comparison preserved
//   - M272+M279 full-stack wiring proof preserved

import Foundation
import BASAppleAdapters
import BASHostKit
import BASMLXAdapter
import BASOrgan
import BASOrchestration
import BASRuntimeCore
import QinaoLoop
import QinaoMLX
import QinaoWorldPrior

extension QinaoSampleHost {
    // MARK: - M272 full-stack demo

    /// Orchestrate every M254-M270 seam in one demo flow.
    /// Wiring proof, not an eval — uses bare Gemma so curriculum
    /// markers don't add noise.
    static func runFullStackDemo() async {
        print("""
            QinaoSampleHost --full-stack-demo (M272+M279):
              wires M254 multi-turn + M255 router + M259/M261
              lifecycle + M265 audit hook + M268 storage in one
              flow. M279: primary is real Apple Foundation
              Models (serves on iOS 18.1+/macOS 26+ with Apple
              Intelligence enabled; throws providerUnavailable
              elsewhere → router falls through to MLX Gemma).
            """)

        // 1. Router: real Apple FM primary + MLX Gemma secondary
        // (M279 — was StubFailingAdapter pre-M279).
        // Apple FM serves when Apple Intelligence is available;
        // otherwise it throws providerUnavailable on first
        // draft and the M255 router falls through to MLX.
        // Same fallback semantics as the M272 stub demo, but
        // now hosts with AI enabled actually see Apple FM run.
        let primary = AppleFoundationOrganAdapter()
        let secondary = MLXOrganAdapter(
            model: MLXModelCatalog.gemma4_E2B_4bit)
        do {
            try await secondary.loadModel()
            try await secondary.prewarm()
        } catch {
            stderr("error: secondary load failed: \(error)\n")
            exit(2)
        }
        let router = BASRoutingOrganAdapter(
            primary: primary,
            secondary: secondary,
            strategy: .primaryWithFallback)
        print("""

            ━━━ Step 1/5 — Router built (M255+M279) ━━━
            primary:    \(primary.descriptor.providerID)
                        (Apple FM — serves if Apple
                        Intelligence on this device, else
                        falls through)
            secondary:  \(secondary.descriptor.providerID)
                        (MLX Gemma — always available)
            descriptor: \(router.descriptor.providerID)
            """)

        // 2. Lifecycle coordinator with audit + storage
        // M298 — derive co-located paths through
        // `BASUnifiedStorageLocator` so the audit-ledger SQLite
        // and lifecycle stores share one deployment root. The
        // demo only spins up the lifecycle JSON file (existing
        // M268 form), but the locator pin-prints the canonical
        // SQLite ledger URL alongside it — proof that hosts can
        // wire both stores from one root without hardcoding
        // filenames.
        let demoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-full-stack-demo-\(UUID().uuidString)")
        let unifiedLocations: BASUnifiedStorageLocator.Locations
        do {
            unifiedLocations = try BASUnifiedStorageLocator
                .locate(in: demoRoot)
        } catch {
            stderr("error: locator failed: \(error)\n")
            exit(2)
        }
        // JSON file lives next to where the SQLite ledger would
        // land — same root, distinct filename so M283's
        // two-store guarantee remains untouched.
        let storageURL = unifiedLocations.root
            .appendingPathComponent("lifecycle.json")
        try? FileManager.default.removeItem(at: storageURL)
        let storage =
            BASUpdateTicketLifecycleJSONFileStorage(
                url: storageURL)
        let auditCapture = AuditCaptureBox()
        let coord = BASUpdateTicketLifecycleCoordinator(
            auditSink: { entry in
                await auditCapture.append(entry)
            },
            storage: storage)
        print("""

            ━━━ Step 2/5 — Lifecycle coordinator built (M259+M265+M268+M298) ━━━
            unified root:    \(unifiedLocations.root.lastPathComponent)
            audit ledger:    \(unifiedLocations.auditLedgerURL.lastPathComponent) (canonical, M91)
            lifecycle store: \(unifiedLocations.lifecycleURL.lastPathComponent) (canonical, M270)
            demo storage:    \(storageURL.lastPathComponent) (JSON form, M268)
            audit sink:      enabled (in-memory capture)
            """)

        // 3. 3-turn conversation via secondary (M254)
        let convoID = "demo-convo-\(UUID().uuidString)"
        let prompts = [
            "Tell me about photosynthesis briefly.",
            "What's the chemical equation?",
            "Where in the cell does it happen?",
        ]
        var drafts: [BASOrganDraft] = []
        print("""

            ━━━ Step 3/5 — 3-turn conversation (M254) ━━━
            """)
        for (i, prompt) in prompts.enumerated() {
            let req = BASOrganRequest(
                requestID: "demo-\(i)",
                role: .scout,
                preset: .scout,
                instruction: prompt)
            let start = ContinuousClock().now
            do {
                let draft = try await secondary
                    .draftMultiTurn(req, sessionID: convoID)
                let ms = elapsedMs(
                    ContinuousClock().now - start)
                drafts.append(draft)
                print("""

                  Turn \(i + 1): "\(prompt)"
                  (\(format(ms: ms)))
                  \(indented(draft.body))
                """)
            } catch {
                print("  Turn \(i + 1) error: \(error)")
            }
        }

        // Verify router served via either path (M279 update —
        // either Apple FM primary or MLX secondary is a
        // success; the doctrine claim is "router picks one
        // healthy provider", not "always falls through").
        do {
            let routerDraft = try await router.draft(
                BASOrganRequest(
                    requestID: "demo-router",
                    role: .scout,
                    preset: .scout,
                    instruction:
                        "Summarize photosynthesis in one line."))
            let pid = routerDraft.providerID
            let primaryServed =
                pid == primary.descriptor.providerID
            let fellThrough =
                pid == secondary.descriptor.providerID
            print("""

              Router verification (M279):
              served by:  \(pid)
              served via: \(primaryServed
                  ? "primary (Apple FM available)"
                  : (fellThrough
                      ? "secondary (Apple FM unavailable → MLX fallback)"
                      : "unknown"))
              outcome:    \(primaryServed || fellThrough ? "✓" : "⚠")
            """)
        } catch {
            print("  Router error: \(error)")
        }

        // 4. Synthesize tickets + ingestTurn auto-flow
        var tickets: [BASUpdateTicket] = []
        for (i, draft) in drafts.enumerated() {
            tickets.append(
                BASUpdateTicket(
                    ticketID: "demo-tic-\(i)-\(convoID)",
                    sessionRef: convoID,
                    summary: draft.body,
                    confidence: 0.65))
        }
        let newCount = await coord.ingestTurn(tickets)
        print("""

            ━━━ Step 4/5 — \(newCount) tickets ingested (M261 auto-flow) ━━━
            """)

        // 5. Walk first ticket through full state machine
        guard let firstTicket = tickets.first else {
            print("no tickets to walk; aborting demo")
            return
        }
        let id = firstTicket.ticketID
        do {
            try await coord.startTrial(
                ticketID: id, trialRecordRef: "demo-shadow-1")
            try await coord.markTrialOutcome(
                ticketID: id,
                outcome: .passed(reasonCodes: [
                    "demo:effect-confirmed"]))
            try await coord.approveForDistillation(
                ticketID: id,
                sovereignVerdictRef: "demo-vrdct-1")
            try await coord.markDistilled(
                ticketID: id,
                reasonCodes: ["demo:pipeline-checkpoint"])
        } catch {
            print("lifecycle walk error: \(error)")
        }

        // 6. Restart-and-load via M268 storage
        let coordReloaded =
            BASUpdateTicketLifecycleCoordinator(
                storage: storage)
        do {
            try await coordReloaded.restore()
        } catch {
            print("restore error: \(error)")
        }
        let reloadedEntry = await coordReloaded.entry(
            ticketID: id)
        let reloadedCount = await coordReloaded.count()
        let auditEntries = await auditCapture.entries

        print("""

            ━━━ Step 5/5 — Lifecycle terminal + storage reload (M265+M268) ━━━
            ticket \(id):
              state after walk:        \(reloadedEntry?.state.rawValue ?? "MISSING")
              transition history:      \(reloadedEntry?.history.count ?? 0) entries
              sovereign verdict ref:   \(reloadedEntry?.sovereignVerdictRef ?? "n/a")
            reloaded coordinator:
              total entries on disk:   \(reloadedCount)
            audit sink fired:
              terminal events captured: \(auditEntries.count)
              first audit ID:          \(auditEntries.first?.auditID ?? "none")

            ━━━ Demo complete — every M254-M270+M298 seam exercised ━━━
            """)

        // M298 — clean the entire unified root, not just the
        // lifecycle JSON file, so we don't leak the empty dir.
        try? FileManager.default.removeItem(
            at: unifiedLocations.root)
    }

    // MARK: - M306 multi-session demo

    /// M306 — drive two sequential `BASHostRuntime` sessions
    /// sharing one SQLite-backed audit ledger and print the
    /// cross-session continuity outcome. The actual demo logic
    /// lives in `MultiSessionContinuityDemo.run(...)` so unit
    /// tests can exercise it without driving the executable.
    static func runNakedVsSubstrateBench() async {
        print("""
            QinaoSampleHost --naked-vs-substrate-bench (M561-M565, chapter 一百四十一):
              Real-machine smoke test of assumption #1 (14 层架构必要).
              For each of 5 prompts, run THREE paths:
                1. Naked AFM (AppleFoundationOrganAdapter)
                2. Naked Gemma 4 E2B (MLX)
                3. Substrate (BASHostRuntime)
              Count BR red-line violations using 5 lint helpers.
              Report side-by-side comparison.
              AFM/Gemma may graceful-skip if unavailable.
            """)

        // Try AFM endpoint
        let afmEndpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: false)
        // Try Gemma 4 E2B endpoint
        var gemmaEndpoint: (any QinaoOrganEndpoint)?
        do {
            gemmaEndpoint = try await QinaoLoop
                .makeMLXEndpoint(model: .gemma4E2B)
            print("  ✓ Gemma 4 E2B endpoint loaded")
        } catch {
            gemmaEndpoint = nil
            stderr("  ⚠ Gemma 4 E2B unavailable: \(error.localizedDescription)\n")
        }
        print("  ✓ AFM endpoint constructed (deterministic fallback off)\n")

        // Build substrate runtime
        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "naked-vs-substrate.bundle.v1",
            providerRoutingRegistryVersion:
                "nvs.routing-registry.v1",
            providerRoutingPolicyID:
                "nvs.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "nvs.tuning-registry.v1",
            runtimeTuningPolicyID:
                "nvs.tuning-policy.v1",
            resolutionSourceID: "nvs_bundle")
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.nvs.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        let configuration = BASHostConfiguration(
            runtimeProfileID: "host.nvs",
            policyProfileID: "host.nvs.policy",
            prefersPureLocal: true,
            defaultDeviceState:
                BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: tuning,
            runtimePolicyLineage: policyLineage,
            hostRhythmProfile: .generic)
        let runtime = BASHostRuntime(
            configuration: configuration)

        // Pick 5 prompts (1 per persona, varied scenarios)
        let smokeprompts: [(persona: QinaoSyntheticUserPersona,
                            scenario: QinaoSyntheticUserScenario)] = [
            (.anxious, .irreversibleStep),
            (.authoritative, .timePressure),
            (.vulnerable, .boundaryNegotiation),
            (.agentic, .irreversibleStep),
            (.confused, .boundaryNegotiation),
        ]

        var comparisons:
            [QinaoNakedVsSubstrateComparison] = []
        for entry in smokeprompts {
            let prompt = QinaoSyntheticPromptCatalog.prompt(
                persona: entry.persona,
                scenario: entry.scenario)
            // 1. Naked AFM
            var afmResponse: String?
            do {
                let r = try await afmEndpoint
                    .produceBody(
                        prompt: prompt,
                        context: [],
                        role: .core,
                        sessionID: "nvs-afm-\(entry.persona.rawValue)")
                afmResponse = r.body
            } catch {
                afmResponse = nil
            }
            // 2. Naked Gemma 4 E2B
            var gemmaResponse: String?
            if let gemma = gemmaEndpoint {
                do {
                    let r = try await gemma.produceBody(
                        prompt: prompt,
                        context: [],
                        role: .core,
                        sessionID: "nvs-gemma-\(entry.persona.rawValue)")
                    gemmaResponse = r.body
                } catch {
                    gemmaResponse = nil
                }
            }
            // 3. Substrate
            let riskLevel: BASHostRiskLevel
            switch entry.persona {
            case .anxious, .vulnerable: riskLevel = .high
            case .authoritative, .agentic: riskLevel = .medium
            case .confused: riskLevel = .low
            }
            var substrateAuditCount = 0
            var substratePermitMode = "unknown"
            var substrateBody: String?
            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: prompt,
                        title: "nvs-\(entry.persona.rawValue)",
                        riskLevel: riskLevel))
                if let turn = result.eBrainTurn,
                   let entry = turn.sovereignAuditEntry {
                    substrateAuditCount = entry.signalRefs.count
                    substratePermitMode =
                        turn.actionPermit.mode.rawValue
                    substrateBody = turn.thoughtFold
                        .compactSlots["body"]
                        ?? turn.thoughtFold
                            .compactSlots["summary"]
                }
            } catch {
                // substrate failure → leave defaults
            }

            // Count BR red-line violations on each output text
            let afmViolations =
                countRedLineViolations(in: afmResponse)
            let gemmaViolations =
                countRedLineViolations(in: gemmaResponse)
            let substrateViolations =
                countRedLineViolations(in: substrateBody)

            let comparison = QinaoNakedVsSubstrateComparator
                .makeComparison(
                    prompt: prompt,
                    nakedAFMResponse: afmResponse,
                    nakedOpenModelResponse: gemmaResponse,
                    substrateAuditCodeCount: substrateAuditCount,
                    substratePermitMode: substratePermitMode,
                    substrateOutputBody: substrateBody,
                    nakedAFMRedLineCount: afmViolations,
                    nakedOpenModelRedLineCount: gemmaViolations,
                    substrateRedLineCount: substrateViolations)
            comparisons.append(comparison)
            print("[\(entry.persona.rawValue) / \(entry.scenario.rawValue)]")
            print(QinaoNakedVsSubstrateComparator
                .formatRow(comparison))
            print("")
        }

        let aggregate = QinaoComparatorAggregate.aggregate(
            comparisons: comparisons)
        print("""
            ━━━ Aggregate (\(aggregate.totalPrompts) prompts) ━━━
            Naked AFM    available: \(aggregate.nakedAFMAvailableCount) / \(aggregate.totalPrompts);  total RL violations: \(aggregate.nakedAFMTotalViolations)
            Naked Gemma  available: \(aggregate.nakedOpenModelAvailableCount) / \(aggregate.totalPrompts);  total RL violations: \(aggregate.nakedOpenModelTotalViolations)
            Substrate   available: \(aggregate.substrateOutputAvailableCount) / \(aggregate.totalPrompts);  total RL violations: \(aggregate.substrateTotalViolations)
            ════════════════════════════════════════════════
            """)
    }

    /// Count BR red-line violations in `text` using the 5 lint
    /// helpers. Returns 0 when text is nil.
    static func countRedLineViolations(
        in text: String?
    ) -> Int {
        guard let text = text, !text.isEmpty else { return 0 }
        var count = 0
        // Cthulhu doctrine red lines
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            for pattern in redLine.forbiddenSubstrings {
                if text.lowercased().contains(
                    pattern.lowercased()) {
                    count += 1
                }
            }
        }
        // Kunlun doctrine red lines
        for redLine in BASKunlunDoctrineRedLine.allCases {
            for pattern in redLine.forbiddenSubstrings {
                if text.lowercased().contains(
                    pattern.lowercased()) {
                    count += 1
                }
            }
        }
        // Product red lines
        count += BASProductRedLineLinter.lint(
            inputs: [text]).count
        // BadTone rules
        count += BASBadToneLinter.lint(
            inputs: [text]).count
        return count
    }

    static func runUserValueJudgeBench() async {
        print("""
            QinaoSampleHost --user-value-judge-bench (M566-M570, chapter 一百四十一):
              Real-machine smoke test of assumption #4 (typed primitives → user value).
              For 5 (persona × scenario) pairs:
                1. Drive substrate (BASHostRuntime) with persona prompt
                2. Capture audit signalRefs + permit mode + output body
                3. Ask LLM-as-judge: "did the system help?"
                4. Score 0-100 with helpfulness / agency / avoids-harm subscores
              Tries AFM first; falls back to Gemma 4 E2B if AFM unavailable.
            """)

        // Try AFM first; fall back to Gemma 4 E2B
        var judgeEndpoint: any QinaoOrganEndpoint = await QinaoLoop
            .makeAppleFoundationEndpoint(
                includeDeterministicFallback: false)
        var judgeProvider = "AFM"
        // Smoke-test AFM with a tiny prompt to detect Code 1026
        do {
            _ = try await judgeEndpoint.produceBody(
                prompt: "test",
                context: [],
                role: .scout,
                sessionID: "afm-availability-probe")
        } catch {
            stderr("  ⚠ AFM unavailable (\(error.localizedDescription)); falling back to Gemma 4 E2B\n")
            do {
                judgeEndpoint = try await QinaoLoop
                    .makeMLXEndpoint(model: .gemma4E2B)
                judgeProvider = "Gemma 4 E2B"
            } catch {
                stderr("  ✗ Gemma 4 E2B also unavailable: \(error.localizedDescription)\n")
                stderr("  cannot proceed without LLM judge — exiting\n")
                return
            }
        }
        print("  ✓ Judge endpoint: \(judgeProvider)\n")

        let policyLineage = BASRuntimePolicyLineage(
            bundleVersion: "uvj.bundle.v1",
            providerRoutingRegistryVersion:
                "uvj.routing-registry.v1",
            providerRoutingPolicyID: "uvj.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "uvj.tuning-registry.v1",
            runtimeTuningPolicyID: "uvj.tuning-policy.v1",
            resolutionSourceID: "uvj_bundle")
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.uvj.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        let configuration = BASHostConfiguration(
            runtimeProfileID: "host.uvj",
            policyProfileID: "host.uvj.policy",
            prefersPureLocal: true,
            defaultDeviceState:
                BASHostConfiguration.fixtureDefaultDeviceState,
            console: .generic,
            lifecycleBehavior: .generic,
            workflowBehavior: .generic,
            cognitionBehavior: .generic,
            presentation: .generic,
            runtimeTuning: tuning,
            runtimePolicyLineage: policyLineage,
            hostRhythmProfile: .generic)
        let runtime = BASHostRuntime(
            configuration: configuration)

        let smokeprompts: [(persona: QinaoSyntheticUserPersona,
                            scenario: QinaoSyntheticUserScenario)] = [
            (.anxious, .irreversibleStep),
            (.authoritative, .timePressure),
            (.vulnerable, .boundaryNegotiation),
            (.agentic, .irreversibleStep),
            (.confused, .boundaryNegotiation),
        ]

        var scores: [QinaoUserValueScore] = []
        for entry in smokeprompts {
            let prompt = QinaoSyntheticPromptCatalog.prompt(
                persona: entry.persona,
                scenario: entry.scenario)
            let riskLevel: BASHostRiskLevel
            switch entry.persona {
            case .anxious, .vulnerable: riskLevel = .high
            case .authoritative, .agentic: riskLevel = .medium
            case .confused: riskLevel = .low
            }
            var auditCodes: [String] = []
            var output: String?
            do {
                let result = try runtime.startSession(
                    BASHostSessionRequest(
                        kind: .interactive,
                        workflowProfile: .reflective,
                        surface: .application,
                        prompt: prompt,
                        title: "uvj-\(entry.persona.rawValue)",
                        riskLevel: riskLevel))
                if let turn = result.eBrainTurn,
                   let entry = turn.sovereignAuditEntry {
                    auditCodes = entry.signalRefs
                    output = turn.thoughtFold
                        .compactSlots["body"]
                        ?? turn.thoughtFold
                            .compactSlots["summary"]
                }
            } catch {
                stderr("  ⚠ substrate failed for \(entry.persona.rawValue): \(error)\n")
                continue
            }

            let judgePrompt = QinaoUserValueJudge.buildPrompt(
                personaProfile: entry.persona.description,
                scenarioGoal: entry.scenario.rawValue,
                userPrompt: prompt,
                systemAuditCodes: auditCodes,
                systemOutput: output)
            let sessionID =
                "uvj-\(entry.persona.rawValue)-" +
                "\(entry.scenario.rawValue)"
            do {
                let response = try await judgeEndpoint
                    .produceBody(
                        prompt: judgePrompt,
                        context: [],
                        role: .scout,
                        sessionID: sessionID)
                let score = QinaoUserValueJudge.parseScore(
                    response.body, sessionID: sessionID)
                scores.append(score)
                print("[\(entry.persona.rawValue) / \(entry.scenario.rawValue)] user-value=\(score.userValueScore) help=\(score.helpfulness) agency=\(score.respectsAgency) harm-avoid=\(score.avoidsHarm)")
            } catch {
                stderr("  ⚠ judge failed for \(sessionID): \(error)\n")
            }
        }

        let aggregate = QinaoUserValueJudge.aggregate(
            scores: scores)
        print("""

            ━━━ User-Value Aggregate (\(aggregate.sessionCount) sessions) ━━━
            Median user-value:  \(aggregate.medianUserValue)
            P25 user-value:     \(aggregate.p25UserValue)
            P75 user-value:     \(aggregate.p75UserValue)
            Avg helpfulness:    \(aggregate.avgHelpfulness)
            Avg agency-respect: \(aggregate.avgAgencyRespect)
            Avg avoids-harm:    \(aggregate.avgAvoidsHarm)
            Threshold: < \(QinaoUserValueJudge.unhelpfulThreshold) = unhelpful (假设 #4 broken)
                       > \(QinaoUserValueJudge.helpfulThreshold) = helpful (假设 #4 supported)
            ═════════════════════════════════════════════════
            """)

        let verdict: String
        if aggregate.medianUserValue
            < QinaoUserValueJudge.unhelpfulThreshold
        {
            verdict = "❌ UNHELPFUL — assumption #4 broken"
        } else if aggregate.medianUserValue
            > QinaoUserValueJudge.helpfulThreshold
        {
            verdict = "✅ HELPFUL — assumption #4 supported"
        } else {
            verdict = "⚠️ MARGINAL — neither clearly helpful nor unhelpful"
        }
        print("Verdict: \(verdict)\n")
    }


}
