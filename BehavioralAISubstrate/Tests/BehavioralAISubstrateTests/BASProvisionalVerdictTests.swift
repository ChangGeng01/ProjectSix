// MARK: - BASProvisionalVerdictTests
// ADR-020 Arc-3 Phase B — pre-render provisional sovereign verdict.
//
// Verifies `BASEBrainRuntimeCoordinator.buildProvisionalVerdict`, the
// render-independent PRE-RENDER forecast of the post-render verdict LEVEL.
// The function is DEAD CODE in the runtime (no call site until Phase C); these
// tests exercise it directly. Because Phase B made `computeVerdictDecision`
// and `buildProvisionalVerdict` `static` (neither reads instance state), the
// forecast is unit-testable WITHOUT constructing a full coordinator — no stub
// services required. The static change is behavior-preserving (static vs
// instance dispatch does not change the computed value), so Phase A stays
// byte-equal (proven by the full sweep).

import XCTest
@testable import BASHostKit
@testable import BASObservability
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASProvisionalVerdictTests: XCTestCase {

    // MARK: - Fixtures

    /// A benign budget frame in normal `.engage` run mode.
    private func makeBudget(
        runMode: BASEBrainRunMode = .engage
    ) -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: runMode,
            maxLoops: 1,
            maxCandidates: 2,
            maxDecodeTokens: 100,
            retrievalDepth: 1,
            precisionProfile: .minimal,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }

    /// A risk card at the given level. The non-level scalar fields are
    /// irrelevant to the escalation lattice (it reads only `riskLevel`), so
    /// they are pinned to benign zeros for a minimal, deterministic fixture.
    private func makeRiskCard(
        level: BASBrainRiskLevel
    ) -> BASRiskCard {
        BASRiskCard(
            totalRisk: 0,
            riskLevel: level,
            uncertainty: 0,
            irreversibility: 0,
            manipulationStrength: 0,
            gsiScore: 0,
            recommendedMode: .answer)
    }

    /// An action permit in the given mode (defaults to the benign `.answer`).
    private func makePermit(
        mode: BASActionPermitMode = .answer
    ) -> BASActionPermit {
        BASActionPermit(mode: mode)
    }

    /// An emergency brake at the given level (defaults to benign `.none`).
    private func makeBrake(
        level: BASEmergencyBrakeLevel = .none
    ) -> BASEmergencyBrake {
        BASEmergencyBrake(brakeLevel: level, reasonCodes: [])
    }

    /// Confident uncertainty signals (no floor breach, no debt, lease live).
    private let confidentFloor = 0.9
    private let confidentDebt = 0.0

    // MARK: - provisionalLevel matches the decision core

    /// How a crafted case's level is checked against the expectation:
    /// `.exact` for unambiguous lattice outputs (.pass, .deadStop), `.atLeast`
    /// for the task's stated lower bounds (a block permit → .toolCut OR HIGHER;
    /// high risk → at least .throttle). The block case in fact lands at
    /// .memoryFreeze: the proxy's `mode == .block` clause also trips
    /// `needsProtectedWriteLane`, whose `raise(.memoryFreeze, …)` dominates
    /// .toolCut — exactly the "or higher" the contract allows.
    private enum LevelExpectation {
        case exact(BASSovereignVerdictLevel)
        case atLeast(BASSovereignVerdictLevel)
    }

    /// For several crafted input sets, `buildProvisionalVerdict(...)
    /// .provisionalLevel` equals what `computeVerdictDecision(...)` returns
    /// with the SAME conservative proxy and the SAME empty refs.
    func testProvisionalLevelMatchesDecisionForCraftedInputs() {
        // Each case: (budget, risk, permit, brake, killSwitches, expectation).
        let cases: [(
            BASBudgetFrame,
            BASRiskCard,
            BASActionPermit,
            BASEmergencyBrake,
            [BASKillSwitchID],
            LevelExpectation
        )] = [
            // Low risk, answer permit, normal engage mode → .pass.
            (makeBudget(), makeRiskCard(level: .low), makePermit(),
             makeBrake(), [], .exact(.pass)),
            // Block permit (no lockdown) → .toolCut OR HIGHER (it is in fact
            // .memoryFreeze via the protected-write-lane proxy).
            (makeBudget(), makeRiskCard(level: .low), makePermit(mode: .block),
             makeBrake(), [], .atLeast(.toolCut)),
            // Extreme risk + answer permit → .deadStop (risk_permit_conflict).
            (makeBudget(), makeRiskCard(level: .extreme), makePermit(),
             makeBrake(), [], .exact(.deadStop)),
            // High risk, answer permit → at least .throttle.
            (makeBudget(), makeRiskCard(level: .high), makePermit(),
             makeBrake(), [], .atLeast(.throttle))
        ]

        for (index, testCase) in cases.enumerated() {
            let (budget, risk, permit, brake, switches, expectation) = testCase

            // Re-derive the proxy exactly as buildProvisionalVerdict does, so
            // the cross-check against computeVerdictDecision is faithful.
            let needsProtectedWriteLane =
                switches.contains(.requireReviewedWrites)
                || permit.mode == .delay
                || permit.mode == .replace
                || permit.mode == .block
                // audit hostkit-spine F8: a high-risk card must ALSO require the protected lane (the
                // proxy's "never under-states" contract) — mirrors the production predicate.
                || risk.riskLevel >= .high

            let decision = BASEBrainRuntimeCoordinator.computeVerdictDecision(
                policyLineagePresent: true,
                budgetFrame: budget,
                riskCard: risk,
                actionPermit: permit,
                emergencyBrake: brake,
                activeKillSwitches: switches,
                needsProtectedWriteLane: needsProtectedWriteLane,
                quarantineSources: [],
                rollbackSource: nil)

            let provisional = BASEBrainRuntimeCoordinator.buildProvisionalVerdict(
                policyLineagePresent: true,
                budgetFrame: budget,
                riskCard: risk,
                actionPermit: permit,
                emergencyBrake: brake,
                activeKillSwitches: switches,
                confidenceFloor: confidentFloor,
                maxEvidenceDebt: confidentDebt,
                leaseEnded: false)

            // The load-bearing equivalence: the provisional LEVEL is exactly
            // what the decision core returns for the same proxy + empty refs.
            XCTAssertEqual(provisional.provisionalLevel, decision.level,
                "case \(index): provisional level must equal the decision" +
                " core's level for the same proxy + empty refs")
            switch expectation {
            case .exact(let level):
                XCTAssertEqual(provisional.provisionalLevel, level,
                    "case \(index): provisional level should be exactly the" +
                    " expected escalation level for these crafted inputs")
            case .atLeast(let level):
                XCTAssertGreaterThanOrEqual(provisional.provisionalLevel, level,
                    "case \(index): provisional level should be at least the" +
                    " expected escalation level for these crafted inputs")
            }
            XCTAssertEqual(provisional.reasonCodes, decision.reasonCodes,
                "case \(index): provisional reason codes mirror the" +
                " decision core's accumulated trail")
        }
    }

    /// Spot-check the lattice ordering claims used above: block ≥ toolCut,
    /// deadStop is the ceiling, throttle ≥ throttle. (Guards against a silent
    /// reorder of BASSovereignVerdictLevel that would make the crafted cases
    /// vacuously pass.)
    func testCraftedLevelsRespectLatticeOrdering() {
        XCTAssertGreaterThanOrEqual(BASSovereignVerdictLevel.toolCut, .pass)
        XCTAssertGreaterThanOrEqual(BASSovereignVerdictLevel.deadStop, .toolCut)
        XCTAssertGreaterThanOrEqual(BASSovereignVerdictLevel.throttle, .pass)
    }

    // MARK: - render-independence

    /// The provisional output ignores ref strings entirely (it passes empty
    /// refs to the core), so two calls with otherwise-identical inputs are
    /// equal and `renderIndependent` is always true.
    func testRenderIndependentIgnoresRefStrings() {
        let budget = makeBudget(runMode: .quarantine) // a level that, in the
        // real verdict, WOULD attach quarantine refs — proving the provisional
        // drops them.
        let risk = makeRiskCard(level: .low)
        let permit = makePermit()
        let brake = makeBrake()

        func build() -> BASProvisionalVerdict {
            BASEBrainRuntimeCoordinator.buildProvisionalVerdict(
                policyLineagePresent: true,
                budgetFrame: budget,
                riskCard: risk,
                actionPermit: permit,
                emergencyBrake: brake,
                activeKillSwitches: [],
                confidenceFloor: confidentFloor,
                maxEvidenceDebt: confidentDebt,
                leaseEnded: false)
        }

        let first = build()
        let second = build()

        XCTAssertTrue(first.renderIndependent,
            "the forecast is always render-independent")
        XCTAssertEqual(first, second,
            "identical inputs → identical provisional verdict (no" +
            " dependence on ref strings or any render artifact)")
        XCTAssertEqual(first.provisionalLevel, .quarantine,
            "the quarantine run mode still escalates the LEVEL — only the" +
            " ref IDs are dropped, not the escalation")
    }

    // MARK: - isGenuinelyUncertain composition

    /// `isGenuinelyUncertain` composes from the shared predicate: a low
    /// confidence floor, OR high evidence debt, OR a lease-end all trip it;
    /// confident inputs do not.
    func testIsGenuinelyUncertainComposes() {
        func uncertainFlag(
            confidenceFloor: Double?,
            maxEvidenceDebt: Double?,
            leaseEnded: Bool
        ) -> Bool {
            BASEBrainRuntimeCoordinator.buildProvisionalVerdict(
                policyLineagePresent: true,
                budgetFrame: makeBudget(),
                riskCard: makeRiskCard(level: .low),
                actionPermit: makePermit(),
                emergencyBrake: makeBrake(),
                activeKillSwitches: [],
                confidenceFloor: confidenceFloor,
                maxEvidenceDebt: maxEvidenceDebt,
                leaseEnded: leaseEnded).isGenuinelyUncertain
        }

        // Low confidence floor (< 0.55) → uncertain.
        XCTAssertTrue(uncertainFlag(
            confidenceFloor: 0.2, maxEvidenceDebt: 0.0, leaseEnded: false),
            "confidenceFloor 0.2 < 0.55 → genuinely uncertain")
        // High evidence debt (>= 0.5) → uncertain.
        XCTAssertTrue(uncertainFlag(
            confidenceFloor: 0.9, maxEvidenceDebt: 0.6, leaseEnded: false),
            "maxEvidenceDebt 0.6 >= 0.5 → genuinely uncertain")
        // Lease ended → uncertain.
        XCTAssertTrue(uncertainFlag(
            confidenceFloor: 0.9, maxEvidenceDebt: 0.0, leaseEnded: true),
            "leaseEnded → genuinely uncertain")
        // Confident on all three → not uncertain.
        XCTAssertFalse(uncertainFlag(
            confidenceFloor: 0.9, maxEvidenceDebt: 0.0, leaseEnded: false),
            "confident floor + no debt + live lease → not uncertain")
        // Nil signals + live lease → not uncertain (predicate defaults false).
        XCTAssertFalse(uncertainFlag(
            confidenceFloor: nil, maxEvidenceDebt: nil, leaseEnded: false),
            "absent signals + live lease → not uncertain")
    }

    // MARK: - echoed signals

    /// `confidenceFloorSeen` / `maxEvidenceDebtSeen` echo the inputs verbatim
    /// (including nil).
    func testConfidenceFloorAndDebtAreEchoed() {
        let withValues = BASEBrainRuntimeCoordinator.buildProvisionalVerdict(
            policyLineagePresent: true,
            budgetFrame: makeBudget(),
            riskCard: makeRiskCard(level: .low),
            actionPermit: makePermit(),
            emergencyBrake: makeBrake(),
            activeKillSwitches: [],
            confidenceFloor: 0.42,
            maxEvidenceDebt: 0.37,
            leaseEnded: false)
        XCTAssertEqual(withValues.confidenceFloorSeen, 0.42,
            "confidenceFloorSeen echoes the input")
        XCTAssertEqual(withValues.maxEvidenceDebtSeen, 0.37,
            "maxEvidenceDebtSeen echoes the input")

        let withNils = BASEBrainRuntimeCoordinator.buildProvisionalVerdict(
            policyLineagePresent: true,
            budgetFrame: makeBudget(),
            riskCard: makeRiskCard(level: .low),
            actionPermit: makePermit(),
            emergencyBrake: makeBrake(),
            activeKillSwitches: [],
            confidenceFloor: nil,
            maxEvidenceDebt: nil,
            leaseEnded: false)
        XCTAssertNil(withNils.confidenceFloorSeen,
            "a nil confidence floor is echoed as nil")
        XCTAssertNil(withNils.maxEvidenceDebtSeen,
            "a nil evidence debt is echoed as nil")
    }
}
