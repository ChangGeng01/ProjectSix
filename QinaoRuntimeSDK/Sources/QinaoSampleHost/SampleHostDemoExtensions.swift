// MARK: - SampleHostDemoExtensions — chapter 二百八十九 / M776
//
// Phase Alpha 第十五刀(QinaoSampleHost god file 2nd cut):从
// `main.swift` 抽出 demo cluster 的 16 个 helper functions —
// Phase Alpha 第四个 god file 第二次拆分。
//
// 抽出 helpers (Swift extension on QinaoSampleHost):
//   - `runMultiSessionDemo` (M306) — 2 BASHostRuntime sessions
//     sharing 1 SQLite ledger
//   - `runPhaseDispatchDemo` (M313) — phase-dispatch demo
//   - `runMultiTurnDemo` (M314) — multi-turn demo
//   - `runCleanRebootDemo` (M322) — clean-reboot demo
//   - `runPersonaPanelReview` (M326) — persona panel review
//   - `runDualKeyDemo` (M328) — dual-key commit demo
//   - `runCrossDeviceSyncDemo` (M329) — cross-device sync demo
//   - `runEvolutionLoopDemo` (M333) — evolution loop demo
//   - `runThroughputBench` (M334) — throughput bench
//   - `runMultiHostDemo` (M335) — multi-host demo
//   - `runCthulhuDoctrineDemo` — Cthulhu doctrine demo
//   - `runKunlunSchemaDemo` — Kunlun schema demo
//   - `runKunlunDoctrineDemo` — Kunlun doctrine demo
//   - `runCthulhuEndToEndDemo` — Cthulhu E2E demo
//   - `runKunlunEndToEndDemo` — Kunlun E2E demo
//
// **0 behavior change**:helpers literal-identical to pre-extraction
// versions,只是改成了 Swift extension on QinaoSampleHost。Module
// DAG 不变(同 module 内部 split)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五 anti-magic-number 全保
//   - demo doctrine pins (M328 dual-key / M329 cross-device sync /
//     M333 lifecycle / M335 multi-host) preserved

import Foundation
import BASMemory
import BASObservability
import BASSovereign
import BASLeaseLife
import CryptoKit

extension QinaoSampleHost {
    static func runMultiSessionDemo() async {
        print("""
            QinaoSampleHost --multi-session-demo (M306):
              drive two BASHostRuntime sessions sharing one
              SQLite-backed audit ledger; verify chain
              integrity + M298-M305 audit-signal codes appear
              in both sessions; reload via a third
              verification ledger.
            """)

        let demoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-multi-session-demo-" +
                "\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: demoRoot)
        }

        let outcome: MultiSessionContinuityDemo.Outcome
        do {
            outcome = try await MultiSessionContinuityDemo
                .run(rootDirectory: demoRoot)
        } catch {
            stderr("error: multi-session demo failed: \(error)\n")
            exit(2)
        }

        print("""

            ━━━ Step 1/4 — Shared unified storage (M298) ━━━
            unified root:    \(outcome.unifiedRoot.lastPathComponent)
            audit ledger:    \(outcome.auditLedgerURL.lastPathComponent)

            ━━━ Step 2/4 — Session A ━━━
            sessionID:       \(outcome.sessionA.sessionID)
            auditID:         \(outcome.sessionA.auditID)
            audit codes:     \(outcome.sessionA.m298ThroughM305CodePrefixes
                .joined(separator: ", "))
            signalRefs (#):  \(outcome.sessionA.signalRefs.count)

            ━━━ Step 3/4 — Session B ━━━
            sessionID:       \(outcome.sessionB.sessionID)
            auditID:         \(outcome.sessionB.auditID)
            audit codes:     \(outcome.sessionB.m298ThroughM305CodePrefixes
                .joined(separator: ", "))
            signalRefs (#):  \(outcome.sessionB.signalRefs.count)

            ━━━ Step 4/4 — Continuity proof (verification ledger) ━━━
            entries on disk:        \(outcome.ledgerEntryCount)
            chain integrity:        \(outcome.chainIntegrityVerified ? "✓ verified" : "⚠ FAILED")
            sessionIDs distinct:    \(outcome.sessionA.sessionID != outcome.sessionB.sessionID ? "✓" : "⚠ SAME")
            auditIDs distinct:      \(outcome.sessionA.auditID != outcome.sessionB.auditID ? "✓" : "⚠ SAME")

            ━━━ Demo complete — M298 locator + M91 SQLite ledger + M298-M305 audit codes verified across two sessions ━━━
            """)
    }

    // MARK: - M313 phase-dispatch demo

    /// Drive M309's three-phase seat dispatch against a 9-seat
    /// council built via M312 `QinaoDefaults.makeStandard
    /// WithAdapters`. Prints per-phase shape (verdicts / failures
    /// / seat raw values) plus a doctrine reminder that
    /// perception completes before cognition starts before
    /// landing starts.
    static func runPhaseDispatchDemo() async {
        print("""
            QinaoSampleHost --phase-dispatch-demo (M313):
              build a 9-seat council via M312 + dispatch through
              M309's perception → cognition → landing ordering.
              Default seats use M292.6d proxy readers (no real
              model needed); demo prints per-phase shape so
              hosts see the manifesto v4 三阶段并发 contract on
              one screen.
            """)

        let outcome: PhaseDispatchDemo.Outcome
        do {
            outcome = try await PhaseDispatchDemo.run()
        } catch {
            stderr("error: phase-dispatch demo failed: \(error)\n")
            exit(2)
        }

        print("""

            ━━━ Step 1/2 — 9-seat council assembled (M312) ━━━
            snapshot:        \(outcome.snapshotID)
            total seats:     \(outcome.totalSeats)

            ━━━ Step 2/2 — Three-phase dispatch (M309) ━━━
            perception ▸ \(outcome.perceptionPhase
                .seatRawValuesASC.joined(separator: ", "))
              verdicts: \(outcome.perceptionPhase.verdictsCount), failures: \(outcome.perceptionPhase.failuresCount)
            cognition  ▸ \(outcome.cognitionPhase
                .seatRawValuesASC.joined(separator: ", "))
              verdicts: \(outcome.cognitionPhase.verdictsCount), failures: \(outcome.cognitionPhase.failuresCount)
            landing    ▸ \(outcome.landingPhase
                .seatRawValuesASC.joined(separator: ", "))
              verdicts: \(outcome.landingPhase.verdictsCount), failures: \(outcome.landingPhase.failuresCount)

            ━━━ Demo complete — manifesto v4 三阶段并发 dispatch shape verified end-to-end ━━━
            """)
    }

    // MARK: - M314 multi-turn demo

    /// Drive M310's multi-turn driver pattern across 3 turns.
    /// Default mock provider always available (deterministic
    /// outcome); AFM real provider activated when
    /// `QINAO_AFM_MULTI_TURN_DEMO=1` env var is set, mirroring
    /// the M178 + M310 gating pattern.
    static func runMultiTurnDemo() async {
        print("""
            QinaoSampleHost --multi-turn-demo (M314):
              drive 3-turn conversation through M310's
              `driveMultiTurn(...)` driver. Default uses a
              deterministic mock provider so the demo runs in
              CI without external dependencies; set
              QINAO_AFM_MULTI_TURN_DEMO=1 to drive Apple
              Foundation Models on macOS 26+ devices with Apple
              Intelligence enabled.
            """)

        let outcome: MultiTurnDemo.Outcome
        do {
            outcome = try await MultiTurnDemo.run()
        } catch {
            stderr("error: multi-turn demo failed: \(error)\n")
            exit(2)
        }

        print("""

            ━━━ Step 1/2 — 3-turn conversation (M310) ━━━
            sessionID:       \(outcome.sessionID)
            provider mode:   \(outcome.providerMode)
            """)
        for turn in outcome.turns {
            print("""

              Turn \(turn.turnIndex + 1) — context entries: \(turn.contextEntryCountBefore)
                prompt:    \(turn.prompt)
                provider:  \(turn.providerID)
                response:  \(turn.responseHead)
            """)
        }
        print("""

            ━━━ Step 2/2 — Continuity proof ━━━
            sessionID stable:        \(outcome.sessionIDStable ? "✓" : "⚠")
            context grew monotonic:  \(outcome.contextGrewMonotonically ? "✓" : "⚠")
            distinct responses:      \(outcome.distinctResponseCount) of \(outcome.turns.count)

            ━━━ Demo complete — M310 driveMultiTurn driver verified end-to-end ━━━
            """)
    }

    // MARK: - M322 clean-reboot demo

    /// Drive `BASSovereignCleanRebootCoordinator` through a
    /// pre-built version tree (v0 good, v1 tainted) and produce
    /// rollback + deadStop plans. Banner renders the typed plan
    /// shape so hosts see the M296.1 净启 contract end-to-end.
    static func runCleanRebootDemo() async {
        print("""
            QinaoSampleHost --clean-reboot-demo (M322):
              drive BASSovereignCleanRebootCoordinator through
              rollback (v1 tainted → v0 good + bootstrap) and
              deadStop (v0 → halt & await host) scenarios.
              Coordinator produces typed RebootPlans; demo
              prints actions sequence + bootstrap flag + audit
              ref so hosts see the M296.1 净启 contract.
            """)

        let outcome: CleanRebootDemo.Outcome
        do {
            outcome = try await CleanRebootDemo.run()
        } catch {
            stderr("error: clean-reboot demo failed: \(error)\n")
            exit(2)
        }

        print("""

            ━━━ Step 1/2 — Rollback scenario (tainted lineage) ━━━
            verdict level:      \(outcome.rollback.verdictLevel)
            source version:     \(outcome.rollback.sourceVersionID)
            target version:     \(outcome.rollback.targetVersionID)
            target anchor:      \(outcome.rollback.targetAnchorID)
            actions:            \(outcome.rollback.actions
                .joined(separator: " → "))
            bootstrap next:     \(outcome.rollback.bootstrapNextSession ? "✓" : "⚠ FALSE")
            audit ref:          \(outcome.rollback.auditRef)

            ━━━ Step 2/2 — DeadStop scenario (halt & await host) ━━━
            verdict level:      \(outcome.deadStop.verdictLevel)
            source version:     \(outcome.deadStop.sourceVersionID)
            target version:     \(outcome.deadStop.targetVersionID)
            target anchor:      \(outcome.deadStop.targetAnchorID)
            actions:            \(outcome.deadStop.actions
                .joined(separator: " → "))
            bootstrap next:     \(outcome.deadStop.bootstrapNextSession ? "⚠ TRUE" : "✓ FALSE (halt expected)")
            audit ref:          \(outcome.deadStop.auditRef)

            ━━━ Audit ledger trail ━━━
            entries appended:   \(outcome.auditEntryCount)

            ━━━ Demo complete — M296.1 净启 (clean reboot) plan generation verified end-to-end ━━━
            """)
    }

    // MARK: - M326 persona-panel-review

    /// Drive AI persona panel against starter curriculum via
    /// real AFM. Output JSON to a temp file path that the demo
    /// prints so the caller can read structured results.
    static func runPersonaPanelReview() async {
        let envFlag = "QINAO_AFM_PANEL_REVIEW"
        guard
            ProcessInfo.processInfo.environment[envFlag] == "1"
        else {
            stderr("error: set \(envFlag)=1 to drive real AFM\n")
            exit(2)
        }
        let count: Int = {
            if let raw = ProcessInfo.processInfo
                .environment["QINAO_PANEL_COUNT"],
               let n = Int(raw),
               n > 0 && n <= 50
            {
                return n
            }
            return 5
        }()

        print("""
            QinaoSampleHost --persona-panel-review (M326):
              drive BASWorldPriorAIPersonaReviewer (5 personas)
              × \(count) starter-curriculum templates against
              Apple Foundation Models on device. Output:
              per-template aggregate (approve / reject / needs-
              expert) + per-persona structured replies.

              Doctrine A pin: persona panel consensus does NOT
              promote envelope provenance. Reviews are
              `.illustrative` regardless of outcome.

              Total AFM calls: \(count) × 5 = \(count * 5)
              (≈ \(count * 5 * 3) sec at typical AFM throughput)
            """)

        let outcome: PersonaPanelReviewDemo.Outcome
        do {
            outcome = try await PersonaPanelReviewDemo.run(
                count: count)
        } catch {
            stderr(
                "error: persona-panel-review failed: \(error)\n")
            exit(2)
        }

        // Print summary banner.
        print("""

            ━━━ Step 1/2 — Run summary ━━━
            templates reviewed:  \(outcome.totalTemplates)
            total AFM calls:     \(outcome.totalCalls)
            parse-success rate:  \(outcome.parseSuccessCount) / \(outcome.totalCalls)
            elapsed:             \(String(format: "%.1f", outcome.elapsedSeconds)) sec

            ━━━ Step 2/2 — Per-template aggregates ━━━
            """)
        for o in outcome.outcomes {
            print("""

              \(o.templateID)
                approve / reject / needs-expert:
                  \(o.approveSuggestedCount) / \(o.rejectSuggestedCount) / \(o.needsExpertJudgmentCount)
                personas:
            """)
            for p in o.perPersona {
                let comment = p.domainComment
                    .replacingOccurrences(of: "\n", with: " ")
                let trunc = comment.count > 100
                    ? String(comment.prefix(100)) + "…"
                    : comment
                print(
                    "    [\(p.persona)] \(p.recommendation): \(trunc)")
            }
        }

        // Encode + write JSON to a temp file the caller can grep.
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "qinao-persona-panel-review-" +
                "\(UUID().uuidString.prefix(8)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted, .sortedKeys,
        ]
        do {
            let payload = try encoder.encode(
                EncodableOutcome(from: outcome))
            try payload.write(to: outURL)
            print("""

                ━━━ JSON output ━━━
                \(outURL.path)

                ━━━ Demo complete — persona panel ran on \(outcome.totalTemplates) templates; envelope stays .illustrative ━━━
                """)
        } catch {
            stderr(
                "warning: failed to write JSON output: \(error)\n")
        }
    }

    // MARK: - M328 dual-key-demo

    /// Drive `BASSovereignHighConsequenceGate` +
    /// `BASSovereignDualKeyCommit` through 5 canonical
    /// scenarios. Banner reports per-scenario outcome
    /// (authorized vs expected) so hosts see M296.2 双钥提交
    /// contract end-to-end.
    static func runDualKeyDemo() {
        print("""
            QinaoSampleHost --dual-key-demo (M328):
              drive BASSovereignHighConsequenceGate +
              BASSovereignDualKeyCommit through 5 scenarios:
                1. routine + nil commit       (expect: pass)
                2. high-conseq + nil commit   (expect: fail)
                3. high-conseq + valid commit (expect: pass)
                4. high-conseq + wrong digest (expect: fail)
                5. high-conseq + tampered sig (expect: fail)
              All cryptography is real Ed25519 via CryptoKit.
            """)

        let outcome: DualKeyCommitDemo.Outcome
        do {
            outcome = try DualKeyCommitDemo.run()
        } catch {
            stderr("error: dual-key demo failed: \(error)\n")
            exit(2)
        }

        print("""

            ━━━ Step 1/2 — Key registry ━━━
            primary key ID:    \(outcome.primaryKeyID)
            secondary key ID:  \(outcome.secondaryKeyID)

            ━━━ Step 2/2 — Scenario results ━━━
            """)
        for (idx, s) in outcome.scenarios.enumerated() {
            let mark = s.outcomeMatches ? "✓" : "⚠"
            print("""

              \(idx + 1). \(s.scenarioName)
                 intent class:        \(s.intentClass)
                 commit provided:     \(s.commitProvided)
                 authorized:          \(s.authorized) (expected \(s.expectedAuthorized))  \(mark)
                 \(s.note)
            """)
        }
        let allOK = outcome.allOutcomesMatchExpected
        print("""

            ━━━ Demo complete — all 5 outcomes match expected: \(allOK ? "✓" : "⚠ MISMATCH") ━━━
            """)
        if !allOK {
            exit(2)
        }
    }

    // MARK: - M329 cross-device-sync-demo

    /// Drive `BASSovereignFragmentMerger` +
    /// `BASSovereignCrossDeviceClock` through a 2-device sync
    /// scenario. Banner reports per-device timelines, merged
    /// total-order, and clock convergence so hosts see M296.3
    /// 跨设备一致性 contract end-to-end.
    static func runCrossDeviceSyncDemo() {
        print("""
            QinaoSampleHost --cross-device-sync-demo (M329):
              simulate 2 devices each emitting audit-fragment
              frames with vector clocks, then merge through
              BASSovereignFragmentMerger.mergeOrdered. In-
              process simulation — no real network transport.
              Vector-clock causal ordering is the M296.3
              default strategy (chapter 38.2); CRDT / leader-
              follower / gossip strategies also shipped.
            """)

        let outcome = CrossDeviceSyncDemo.run()

        print("""

            ━━━ Step 1/3 — Per-device timelines ━━━
            \(outcome.deviceA.deviceID):
              frame count: \(outcome.deviceA.frameCount)
              frame refs:  \(outcome.deviceA.frameRefs
                  .joined(separator: " → "))
            \(outcome.deviceB.deviceID):
              frame count: \(outcome.deviceB.frameCount)
              frame refs:  \(outcome.deviceB.frameRefs
                  .joined(separator: " → "))

            ━━━ Step 2/3 — Merged total-order timeline ━━━
            merged frame count:        \(outcome.merged.frameCount)
            ordered refs:              \(outcome.merged.orderedRefs
                .joined(separator: " → "))
            merge(A, B) == merge(B, A): \(outcome.merged.symmetricUnderReverse ? "✓ symmetric" : "⚠ ASYMMETRIC")

            ━━━ Step 3/3 — Clock convergence ━━━
            device A's final counter:  \(outcome.convergence.deviceA_finalCounter)
            device B's final counter:  \(outcome.convergence.deviceB_finalCounter)
            merged counters:           \(outcome.convergence.mergedCounters
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ", "))
            merge(A,B) == merge(B,A):  \(outcome.convergence.convergenceMatches ? "✓ commutative" : "⚠ NOT COMMUTATIVE")

            ━━━ Demo complete — M296.3 跨设备一致性 (vector-clock merge + clock convergence) verified end-to-end ━━━
            """)
    }

    // MARK: - M333 evolution-loop-demo

    /// Drive `BASEvolutionLifecycleSession` (chapter 五十六)
    /// through 3 lifecycle paths + 4 invariant pins. Pure
    /// value-type — no actor, no IO. Banner reports per-path
    /// stages-visited + transitions + each invariant outcome.
    static func runEvolutionLoopDemo() {
        print("""
            QinaoSampleHost --evolution-loop-demo (M333):
              drive BASEvolutionLifecycleSession (chapter 五十六)
              through 3 paths and 4 invariant pins. Pure
              value-type lifecycle — no actor, no IO. Doctrine:
              promoted is NON-terminal (retraction is real path);
              withdraw is BLOCKED from promoted (only retraction
              gets you out).
            """)

        let outcome = EvolutionLoopDemo.run()

        print("""

            ━━━ Step 1/3 — Path 1: promotion + retraction ━━━
            ticket:           \(outcome.promotedThenRetracted.candidateID)
            path:             \(outcome.promotedThenRetracted.pathName)
            final stage:      \(outcome.promotedThenRetracted.finalStage)
            terminal:         \(outcome.promotedThenRetracted.isTerminal)
            reached promotion: \(outcome.promotedThenRetracted.hasReachedPromotion)
            stages visited:   \(outcome.promotedThenRetracted.stagesVisited
                .joined(separator: " → "))
            transitions:
            """)
        for t in outcome.promotedThenRetracted.transitions {
            print("              • \(t)")
        }

        print("""

            ━━━ Step 2/3 — Path 2: trial failure ━━━
            ticket:           \(outcome.trialFailed.candidateID)
            path:             \(outcome.trialFailed.pathName)
            final stage:      \(outcome.trialFailed.finalStage)
            terminal:         \(outcome.trialFailed.isTerminal)
            reached promotion: \(outcome.trialFailed.hasReachedPromotion)
            stages visited:   \(outcome.trialFailed.stagesVisited
                .joined(separator: " → "))
            transitions:
            """)
        for t in outcome.trialFailed.transitions {
            print("              • \(t)")
        }

        print("""

            ━━━ Step 3/3 — Path 3: early withdrawal ━━━
            ticket:           \(outcome.earlyWithdrawn.candidateID)
            path:             \(outcome.earlyWithdrawn.pathName)
            final stage:      \(outcome.earlyWithdrawn.finalStage)
            terminal:         \(outcome.earlyWithdrawn.isTerminal)
            reached promotion: \(outcome.earlyWithdrawn.hasReachedPromotion)
            stages visited:   \(outcome.earlyWithdrawn.stagesVisited
                .joined(separator: " → "))
            transitions:
            """)
        for t in outcome.earlyWithdrawn.transitions {
            print("              • \(t)")
        }

        print("""

            ━━━ Doctrine invariant pins ━━━
            """)
        for pin in outcome.invariantPins {
            let mark = pin.assertionResult ? "✓" : "⚠"
            print("""
              \(mark) \(pin.pinName)
                \(pin.detail)
            """)
        }
        let allOK = outcome.allInvariantsHold
        print("""

            ━━━ Demo complete — all invariants hold: \(allOK ? "✓" : "⚠ MISMATCH") ━━━
            """)
        if !allOK {
            exit(2)
        }
    }

    // MARK: - M334 throughput-bench

    /// Drive N turns of substrate work + capture latency stats +
    /// thermal/breath quantification. Banner mirrors M179 perf
    /// shape (p50 / p95 / p99 / min / max / mean) plus thermal
    /// evolution.
    static func runThroughputBench() async {
        let turnCount: Int = {
            if let raw = ProcessInfo.processInfo
                .environment["QINAO_BENCH_TURN_COUNT"],
               let n = Int(raw),
               n > 0
            {
                return n
            }
            return 100
        }()

        print("""
            QinaoSampleHost --throughput-bench (M334 + M340 scope pin):
              drive \(turnCount) turns of substrate work
              (lifecycle + thermal/breath cycling) + capture
              latency stats. Default 100 turns; override via
              QINAO_BENCH_TURN_COUNT=N.

              \(ThroughputBenchDemo.scopeStatement)
            """)

        let outcome = await ThroughputBenchDemo.run(
            turnCount: turnCount)

        print("""

            ━━━ Step 1/2 — Latency stats (\(outcome.turnCount) turns) ━━━
            elapsed wall:  \(String(format: "%.2f", outcome.elapsedSeconds)) sec
            min:           \(String(format: "%.4f", outcome.latency.min)) ms
            p50:           \(String(format: "%.4f", outcome.latency.p50)) ms
            p95:           \(String(format: "%.4f", outcome.latency.p95)) ms
            p99:           \(String(format: "%.4f", outcome.latency.p99)) ms
            max:           \(String(format: "%.4f", outcome.latency.max)) ms
            mean:          \(String(format: "%.4f", outcome.latency.mean)) ms

            ━━━ Step 2/2 — Thermal / breath cycling ━━━
            first pressure:        \(String(format: "%.4f", outcome.thermal.firstPressure))
            final pressure:        \(String(format: "%.4f", outcome.thermal.finalPressure))
            peak pressure:         \(String(format: "%.4f", outcome.thermal.peakPressure))
            first guardLevel:      \(outcome.thermal.firstGuardLevel)
            final guardLevel:      \(outcome.thermal.finalGuardLevel)
            guardLevel escalations: \(outcome.thermal.guardEscalations)
            cancelled breath total: \(outcome.thermal.cancelledBreathTotal)

            ━━━ Demo complete — \(turnCount) turns benchmarked; thermal twin observed ━━━
            """)
    }

    // MARK: - M335 multi-host-demo

    /// Drive 2 independent host instances + merge their audit
    /// fragment timelines via M329 FragmentMerger. Banner
    /// reports per-host stages walked + merged consensus +
    /// invariant outcomes.
    static func runMultiHostDemo() {
        print("""
            QinaoSampleHost --multi-host-demo (M335):
              drive 2 independent host instances (host-A walks
              the promotion path; host-B walks the failure
              path); merge audit fragments via M329
              FragmentMerger; verify symmetry + commutativity
              + isolation invariants. 0 BAS code changes —
              pure recombination of M329 cross-device
              primitives with hostID semantics.
            """)

        let outcome = MultiHostDemo.run()

        print("""

            ━━━ Step 1/3 — Host A (promotion path) ━━━
            hostID:                \(outcome.hostA.hostID)
            constitution version:  \(outcome.hostA.constitutionVersion)
            stages walked:         \(outcome.hostA.stagesWalked
                .joined(separator: " → "))
            audit fragments:       \(outcome.hostA.auditFragmentRefs.count)
              \(outcome.hostA.auditFragmentRefs
                  .joined(separator: ", "))
            final clock:           \(outcome.hostA.finalClock
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ", "))

            ━━━ Step 2/3 — Host B (failure path) ━━━
            hostID:                \(outcome.hostB.hostID)
            constitution version:  \(outcome.hostB.constitutionVersion)
            stages walked:         \(outcome.hostB.stagesWalked
                .joined(separator: " → "))
            audit fragments:       \(outcome.hostB.auditFragmentRefs.count)
              \(outcome.hostB.auditFragmentRefs
                  .joined(separator: ", "))
            final clock:           \(outcome.hostB.finalClock
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ", "))

            ━━━ Step 3/3 — Cross-host audit consensus (M329 FragmentMerger) ━━━
            total frames:                \(outcome.consensus.totalFrames)
            ordered audit refs:          \(outcome.consensus.orderedAuditRefs
                .joined(separator: " → "))
            merge(A,B) == merge(B,A):    \(outcome.consensus.mergeIsSymmetric ? "✓ symmetric" : "⚠ ASYMMETRIC")
            clock merge commutative:     \(outcome.consensus.clockMergeIsCommutative ? "✓" : "⚠")
            constitutions isolated:      \(outcome.consensus.constitutionsAreIsolated ? "✓ (hostID-namespaced)" : "⚠ COLLISION")
            no duplicate frames:         \(outcome.consensus.noDuplicateFrames ? "✓" : "⚠ DUPLICATES")
            merged clock counters:       \(outcome.consensus.mergedClockCounters
                .map { "\($0.key)=\($0.value)" }
                .sorted()
                .joined(separator: ", "))

            ━━━ Demo complete — multi-host audit consensus invariants all hold: \(outcome.consensus.allInvariantsHold ? "✓" : "⚠ MISMATCH") ━━━
            """)
        if !outcome.consensus.allInvariantsHold {
            exit(2)
        }
    }

    // MARK: - M393 cthulhu-doctrine-demo

    /// Drive every M384-M389 typed primitive once against
    /// fixture inputs that trigger each wire's non-trivial
    /// path. Pure function — no actor, no IO. Banner reports
    /// per-wire summary + reason codes + final invariant pin.
    static func runCthulhuDoctrineDemo() {
        print("""
            QinaoSampleHost --cthulhu-doctrine-demo (M393):
              exercise M384-M389 Cthulhu doctrine wires in
              isolation. Pure-function — no actor / no IO. Each
              step shows the gate / cap / histogram / dominant-
              axis output the helpers produce when the input
              crosses the wire's trigger threshold. The audit
              codes printed below are exactly the strings the
              substrate writes into `BASSovereignAuditEntry
              .signalRefs` for each turn that activates the
              wire.
            """)

        let outcome = CthulhuDoctrineDemo.run()

        func renderStep(
            _ step: CthulhuDoctrineWireOutcome
        ) -> String {
            var lines = "  \(step.summary)"
            if !step.reasonCodes.isEmpty {
                lines += "\n  reason codes:\n"
                lines += step.reasonCodes
                    .map { "    • \($0)" }
                    .joined(separator: "\n")
            }
            return lines
        }

        print("""

            ━━━ Step 1/7 — \(outcome.m384HighPressureWarmAnchor.stepName) ━━━
            \(renderStep(outcome.m384HighPressureWarmAnchor))

            ━━━ Step 2/7 — \(outcome.m384RedLine8ReservedAnchor.stepName) ━━━
            \(renderStep(outcome.m384RedLine8ReservedAnchor))

            ━━━ Step 3/7 — \(outcome.m385ActiveReserveCap.stepName) ━━━
            \(renderStep(outcome.m385ActiveReserveCap))

            ━━━ Step 4/7 — \(outcome.m386ForbiddenGateRefusal.stepName) ━━━
            \(renderStep(outcome.m386ForbiddenGateRefusal))

            ━━━ Step 5/7 — \(outcome.m387SealHistogramShape.stepName) ━━━
            \(renderStep(outcome.m387SealHistogramShape))

            ━━━ Step 6/7 — \(outcome.m388NarrativeDominantAxis.stepName) ━━━
            \(renderStep(outcome.m388NarrativeDominantAxis))

            ━━━ Step 7/7 — \(outcome.m389DoctrineRedLineCardinality.stepName) ━━━
            \(renderStep(outcome.m389DoctrineRedLineCardinality))

            ━━━ Demo complete — Cthulhu doctrine invariants all hold: \(outcome.allInvariantsHold ? "✓" : "⚠ MISMATCH") ━━━
            """)
        if !outcome.allInvariantsHold {
            exit(2)
        }
    }

    // MARK: - M403 kunlun-schema-demo (chapter 九十二 Phase α)

    /// Print the 5 Kunlun schema shapes + 5 protocol helper
    /// signatures for the Phase α landing of the Kunlun Axis
    /// Doctrine. Schema-only introspection — no runtime, no
    /// actor, no IO. Each schema cites the white paper section
    /// that defines its fields.
    static func runKunlunSchemaDemo() {
        print("""
            QinaoSampleHost --kunlun-schema-demo (M403, chapter 九十二 Phase α):
              Print the Kunlun Axis Doctrine schema shapes
              shipped in M401 (`BASKunlunProtocol.swift`). This
              is schema-only introspection — no runtime, no
              decision wires yet. Wires hook into L11 / L8 /
              L14 in chapters 九十三 (β) / 九十四 (γ).

              Cite: docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md §4.

            ━━━ Schema 1 — BASKunlunAxis (white paper §4.1) ━━━
              Host-sovereignty centerline definition.
              Fields: axisID / hostRef / sovereignRef /
              worldAnchorRef / activeLayerRefs[] / agentSeatRefs[] /
              centerlineRules[] / deviationThreshold ∈ [0,1] /
              lastAlignmentCheck.
              Doctrine: 多角色可以并行，但必须共轴.

            ━━━ Schema 2 — BASAxisAlignment (white paper §4.1) ━━━
              Per-target alignment readout (centered / deviating /
              overreaching). Fields: alignmentID / targetRef /
              axisRef / centerScore ∈ [0,1] / deviationCodes[] /
              correctionHint / requiresGate.
              Doctrine: 中轴一动，全脑随之调向.

            ━━━ Schema 3 — BASJadeCanonSeal (white paper §4.2) ━━━
              High-integrity object seal. Fields: sealID /
              targetRef / objectClass (8 canonical) /
              targetSchemaVersion / provenanceRefs[] /
              integrityHash / signatureRef / replayRequired /
              revocationPath / sourceRiverRef.
              Doctrine: 无来源不成玉 / 无签名不进门 /
              无回放不升格 / 无撤销路径不得长期生效.

            ━━━ Schema 4 — BASHeavenGatePermit (white paper §4.3) ━━━
              Domain-transition gate (cognitive / memory / tool /
              host / evolution / public). Fields: gateID /
              sourceRef / targetDomain / gateClass /
              requiredSeals[] / actionPermitRef /
              sovereignWarrantRef / secondCheckRequired /
              passState / returnPathRef.
              Doctrine: 高处有门，过门有证.

            ━━━ Schema 5 — BASYaochiSanctumEntry (white paper §4.4) ━━━
              Sanctum memory parking record (sensitive / precious /
              grief / boundary / vow / high-weight-relation).
              Fields: entryID / memoryRef / hostRef / sanctumClass /
              accessPolicy (sealed / conditional / audited-open) /
              revealConditions[] / coolingPeriod (sec) /
              humanAnchorRequired / lastRevealedAt.
              Doctrine: 瑶池不是炫耀珍藏，
                       而是安置不该被频繁触碰的深物.

            ━━━ Schema 6 — BASRiverOriginTrace (white paper §4.5) ━━━
              System-level provenance graph. Fields: traceID /
              rootSourceRefs[] / tributaryRefs[] /
              derivedObjectRefs[] / transformationSteps[] /
              consentRefs[] / permitRefs[] / auditRefs[] /
              deletionDependents[] / lineageCutRefs[].
              Doctrine: 没有源流，就没有可信成长.

            ━━━ Protocol helpers (5 pure-function families) ━━━
              1. BASKunlunAxisProtocol.computeAlignment(
                   alignmentID:axis:targetRef:matchedRules:
                   deviationCodes:correctionHint:)
                 → BASAxisAlignment

              2. BASKunlunJadeCanonProtocol.verifySeal(_:)
                 → Verification {isCanonical, missingRequirements[]}

              3. BASKunlunHeavenGateProtocol.evaluateReadiness(_:)
                 → Readiness {isReady, reasonCodes[]}

              4. BASKunlunYaochiProtocol.evaluateAccess(
                   entry:hostAnchorPresent:
                   matchedRevealConditions:secondsSinceLastReveal:)
                 → AccessDecision {granted, reasonCodes[]}

              5. BASKunlunRiverOriginProtocol.analyze(_:)
                 → LineageReport {isWellFormed, upwardCount,
                   downwardCount, hasLineageCut, warningCodes[]}

            ━━━ Audit signalRefs (M402, chapter 九十二) ━━━
              Per-turn audit emission codes:
                kunlun.axis.center:%.3f (always when alignment
                                         fed into audit)
                kunlun.axis.deviation:<sorted+joined>
                                         (when codes non-empty)
                kunlun.axis.requires-gate:true
                                         (when gate needed)

            ━━━ Doctrine pair invariant (Kunlun + Cthulhu) ━━━
              昆仑给方向。深渊给边界。
              昆仑给秩序。深渊给警惕。
              昆仑负责立中。深渊负责止损。

            ━━━ Demo complete — Phase α (chapter 九十二) ━━━
              Phase β (chapter 九十三): JadeCanon + RiverOrigin
                wires hook into L11 permit synthesis.
              Phase γ (chapter 九十四): Yaochi + Tianmen wires
                hook into L8 query gate + L14 sovereign warrant.
              See docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md
                + plan附录 L for full roadmap.
            """)
    }

    // MARK: - M414 kunlun-doctrine-demo (chapter 九十五 Phase δ)

    /// Exercise every Kunlun doctrine wire shipped in M402 +
    /// M404 + M405 + M406 + M408 + M409 + M412 in pure-function
    /// isolation. Pattern parallel to `runCthulhuDoctrineDemo`.
    /// No runtime / no actor / no IO. Banner verifies all
    /// invariants hold via the helper's `allInvariantsHold`
    /// final flag.
    static func runKunlunDoctrineDemo() {
        print("""

            QinaoSampleHost --kunlun-doctrine-demo (M414):

              Exercises every Kunlun doctrine wire shipped in
              chapter 九十二 / 九十三 / 九十四 / 九十五 in
              pure-function isolation. No runtime / no actor /
              no IO. Each step prints the helper's typed input
              shape, the typed output, and the audit-emittable
              reason codes the wire produced.

            """)
        let outcome = KunlunDoctrineDemo.run()
        let steps: [KunlunDoctrineWireOutcome] = [
            outcome.m402AxisAlignmentCentered,
            outcome.m402AxisAlignmentOverreaching,
            outcome.m404JadeCanonCanonicalSeal,
            outcome.m404JadeCanonDefectiveSeal,
            outcome.m405RiverOriginWellformed,
            outcome.m405RiverOriginPartial,
            outcome.m406PermitEscalationOverreaching,
            outcome.m406PermitEscalationReserved,
            outcome.m408YaochiSealedDenied,
            outcome.m408YaochiConditionalGranted,
            outcome.m409TianmenHighStakesNotReady,
            outcome.m409TianmenLowStakesReady,
            outcome.m412DoctrineRedLineCardinality,
        ]
        for (idx, step) in steps.enumerated() {
            print("""

              [\(idx + 1)/\(steps.count)] \(step.stepName)
                summary: \(step.summary)
                reasonCodes (\(step.reasonCodes.count)):
                \(step.reasonCodes.map { "  - \($0)" }
                    .joined(separator: "\n                "))
            """)
        }
        print("""

            ━━━ Demo complete — chapter 九十五 Phase δ ━━━
              allInvariantsHold = \(outcome.allInvariantsHold)
              13 wires exercised: 2 axis (M402) + 2 jade (M404)
              + 2 river (M405) + 2 escalation (M406) + 2 yaochi
              (M408) + 2 tianmen (M409) + 1 red-line (M412).
              See docs/QINAO_KUNLUN_AXIS_DOCTRINE_TARGET_VINF.md
                + plan 附录 L for full roadmap.
              Phase ε (chapter 九十六): behavioral snapshots +
                e2e through real BASHostRuntime.
              Phase ζ (chapter 九十七): deep review pass +
                manifesto v9 按需 author decision.
            """)
    }

    // MARK: - M399 cthulhu-end-to-end-demo

    /// Drive a real `BASHostRuntime` session through every
    /// M384-M388 wire AND invoke the M391
    /// `submitWithForbiddenGate` extension against the resulting
    /// update tickets. Banner reports per-wire audit-prefix
    /// presence in the runtime's `BASSovereignAuditEntry.signalRefs`
    /// PLUS the gate's effect on the first vs second ticket.
    static func runCthulhuEndToEndDemo() async {
        print("""
            QinaoSampleHost --cthulhu-end-to-end-demo (M399):
              drive `BASHostRuntime.startSession(...)` and verify
              every M384-M388 wire ran through the production
              audit pipeline (audit signalRefs presence per
              wire); then invoke M391
              `submitWithForbiddenGate(_:forbidden:)` against the
              runtime's actual update tickets. The first ticket
              is paired with a synthesized sovereign-rejected
              forbidden candidate so the gate refuses it; the
              second ticket (if present) is unpaired so the gate
              passes through. Closes chapter 八十九.5 #2 (no
              production caller) and #3 (pure-function demo).
            """)

        let outcome: CthulhuEndToEndOutcome
        do {
            outcome = try await CthulhuEndToEndDemo.run()
        } catch {
            print("""

                ━━━ Demo failed: \(error) ━━━
                """)
            exit(2)
        }

        print("""

            ━━━ Step 1/2 — runtime turn shape ━━━
            sessionID:               \(outcome.sessionID)
            auditID:                 \(outcome.auditID)
            signalRefs count:        \(outcome.signalRefCount)
            permit.mode:             \(outcome.permitMode)
            permit.stackedModes:     \(outcome.permitStackedModes
                .joined(separator: "+"))
            permit.assertionCeiling: \(outcome.permitAssertionCeiling)
            permit.reasonCodes count: \(outcome.permitReasonCodeCount)
            updateTickets count:     \(outcome.updateTicketCount)
            """)

        print("""

            ━━━ Step 2/2 — per-wire audit-prefix presence ━━━
            """)
        for r in outcome.wireReadouts {
            let mark = r.present ? "✓" : "·"
            let sample = r.sampleCodes.isEmpty
                ? "(non-trivial path did not fire on this turn)"
                : r.sampleCodes.joined(separator: ", ")
            print("  \(mark) \(r.wireName) [\(r.auditCodePrefix)]: \(sample)")
        }

        if let g = outcome.forbiddenGateRecord {
            print("""

                ━━━ Step 3/3 — M391 forbidden-gate production call ━━━
                first ticket:               \(g.firstTicketID)
                  state after gate:         \(g.firstTicketStateAfterGate) (expected: rejected)
                  refusal reason codes:     \(g.gateRefusalReasonCodes
                    .joined(separator: ", "))
                second ticket:              \(g.secondTicketID ?? "(none)")
                  state after gate:         \(g.secondTicketStateAfterGate ?? "(n/a)") (expected: proposed)
                """)
        } else {
            print("""

                ━━━ Step 3/3 — M391 forbidden-gate production call ━━━
                runtime produced 0 update tickets — gate not invoked.
                """)
        }

        print("""

            ━━━ Demo complete — Cthulhu wires ran through BASHostRuntime: \(outcome.allWiresRegistered ? "✓" : "⚠")
                forbidden-gate production caller invoked: \(outcome.forbiddenGateInvoked ? "✓" : "⚠ no tickets") ━━━
            """)
    }

    // MARK: - M416 kunlun-end-to-end-demo (chapter 九十六 Phase ε)

    /// Drive a real `BASHostRuntime` session through every
    /// M402-M410 wire and verify each wire's audit signalRefs
    /// prefix is present. Pattern parallel to
    /// `runCthulhuEndToEndDemo`.
    static func runKunlunEndToEndDemo() async {
        print("""

            QinaoSampleHost --kunlun-end-to-end-demo (M416):

              Drives a real BASHostRuntime session through every
              Kunlun doctrine wire shipped in chapter 九十二 /
              九十三 / 九十四 / 九十五 (M402 axis, M404 jade,
              M405 river, M406 escalation, M408 yaochi, M409
              tianmen, M410 cross-protocol bind). For each wire,
              scan the resulting audit signalRefs for the wire's
              expected emission prefix, and report whether the
              wire's non-trivial path fired with the demo's
              inputs.

            """)
        do {
            let outcome = try await KunlunEndToEndDemo.run()
            print("""
              Session: \(outcome.sessionID)
              Audit ID: \(outcome.auditID)
              SignalRefs: \(outcome.signalRefCount)
              Permit: mode=\(outcome.permitMode) stackedModes=\(outcome.permitStackedModes.joined(separator: "+"))
              Permit reason codes: \(outcome.permitReasonCodeCount)

              Wire readouts (\(outcome.wiresFiredCount)/\(outcome.wiresRegisteredCount) fired):
            """)
            for readout in outcome.wireReadouts {
                let mark = readout.present ? "✓" : "·"
                let samples = readout.sampleCodes
                    .joined(separator: ", ")
                print("""
                    [\(mark)] \(readout.wireName) — prefix: \(readout.auditCodePrefix)
                        samples: \(samples)
                """)
            }
            print("""

              ━━━ Demo complete — Kunlun wires ran through BASHostRuntime: \(outcome.allWiresRegistered ? "✓" : "⚠")
                  fired \(outcome.wiresFiredCount)/\(outcome.wiresRegisteredCount) on this turn's inputs.
                  Phase ζ (chapter 九十七): deep review pass +
                    manifesto v9 按需 author decision.
              ━━━
            """)
        } catch {
            print("""
              ⚠ Kunlun end-to-end demo failed: \(error)
            """)
        }
    }

}
