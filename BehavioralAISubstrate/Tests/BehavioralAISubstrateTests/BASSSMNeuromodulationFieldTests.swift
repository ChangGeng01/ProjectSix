// T3.2 — SSM neuromodulation field extension (OBSERVATION-ONLY), proven at both the pure-projector
// level and through `runTurn`. Mirrors BASSSMCautionOperatorRunTurnTests. The safety net:
//   • flag-off byte-equality — the FULL-turn replay digest is identical with the suggestions flag off
//     vs never mentioned (code-absent witness), and the emitted observation's field stays nil
//   • OFF-preimage proof — even flag-ON the result digest is unchanged (the suggestion lives only on
//     the observation side-channel; zero SSM fields in BASEBrainTurnResult)
//   • determinism — same inputs ⇒ identical suggestion record (projector twice + full pipeline twice)
//   • delta correctness — deltaPasses == suggested − actual
//   • sign discipline (ENFORCED, swept) — suggestedTargetPasses ≥ actual (raise-only) AND
//     suggestedOrganPowerBudget ≤ host hint (conserve-only), including extremes 0.0/1.0 + degenerate
//   • schema backward decode — JSON without the new key decodes with a nil field
//   • L2 policy-counterfactual honesty — the recorded backends come from the PURE
//     `bas_organ_router_select` policy call (no live production caller; deterministic given budget)

import XCTest
import Foundation
@testable import BASHostKit
@testable import BASRuntimeCore
@testable import BASMetalSubstrate

final class BASSSMNeuromodulationFieldTests: XCTestCase {

    private final class ObservationBox: @unchecked Sendable {
        var observations: [BASMambaSSMTurnObservation] = []
    }

    /// Coordinator with the SSM caution operator ON (the suggestion seam is nested inside it).
    /// `suggestionsEnabled == nil` ⇒ the new flag is NEVER MENTIONED (the code-absent witness);
    /// otherwise it is set explicitly.
    private func makeCoordinator(
        suggestionsEnabled: Bool?,
        box: ObservationBox
    ) -> BASEBrainRuntimeCoordinator {
        var coordinator = BASEBrainRuntimeCoordinator(
            powerClockService: StubPowerClock(),
            hostProfileService: StubHost(),
            contextService: StubContext(),
            decomposeService: StubDecompose(),
            memoryService: StubMemory(),
            loopService: StubLoop(),
            triSelfService: StubTriSelf(),
            riskService: StubRisk(),
            actionService: StubAction(),
            evolutionService: StubEvolution(),
            ssmCautionOperatorEnabled: true,
            ssmCautionObservationSink: { [box] in box.observations.append($0) })
        if let suggestionsEnabled {
            coordinator.ssmNeuromodulationSuggestionsEnabled = suggestionsEnabled
        }
        return coordinator
    }

    private func canonicalDigest(_ result: BASEBrainTurnResult) -> String {
        BASEBrainTurnResultReplayDigest.from(
            result: result,
            producedAt: Date(timeIntervalSince1970: 0)).digestString
    }

    // MARK: - 1. Flag-off byte-equality (full-turn digest + nil field)

    func testFlagOffFullTurnDigestByteEqualAndFieldStaysNil() throws {
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let absentBox = ObservationBox()
        let offBox = ObservationBox()

        // (a) the new flag NEVER MENTIONED — the code-absent witness (default OFF).
        let absentResult = makeCoordinator(suggestionsEnabled: nil, box: absentBox)
            .runTurn(request)
        // (b) the new flag EXPLICITLY false.
        let offResult = makeCoordinator(suggestionsEnabled: false, box: offBox)
            .runTurn(request)

        XCTAssertEqual(
            canonicalDigest(absentResult), canonicalDigest(offResult),
            "flag off ⇒ FULL-turn replay digest identical to the code-absent witness (红线 7 / ADR-014)")

        let absentObs = try XCTUnwrap(absentBox.observations.first,
            "the operator-on observation is still emitted")
        let offObs = try XCTUnwrap(offBox.observations.first)
        XCTAssertNil(absentObs.neuromodulationSuggestion,
            "flag never mentioned ⇒ the suggestion field stays nil")
        XCTAssertNil(offObs.neuromodulationSuggestion,
            "flag explicitly off ⇒ the suggestion field stays nil")
        XCTAssertEqual(absentObs, offObs,
            "the emitted observation is byte-identical to the code-absent witness")
    }

    /// OFF-preimage doctrine witness: the suggestion lives ONLY on the observation side-channel, so
    /// even turning the flag ON leaves the FULL-turn result digest unchanged (zero SSM fields in
    /// `BASEBrainTurnResult` — the replay-digest preimage is untouched by construction).
    func testFlagOnLeavesResultDigestUnchangedOffPreimageProof() throws {
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let offResult = makeCoordinator(suggestionsEnabled: false, box: ObservationBox())
            .runTurn(request)
        let onBox = ObservationBox()
        let onResult = makeCoordinator(suggestionsEnabled: true, box: onBox)
            .runTurn(request)

        XCTAssertEqual(
            canonicalDigest(offResult), canonicalDigest(onResult),
            "flag ON must not perturb the result digest — the record is OFF the digest preimage")
        let onObs = try XCTUnwrap(onBox.observations.first)
        XCTAssertNotNil(onObs.neuromodulationSuggestion,
            "flag ON (+ sink set) ⇒ the emitted observation carries the suggestion record")
    }

    // MARK: - 2. Determinism

    func testProjectorIsDeterministic() {
        let a = BASSSMNeuromodulationField.suggestion(
            ssmCaution: 0.42, actualTargetPasses: 2, thermallyFlooredMaxLoops: 4,
            thermalLevel: .warm, npuAvailable: true)
        let b = BASSSMNeuromodulationField.suggestion(
            ssmCaution: 0.42, actualTargetPasses: 2, thermallyFlooredMaxLoops: 4,
            thermalLevel: .warm, npuAvailable: true)
        XCTAssertEqual(a, b,
            "pure projector: same inputs ⇒ identical record (no clock, no randomness)")
    }

    func testFullPipelineSuggestionIsDeterministic() throws {
        let request = BASCoordinatorTestStubs.makeStubRequest()
        let box1 = ObservationBox()
        let box2 = ObservationBox()
        _ = makeCoordinator(suggestionsEnabled: true, box: box1).runTurn(request)
        _ = makeCoordinator(suggestionsEnabled: true, box: box2).runTurn(request)
        let s1 = try XCTUnwrap(box1.observations.first?.neuromodulationSuggestion)
        let s2 = try XCTUnwrap(box2.observations.first?.neuromodulationSuggestion)
        XCTAssertEqual(s1, s2,
            "full pipeline twice with identical inputs ⇒ identical suggestion record")
    }

    // MARK: - 3. Delta correctness

    func testDeltaPassesEqualsSuggestedMinusActual() throws {
        // Projector level, across the band.
        for caution in stride(from: 0.0, through: 1.0, by: 0.125) {
            for actual in 1...4 {
                let s = BASSSMNeuromodulationField.suggestion(
                    ssmCaution: caution, actualTargetPasses: actual,
                    thermallyFlooredMaxLoops: 6, thermalLevel: .nominal,
                    npuAvailable: false)
                XCTAssertEqual(s.deltaPasses, s.suggestedTargetPasses - s.actualTargetPasses,
                    "deltaPasses == suggested − actual (caution \(caution), actual \(actual))")
                XCTAssertEqual(s.actualTargetPasses, actual)
            }
        }
        // Pipeline level.
        let box = ObservationBox()
        _ = makeCoordinator(suggestionsEnabled: true, box: box)
            .runTurn(BASCoordinatorTestStubs.makeStubRequest())
        let record = try XCTUnwrap(box.observations.first?.neuromodulationSuggestion)
        XCTAssertEqual(record.deltaPasses,
            record.suggestedTargetPasses - record.actualTargetPasses)
        XCTAssertEqual(record.actualTargetPasses, 1,
            "deliberation loop disabled ⇒ the single pass is the actual")
    }

    // MARK: - 4. Sign discipline (raise-only / conserve-only), property-style sweep

    func testSignDisciplineSweepIncludingExtremesAndDegenerate() {
        let hints: [BASAutoRouteRanker.OrganRouterBudget] = [.constrained, .normal, .generous]
        var cautions = Array(stride(from: 0.0, through: 1.0, by: 0.05))
        cautions += [0.0, 1.0]                                            // extremes, explicitly
        cautions += [-1.0, 2.0, .nan, .infinity, -.infinity]              // degenerate (clamped)
        for caution in cautions {
            for actual in 1...4 {
                for floored in 0...5 {
                    let suggested = BASSSMNeuromodulationField.suggestedTargetPasses(
                        ssmCaution: caution, actualTargetPasses: actual,
                        thermallyFlooredMaxLoops: floored)
                    XCTAssertGreaterThanOrEqual(suggested, actual,
                        "raise-only: suggested ≥ actual (caution \(caution), actual \(actual), floor \(floored))")
                    XCTAssertLessThanOrEqual(suggested, max(actual, floored),
                        "the suggestion never exceeds the loop's own normalization band")
                }
                for hint in hints {
                    let budget = BASSSMNeuromodulationField.suggestedOrganPowerBudget(
                        ssmCaution: caution, hostHint: hint)
                    XCTAssertLessThanOrEqual(budget.rawValue, hint.rawValue,
                        "conserve-only: suggested budget ≤ host hint (caution \(caution), hint \(hint))")
                }
            }
        }
    }

    func testSignDisciplineExactExtremes() {
        // caution == 0 ⇒ no modulation: suggested passes == actual, suggested budget == hint.
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedTargetPasses(
            ssmCaution: 0.0, actualTargetPasses: 2, thermallyFlooredMaxLoops: 5), 2)
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedOrganPowerBudget(
            ssmCaution: 0.0, hostHint: .generous), .generous)
        // caution == 1 ⇒ full modulation: suggested passes == band ceiling, budget == floor tier.
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedTargetPasses(
            ssmCaution: 1.0, actualTargetPasses: 2, thermallyFlooredMaxLoops: 5), 5)
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedOrganPowerBudget(
            ssmCaution: 1.0, hostHint: .generous), .constrained)
        // NaN ⇒ clamps to 0 ⇒ no modulation in either direction (never a lower).
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedTargetPasses(
            ssmCaution: .nan, actualTargetPasses: 3, thermallyFlooredMaxLoops: 5), 3)
        XCTAssertEqual(BASSSMNeuromodulationField.suggestedOrganPowerBudget(
            ssmCaution: .nan, hostHint: .normal), .normal)
    }

    // MARK: - 5. Schema backward decode (absent key ⇒ nil — the gpuShadowMAE precedent)

    func testObservationWithoutNewKeyDecodesWithNilField() throws {
        // The pre-T3.2 wire shape: only the required keys, no `neuromodulationSuggestion`.
        let legacyJSON = """
        {"sessionID":"s","turnID":"t","affectCount":1,"historyCount":2,"candidateCount":3,\
        "ssmCaution":0.5,"finalMagnitude":0.0125}
        """
        let decoded = try JSONDecoder().decode(
            BASMambaSSMTurnObservation.self,
            from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.neuromodulationSuggestion,
            "absent key must decode to nil (Codable-backward)")
        XCTAssertNil(decoded.gpuShadowMAE)
        XCTAssertEqual(decoded.ssmCaution, 0.5, accuracy: 1e-12)
    }

    func testObservationWithSuggestionRoundTripsLossless() throws {
        let suggestion = BASSSMNeuromodulationField.suggestion(
            ssmCaution: 0.8, actualTargetPasses: 1, thermallyFlooredMaxLoops: 3,
            thermalLevel: .hot, npuAvailable: false)
        let observation = BASMambaSSMTurnObservation(
            sessionID: "s", turnID: "t", affectCount: 1, historyCount: 1,
            candidateCount: 1, ssmCaution: 0.8, finalMagnitude: 0.02,
            neuromodulationSuggestion: suggestion)
        let decoded = try JSONDecoder().decode(
            BASMambaSSMTurnObservation.self,
            from: JSONEncoder().encode(observation))
        XCTAssertEqual(decoded, observation,
            "Codable round-trip preserves the suggestion record")
        XCTAssertEqual(decoded.neuromodulationSuggestion, suggestion)
    }

    // MARK: - 6. L2 policy-counterfactual honesty

    /// The recorded per-family backends must come from the PURE `bas_organ_router_select` policy call
    /// at the SUGGESTED budget — `bas_organ_router_select` has NO live production caller, so the record
    /// is a POLICY COUNTERFACTUAL (what the Rust policy WOULD select), never a live-dispatch claim.
    /// Deterministic given the budget inputs.
    func testSuggestedBackendsComeFromThePurePolicyCall() throws {
        #if os(iOS) || os(macOS)
        let suggestion = BASSSMNeuromodulationField.suggestion(
            ssmCaution: 0.9, actualTargetPasses: 1, thermallyFlooredMaxLoops: 2,
            thermalLevel: .nominal, npuAvailable: false)
        // caution 0.9 ≥ two-tier threshold ⇒ generous hint stepped to the constrained floor.
        XCTAssertEqual(suggestion.suggestedOrganPowerBudget, "constrained")
        XCTAssertEqual(suggestion.hostHintBudget, "generous")

        XCTAssertEqual(suggestion.suggestedBackendByFamily.count,
            BASSSMNeuromodulationField.familyNamePairs.count,
            "every routed family is recorded when the FFI is available")
        for pair in BASSSMNeuromodulationField.familyNamePairs {
            let direct = try XCTUnwrap(BASAutoRouteRanker.organRouterSelect(
                family: pair.family,
                shapeSize: BASSSMNeuromodulationField.counterfactualShapeSize,
                budget: .constrained))
            XCTAssertEqual(
                suggestion.suggestedBackendByFamily[pair.name],
                BASSSMNeuromodulationField.backendName(direct),
                "recorded \(pair.name) backend == the pure policy output at the suggested budget")
        }
        // Deterministic given the budget inputs: recompute ⇒ identical map.
        XCTAssertEqual(
            BASSSMNeuromodulationField.suggestedBackendByFamily(budget: .constrained),
            suggestion.suggestedBackendByFamily)
        #endif
    }

    /// The OPTIONAL live-actual companion: `actualAttentionBackend` is the ADR-039 Phase-3 dispatch
    /// router's replay-stable CHOICE recomputed from the device state (a DIFFERENT policy surface
    /// from the organ router — dispatch-router vocabulary, recorded as such).
    func testActualAttentionBackendIsTheDeterministicDispatchRouterChoice() {
        let suggestion = BASSSMNeuromodulationField.suggestion(
            ssmCaution: 0.5, actualTargetPasses: 1, thermallyFlooredMaxLoops: 1,
            thermalLevel: .critical, npuAvailable: true)
        let expected = BASMetalKernelDispatchRouter.decide(
            op: .attention, thermalState: .critical, anePriority: .aneFirst)
        XCTAssertEqual(suggestion.actualAttentionBackend, expected.routing.rawValue,
            "the recorded actual == the pure Phase-3 routing CHOICE for the same device state")
        XCTAssertEqual(suggestion.actualAttentionBackend, "cpu-stub",
            "thermal-critical ⇒ the router declines the accelerator (ADR-039 Rule 1)")
    }
}
