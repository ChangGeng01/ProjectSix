// MARK: - BASChapter986HostAlignmentInputAdapterTests
// chapter 九百八十六 / M3635 — Cross-Module Integration Arc ch4
//
// Closes ch 982.5 META-REVIEW cross-module Gap 1:
// BASHostAlignmentSeat's `hostConstraintsRef` was a free-form
// String — the fabric did NOT actually read from the live L5
// BASHostConstitution。 Now the adapter derives axes +
// strictness from the live constitution。
//
// Tests pin:
//   1. boundaryAxes is the SORTED union of valueAxes.axes +
//      boundaryVeil.hardNoGo (deterministic + de-duped)
//   2. hostID flows from constitution
//   3. styleStrictness derived from styleGenome.structureBias
//   4. styleStrictnessOverride takes precedence when supplied
//   5. Empty constitution (no axes) produces empty boundaryAxes
//   6. Determinism — two calls with same input byte-equal output

import XCTest
@testable import BASOrchestration
@testable import BASMemory

final class BASChapter986HostAlignmentInputAdapterTests:
    XCTestCase
{

    // MARK: - boundaryAxes derivation

    func testBoundaryAxes_UnionOfValueAxesAndHardNoGo() {
        let constitution = BASHostConstitution(
            hostID: "user.1",
            valueAxes: BASValueAxisSet(
                axes: ["financial", "relational", "privacy"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["legal", "privacy"]))
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        // privacy appears in both lists — must dedupe + sorted
        XCTAssertEqual(input.hostBoundaryAxes,
            ["financial", "legal", "privacy", "relational"],
            "ch 986 Gap 1: boundaryAxes MUST be sorted union " +
            "of valueAxes.axes + boundaryVeil.hardNoGo")
    }

    func testBoundaryAxes_DeterministicOrdering() {
        // Build the same constitution twice in different orders
        let c1 = BASHostConstitution(
            hostID: "u",
            valueAxes: BASValueAxisSet(
                axes: ["zebra", "apple", "mango"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["banana"]))
        let c2 = BASHostConstitution(
            hostID: "u",
            valueAxes: BASValueAxisSet(
                axes: ["mango", "apple", "zebra"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["banana"]))
        let i1 = BASAgentFabricAdapters
            .hostAlignmentInput(from: c1)
        let i2 = BASAgentFabricAdapters
            .hostAlignmentInput(from: c2)
        XCTAssertEqual(i1.hostBoundaryAxes, i2.hostBoundaryAxes,
            "ch 986 Gap 1: same axes in different order MUST " +
            "produce byte-equal output (Root Law 7 可回放)")
    }

    // MARK: - hostID + strictness derivation

    func testHostID_FlowsFromConstitution() {
        let constitution = BASHostConstitution(
            hostID: "user.alpha")
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        XCTAssertEqual(input.hostID, "user.alpha",
            "ch 986 Gap 1: hostID MUST flow from constitution")
    }

    func testStyleStrictness_DerivedFromStructureBias() {
        let constitution = BASHostConstitution(
            hostID: "u",
            styleGenome: BASStyleGenome(
                structureBias: 0.85))
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        XCTAssertEqual(input.styleStrictness, 0.85,
            accuracy: 0.001,
            "ch 986 Gap 1: strictness MUST flow from " +
            "styleGenome.structureBias")
    }

    func testStyleStrictness_OverrideTakesPrecedence() {
        let constitution = BASHostConstitution(
            hostID: "u",
            styleGenome: BASStyleGenome(
                structureBias: 0.3))
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: constitution,
                styleStrictnessOverride: 0.95)
        XCTAssertEqual(input.styleStrictness, 0.95,
            accuracy: 0.001,
            "ch 986 Gap 1: override MUST take precedence over " +
            "derived value")
    }

    func testStyleStrictness_DefensiveClamp() {
        // structureBias should already be [0,1] per BASStyleGenome
        // contract,but defense-in-depth at the adapter boundary
        let lowConstitution = BASHostConstitution(
            hostID: "u",
            styleGenome: BASStyleGenome(
                structureBias: -0.5))
        let lowInput = BASAgentFabricAdapters
            .hostAlignmentInput(from: lowConstitution)
        XCTAssertEqual(lowInput.styleStrictness, 0.0,
            accuracy: 0.001,
            "ch 986 Gap 1: out-of-range structureBias MUST " +
            "clamp at lower bound")
        let highConstitution = BASHostConstitution(
            hostID: "u",
            styleGenome: BASStyleGenome(
                structureBias: 1.5))
        let highInput = BASAgentFabricAdapters
            .hostAlignmentInput(from: highConstitution)
        XCTAssertEqual(highInput.styleStrictness, 1.0,
            accuracy: 0.001,
            "ch 986 Gap 1: out-of-range structureBias MUST " +
            "clamp at upper bound")
    }

    // MARK: - Edge cases

    func testEmptyConstitution_ProducesEmptyAxes() {
        let constitution = BASHostConstitution(hostID: "u")
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        XCTAssertTrue(input.hostBoundaryAxes.isEmpty,
            "ch 986 Gap 1: empty constitution MUST produce " +
            "empty boundaryAxes")
        XCTAssertEqual(input.hostID, "u")
    }

    func testCandidatesFlowFromParameter() {
        let constitution = BASHostConstitution(hostID: "u")
        let candidates = [
            BASHostAlignmentCandidate(
                candidateID: "c.1",
                title: "test",
                touchesAxes: ["financial"]),
        ]
        let input = BASAgentFabricAdapters
            .hostAlignmentInput(
                from: constitution,
                candidates: candidates)
        XCTAssertEqual(input.candidates.count, 1)
        XCTAssertEqual(input.candidates[0].touchesAxes,
            ["financial"])
    }

    // MARK: - Determinism

    func testAdapter_IsDeterministic() {
        let constitution = BASHostConstitution(
            hostID: "u",
            valueAxes: BASValueAxisSet(
                axes: ["financial"]),
            boundaryVeil: BASBoundaryVeil(
                hardNoGo: ["legal"]),
            styleGenome: BASStyleGenome(
                structureBias: 0.6))
        let i1 = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        let i2 = BASAgentFabricAdapters
            .hostAlignmentInput(from: constitution)
        XCTAssertEqual(i1.hostBoundaryAxes, i2.hostBoundaryAxes)
        XCTAssertEqual(i1.hostID, i2.hostID)
        XCTAssertEqual(i1.styleStrictness, i2.styleStrictness)
    }
}
