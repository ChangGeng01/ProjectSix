import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASOrchestration
import BASRuntimeCore

/// M318 — pin that `BASAbyssalBranch.deriveAll(...)` is consumed
/// by the L14 sovereign audit entry, only when an
/// `BASAbyssalPressure` reading exceeds the abyssal threshold
/// (default 0.5).
///
/// Pre-M318 the `BASAbyssalBranch` schema (white paper §7) had
/// 0 runtime callers. M318 adds `deriveAll(candidateIDs:
/// pressure:)` that fans out one branch per candidate when the
/// abyssal pressure aggregate magnitude is elevated, and wires
/// the result into runTurn audit signalRefs as additive metadata
/// (`abyssalBranch.count` / `.maxLoad` / optional `.escalation`).
///
/// Doctrine pinned:
/// - Empty array (below threshold) → all `abyssalBranch.*` codes
///   elided
/// - Each branch carries the same pressure dimensions
///   (unknown-load / manipulation / ontology-distortion) the
///   white paper §7 promised
/// - Closure conditions populated only at high aggregate
///   magnitude (≥0.7)
final class M318AbyssalBranchConsumptionTests: XCTestCase {

    // MARK: - Pure derive tests

    /// 1. Below threshold (low pressure) → empty array.
    func testDeriveAllReturnsEmptyBelowThreshold() {
        let pressure = BASAbyssalPressure(
            pressureID: "low",
            unknownLoad: 0.1,
            consequenceRadius: 0.1,
            evidenceDebt: 0.1,
            ontologyDistortion: 0.1,
            manipulationIndex: 0.1,
            narrativePollution: 0.1,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        let branches = BASAbyssalBranch.deriveAll(
            candidateIDs: ["c-1", "c-2"],
            pressure: pressure)
        XCTAssertTrue(branches.isEmpty)
    }

    /// 2. Above threshold → one branch per candidate.
    func testDeriveAllReturnsOneBranchPerCandidate() {
        let pressure = BASAbyssalPressure(
            pressureID: "high",
            unknownLoad: 0.6,
            consequenceRadius: 0.6,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.6,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        let branches = BASAbyssalBranch.deriveAll(
            candidateIDs: ["c-1", "c-2", "c-3"],
            pressure: pressure)
        XCTAssertEqual(branches.count, 3)
        XCTAssertEqual(
            branches.map(\.sourceCandidateRef),
            ["c-1", "c-2", "c-3"])
    }

    /// 3. Branch fields mirror the pressure reading exactly.
    func testBranchFieldsMirrorPressure() {
        let pressure = BASAbyssalPressure(
            pressureID: "mirror",
            unknownLoad: 0.7,
            consequenceRadius: 0.6,
            evidenceDebt: 0.5,
            ontologyDistortion: 0.65,
            manipulationIndex: 0.55,
            narrativePollution: 0.6,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        let branch = BASAbyssalBranch.deriveAll(
            candidateIDs: ["c-X"],
            pressure: pressure).first!
        XCTAssertEqual(branch.unknownLoad, 0.7)
        XCTAssertEqual(branch.manipulationLoad, 0.55)
        XCTAssertEqual(branch.ontologyDistortion, 0.65)
        XCTAssertEqual(branch.sourceCandidateRef, "c-X")
        XCTAssertEqual(
            branch.branchID, "abyssal-branch-c-X")
    }

    /// 4. High aggregate magnitude (≥0.7) populates closure
    ///    conditions; medium magnitude leaves them empty.
    func testClosureConditionsScaleByAggregateMagnitude() {
        // Aggregate mean = 0.6 → no closure conditions.
        let medium = BASAbyssalPressure(
            pressureID: "medium",
            unknownLoad: 0.6,
            consequenceRadius: 0.6,
            evidenceDebt: 0.6,
            ontologyDistortion: 0.6,
            manipulationIndex: 0.6,
            narrativePollution: 0.6,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        // Aggregate mean = 0.8 → closure conditions populated.
        let high = BASAbyssalPressure(
            pressureID: "high",
            unknownLoad: 0.8,
            consequenceRadius: 0.8,
            evidenceDebt: 0.8,
            ontologyDistortion: 0.8,
            manipulationIndex: 0.8,
            narrativePollution: 0.8,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        let mediumBranch = BASAbyssalBranch.deriveAll(
            candidateIDs: ["c-m"], pressure: medium).first!
        let highBranch = BASAbyssalBranch.deriveAll(
            candidateIDs: ["c-h"], pressure: high).first!
        XCTAssertTrue(
            mediumBranch.requiredClosureConditions.isEmpty)
        XCTAssertTrue(
            highBranch.requiredClosureConditions
                .contains("sovereign-review-passed"))
    }

    /// 5. Empty candidate list → empty branch list, even at
    ///    high pressure.
    func testEmptyCandidatesProducesEmptyBranches() {
        let pressure = BASAbyssalPressure(
            pressureID: "high",
            unknownLoad: 0.9,
            consequenceRadius: 0.9,
            evidenceDebt: 0.9,
            ontologyDistortion: 0.9,
            manipulationIndex: 0.9,
            narrativePollution: 0.9,
            recommendedModes: [],
            sovereignEscalationHint: nil)
        let branches = BASAbyssalBranch.deriveAll(
            candidateIDs: [], pressure: pressure)
        XCTAssertTrue(branches.isEmpty)
    }

    // MARK: - Runtime integration

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m318.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m318.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m318.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m318.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m318.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m318.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m318",
                policyProfileID: "host.m318.policy",
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

    /// 6. Runtime turn at low risk emits no `abyssalBranch.*`
    ///    codes (M303 abyssal pressure stays low → M318 derives
    ///    empty array → audit elides cleanly).
    func testLowRiskTurnEliesAbyssalBranchCodes() throws {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: "low-risk M318 turn",
                title: "M318 abyssal branch elide",
                riskLevel: .low))
        let turn = try XCTUnwrap(result.eBrainTurn)
        let auditEntry = try XCTUnwrap(
            turn.sovereignAuditEntry)
        let branchCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("abyssalBranch.")
        }
        XCTAssertTrue(
            branchCodes.isEmpty,
            "low-risk turn must emit zero abyssalBranch codes, " +
            "got \(branchCodes)")
    }
}
