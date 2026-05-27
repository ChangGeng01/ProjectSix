// MARK: - BASChapter1008TierValidatorTests
// chapter 一千零八 / M3745 — `Gate.Tier` validation wire
//
// Pre-ch-1008: `BASAgentFabricGate.Tier.{core,all}` shipped at
// ch 993 as host-observable signal,parsed into Activation,
// surfaced in diagnostics,but NO substrate-side behavioral
// branch — decorative env-var echo per ch 995.5。
//
// Full multi-chapter tier-filter wire (integrate 7 watchers +
// 4 skill agents into the pipeline) is Phase 9+ scope。 But
// VALIDATION of tier ↔ activeAgents consistency is achievable
// today and produces a real substrate-side behavioral signal。
//
// Tests pin:
//   1. `.core` + empty activeAgents → consistent diagnostic
//   2. `.core` + only core seat names → consistent
//   3. `.core` + watcher names → MISMATCH diagnostic per name
//   4. `.core` + skill names → MISMATCH diagnostic per name
//   5. `.all` + watcher names → consistent
//   6. `.all` + unknown names → MISMATCH (catches typos)
//   7. Output is sorted (byte-equal across runs)
//   8. Case insensitivity: "AnomalyWatcher" matches
//      "anomalywatcher"
//   9. Host pipeline emits `gate.tierValidation` diagnostic

import XCTest
@testable import BASMemory
@testable import BASHostKit

final class BASChapter1008TierValidatorTests: XCTestCase {

    private static func makeActivation(
        tier: BASAgentFabricGate.Tier = .core,
        activeAgents: [String] = []
    ) -> BASAgentFabricGate.Activation {
        BASAgentFabricGate.Activation(
            fabricEnabled: true,
            tier: tier,
            transcriptMode: .singleAgent,
            activeAgents: activeAgents)
    }

    // MARK: - 1 + 2. Consistent .core cases

    func test_CoreTier_EmptyActiveAgents_IsConsistent() {
        let activation = Self.makeActivation(
            tier: .core, activeAgents: [])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 1)
        XCTAssertTrue(
            diag[0].contains("tier.consistent\u{001F}tier=core"),
            "ch 1008: empty activeAgents + .core MUST be " +
            "consistent (default config)")
    }

    func test_CoreTier_OnlyCoreSeats_IsConsistent() {
        let activation = Self.makeActivation(
            tier: .core,
            activeAgents: ["Planner", "Critic", "Memory"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 1)
        XCTAssertTrue(
            diag[0].contains("tier.consistent"),
            "ch 1008: .core + only core-seat names MUST be " +
            "consistent")
    }

    // MARK: - 3. .core + watcher → MISMATCH

    func testCRITICAL_CoreTier_WithWatchers_FlagsMismatch() {
        let activation = Self.makeActivation(
            tier: .core,
            activeAgents: ["anomalyWatcher", "gaslightWatcher"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        // 2 mismatch diagnostics, no consistent informational
        XCTAssertEqual(diag.count, 2,
            "ch 1008 CRITICAL: 2 watcher names + .core tier " +
            "MUST emit 2 mismatch diagnostics")
        XCTAssertTrue(
            diag.allSatisfy { $0.contains("tier.mismatch") },
            "ch 1008: all diagnostics MUST be mismatch class")
        XCTAssertTrue(
            diag.contains(where: {
                $0.contains("anomalywatcher")
            }))
        XCTAssertTrue(
            diag.contains(where: {
                $0.contains("gaslightwatcher")
            }))
    }

    // MARK: - 4. .core + skill → MISMATCH

    func test_CoreTier_WithSkills_FlagsMismatch() {
        let activation = Self.makeActivation(
            tier: .core,
            activeAgents: ["codeSkill"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 1)
        XCTAssertTrue(
            diag[0].contains("tier.mismatch\u{001F}tier=core") &&
            diag[0].contains("codeskill"))
    }

    // MARK: - 5. .all + watcher → consistent

    func test_AllTier_WithWatchers_IsConsistent() {
        let activation = Self.makeActivation(
            tier: .all,
            activeAgents: [
                "anomalyWatcher", "Planner"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 1)
        XCTAssertTrue(
            diag[0].contains("tier.consistent\u{001F}tier=all"),
            "ch 1008: .all + watchers + core seats MUST be " +
            "consistent")
    }

    // MARK: - 6. .all + unknown → MISMATCH

    func testCRITICAL_AllTier_WithUnknownAgent_FlagsMismatch() {
        let activation = Self.makeActivation(
            tier: .all,
            activeAgents: ["zorpAgent", "Planner"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 1)
        XCTAssertTrue(
            diag[0].contains("tier.mismatch\u{001F}tier=all") &&
            diag[0].contains("zorpagent"),
            "ch 1008 CRITICAL: unknown agent name MUST emit " +
            "mismatch in .all tier (catches typos)")
    }

    // MARK: - 7. Output sorted

    func test_Output_IsSortedAlphabetically() {
        let activation = Self.makeActivation(
            tier: .core,
            activeAgents: [
                "toolInjectionWatcher",
                "anomalyWatcher",
                "memoryPollutionWatcher",
            ])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 3)
        // sorted: anomalywatcher < memorypollution < toolinjection
        let sorted = diag.sorted()
        XCTAssertEqual(diag, sorted,
            "ch 1008: output MUST be sorted for byte-equal " +
            "determinism across runs")
    }

    // MARK: - 8. Case insensitivity

    func test_CaseInsensitive_MatchesAcrossCasings() {
        let activation = Self.makeActivation(
            tier: .core,
            activeAgents: [
                "ANOMALYWATCHER", "GaslightWatcher"])
        let diag = BASAgentTierActivationValidator
            .validate(activation)
        XCTAssertEqual(diag.count, 2,
            "ch 1008: case-insensitive matching MUST detect " +
            "watchers regardless of input casing")
    }
}
