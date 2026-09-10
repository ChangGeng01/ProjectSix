import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M541-M548 (chapter 一百三十六) — Substrate Value-Add Test per
/// Appendix Q.2.2 simplified scope.
///
/// **Original Q.2.2 plan**: side-by-side naked-AFM vs BAS-substrate
/// comparator. Required AFM/MLX wiring + AFM-gated tests +
/// `bench-baselines/naked-vs-substrate.json` baseline. Estimated 5
/// hrs.
///
/// **Simplified scope (this chapter)**: prove that BAS substrate
/// emits **non-trivial structured audit codes per turn** —
/// codes that a naked AFM/MLX call would NOT produce. This is
/// the structural value-add measurement, separate from
/// output-quality comparison.
///
/// **What this proves**:
///   - Substrate adds N audit reason codes per turn beyond what
///     naked LLM emits (which is 0 audit codes)
///   - Substrate codes span ≥3 doctrine layers (Cthulhu / Kunlun /
///     sovereign) — proves multi-doctrine integration works
///   - Substrate codes include load-bearing prefixes that map to
///     decision/permit (not just observational hints)
///
/// **What this does NOT prove**:
///   - That substrate output text is BETTER than naked LLM
///   - That audit codes translate to user value
///   - That structure matters more than raw response quality
///
/// Output-quality comparison + audit explainability + user value
/// require AFM/MLX-gated chapters 一百三十六.5 / 一百三十七 /
/// 一百三十八 (Appendix Q.2.2 full / Q.2.3 / Q.2.4).
///
/// **Empirical claim narrowed**: substrate ADDS STRUCTURE that
/// naked path doesn't. Whether that structure is valuable is
/// the next chapter's question.
final class M541SubstrateValueAddTests: XCTestCase {

    // MARK: - Test fixture

    private func makeRuntimePolicyLineage()
        -> BASRuntimePolicyLineage
    {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m541.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m541.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m541.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m541.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m541.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning()
        -> BASEBrainRuntimeSynthesisPolicy
    {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m541.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m541",
                policyProfileID: "host.m541.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn(
        prompt: String,
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: "M541 substrate value-add",
                riskLevel: riskLevel))
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. Substrate emits non-trivial structure per turn

    /// **Empirical claim**: BAS substrate emits ≥30 audit reason
    /// codes per turn. Naked LLM call would emit 0. Delta = 30+
    /// audit codes per turn that ONLY exist because substrate
    /// runs.
    func testSubstrateEmitsNonTrivialStructurePerTurn() throws {
        let turn = try runTurn(
            prompt: "Help me plan a meeting agenda.")
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        XCTAssertGreaterThanOrEqual(
            entry.signalRefs.count, 30,
            "Substrate MUST emit ≥30 audit codes per turn (was \(entry.signalRefs.count)). Naked LLM emits 0; delta = substrate value-add structure.")
    }

    // MARK: - 2. Substrate emits multi-doctrine codes

    /// **Empirical claim**: every turn emits codes from BOTH
    /// Cthulhu doctrine (向下) AND Kunlun doctrine (向上) — proves
    /// the 一轴一渊 doctrine pair is load-bearing on every turn,
    /// not just on adversarial input.
    func testSubstrateEmitsBothDoctrines() throws {
        let turn = try runTurn(
            prompt: "Explain how to file a tax return.")
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let cthulhuCodes = entry.signalRefs.filter {
            $0.hasPrefix("cthulhu.")
                || $0.hasPrefix("abyssal.")
                || $0.hasPrefix("anomaly.")
                || $0.hasPrefix("narrative.")
                || $0.hasPrefix("humanAnchor.")
        }
        let kunlunCodes = entry.signalRefs.filter {
            $0.hasPrefix("kunlun.")
        }
        XCTAssertGreaterThan(
            cthulhuCodes.count, 0,
            "Substrate MUST emit Cthulhu (向下) codes — if 0, Cthulhu doctrine is dead weight on this turn")
        XCTAssertGreaterThan(
            kunlunCodes.count, 0,
            "Substrate MUST emit Kunlun (向上) codes — if 0, Kunlun doctrine is dead weight on this turn")
    }

    // MARK: - 3. Substrate emits decision-influencing codes

    /// **Empirical claim**: every turn emits at least 1 code that
    /// directly influences decision (permit / verdict / risk /
    /// fold / refinement). Pure-observation-only doctrine would
    /// be theater; this test pins at least some codes are
    /// load-bearing for decision.
    func testSubstrateEmitsDecisionInfluencingCodes() throws {
        let turn = try runTurn(
            prompt: "Review my code refactor plan.")
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let decisionCodes = entry.signalRefs.filter {
            $0.hasPrefix("permit:")
                || $0.hasPrefix("risk:")
                || $0.hasPrefix("fold:")
                || $0.hasPrefix("forced_mode:")
        }
        XCTAssertGreaterThan(
            decisionCodes.count, 0,
            "Substrate MUST emit ≥1 decision-influencing code (permit:/risk:/fold:/forced_mode:) — if 0, all codes are observation-only theater")
    }

    // MARK: - 4. Risk-level escalation produces detectable delta

    /// **Empirical claim**: substrate output structure varies with
    /// risk-level input. low-risk turn vs extreme-risk turn MUST
    /// produce DIFFERENT audit code shapes (otherwise risk-level
    /// is dead input).
    func testRiskLevelEscalationProducesDelta() throws {
        let lowRiskTurn = try runTurn(
            prompt: "Casual chat",
            riskLevel: .low)
        let extremeRiskTurn = try runTurn(
            prompt: "Help me decide whether to take this irreversible step.",
            riskLevel: .high)
        let lowEntry = try XCTUnwrap(
            lowRiskTurn.sovereignAuditEntry)
        let extremeEntry = try XCTUnwrap(
            extremeRiskTurn.sovereignAuditEntry)
        XCTAssertNotEqual(
            lowEntry.signalRefs.sorted(),
            extremeEntry.signalRefs.sorted(),
            "Substrate audit codes MUST differ between low-risk and extreme-risk turns — if invariant, risk-level is dead input")
    }

    // MARK: - 5. Determinism: same input → byte-equal output

    /// **Counter-test**: same input MUST produce byte-equal audit
    /// trail. Non-determinism breaks audit replay.
    func testDeterminismSameInputByteEqual() throws {
        let turn1 = try runTurn(
            prompt: "Help me decide.")
        let turn2 = try runTurn(
            prompt: "Help me decide.")
        let e1 = try XCTUnwrap(turn1.sovereignAuditEntry)
        let e2 = try XCTUnwrap(turn2.sovereignAuditEntry)
        // Filter time-varying fields (audit ID may include
        // session-level random; reason codes should be stable
        // for fixed input).
        let codes1 = e1.signalRefs.sorted()
        let codes2 = e2.signalRefs.sorted()
        XCTAssertEqual(
            codes1, codes2,
            "Same input MUST yield byte-equal audit codes — non-determinism breaks audit replay invariant")
    }

    // MARK: - 6. Substrate value-add summary report

    /// **Coverage report**: prints typical audit code counts +
    /// distribution for documentation purposes. Not a test —
    /// always passes; output captured during test run shows
    /// substrate value-add at-a-glance.
    func testValueAddCoverageReport() throws {
        let turn = try runTurn(
            prompt: "Summarize the substrate value-add.")
        let entry = try XCTUnwrap(turn.sovereignAuditEntry)
        let allCodes = entry.signalRefs

        // Bucket codes by prefix for visibility
        var buckets: [String: Int] = [:]
        for code in allCodes {
            let prefix = code.split(separator: ".").first
                ?? code.split(separator: ":").first
                ?? Substring(code)
            buckets[String(prefix), default: 0] += 1
        }

        let totalLayers = buckets.count
        XCTAssertGreaterThanOrEqual(
            totalLayers, 5,
            "Substrate MUST emit codes spanning ≥5 distinct prefix buckets (was \(totalLayers)) — if fewer, doctrine breadth is theater")

        print("""
            === Substrate Value-Add Report ===
            Total audit codes per turn: \(allCodes.count)
            Distinct prefix buckets:    \(totalLayers)
            Top buckets (sorted by count):
            """)
        for (prefix, count) in buckets.sorted(by: {
            $0.value > $1.value
        }).prefix(10) {
            print("  \(prefix): \(count)")
        }
        print("=======================================")
    }
}
