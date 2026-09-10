// MARK: - BASChapter994AuthoritativeModeScaffoldTests
// chapter 九百九十四 / M3675 — fabric-authoritative mode scaffold
//
// Closes plan section 9.1-9.7 "future fabric-authoritative mode"
// gap deferred since ch 960 observation-only launch。 This chapter
// ships the SUBSTRATE-SIDE SCAFFOLD only — actual per-state-domain
// replacement logic remains host responsibility per ADR-014 OPT-IN
// (each host has different downstream consumers of state objects)。
//
// Tests pin:
//   1. Default mode is `.observationOnly` (byte-equal to pre-ch-994)
//   2. Explicit `.authoritative` mode flows through the runtime
//   3. Mode is preserved across runtime construction
//   4. Mode enum has exactly 2 cases (CaseIterable contract)
//   5. Mode is Codable for wire-format stability

import XCTest
@testable import BASMemory

final class BASChapter994AuthoritativeModeScaffoldTests:
    XCTestCase
{

    func testCRITICAL_DefaultMode_IsObservationOnly() {
        let roster = makeRoster()
        let runtime = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph())
        XCTAssertEqual(runtime.mode, .observationOnly,
            "ch 994 CRITICAL: default mode MUST be " +
            "`.observationOnly` to preserve ch 960 byte-equality " +
            "(red-line 7 + ADR-014 OPT-IN)")
    }

    func testExplicitAuthoritativeMode_FlowsThroughRuntime() {
        let roster = makeRoster()
        let runtime = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph(),
            mode: .authoritative)
        XCTAssertEqual(runtime.mode, .authoritative,
            "ch 994: explicit `.authoritative` mode MUST flow " +
            "through runtime unchanged")
    }

    func testModeEnum_HasExactlyTwoCases() {
        XCTAssertEqual(
            BASAgentFabricMode.allCases.count, 2,
            "ch 994: BASAgentFabricMode MUST have exactly 2 " +
            "cases (observationOnly + authoritative)。 Adding " +
            "a 3rd case is a SDK wire-format change requiring " +
            "explicit version bump per " +
            "Docs/SDK_API_STABILITY.md")
        let cases = Set(BASAgentFabricMode.allCases)
        XCTAssertTrue(cases.contains(.observationOnly))
        XCTAssertTrue(cases.contains(.authoritative))
    }

    func testMode_RawValueStable() {
        // Wire-format stability:rawValues MUST NOT change
        XCTAssertEqual(
            BASAgentFabricMode.observationOnly.rawValue,
            "observationOnly")
        XCTAssertEqual(
            BASAgentFabricMode.authoritative.rawValue,
            "authoritative")
    }

    func testMode_CodableRoundTrip() throws {
        let original: BASAgentFabricMode = .authoritative
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(
            BASAgentFabricMode.self, from: data)
        XCTAssertEqual(decoded, original,
            "ch 994: Codable round-trip MUST preserve mode " +
            "(wire-format stability for future on-disk persistence)")
    }

    /// Defense:dispatcher behavior is currently mode-agnostic
    /// (observation-only and authoritative produce same emitted
    /// deltas)。 The DIFFERENCE between modes is what the HOST
    /// does with the result downstream — but the dispatcher's
    /// own output MUST be identical regardless of mode so test
    /// scenarios that compare across modes have a stable
    /// substrate-side floor。
    func testDispatcher_OutputModeAgnostic() async {
        let roster = makeRoster()
        let input = makeInput()
        // Same input,both modes
        let runtimeObs = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph(),
            mode: .observationOnly)
        let resultObs = await runtimeObs.dispatchTurn(
            input: input)
        let runtimeAuth = BASAgentFabricRuntime(
            roster: roster,
            graph: BASSharedStateGraph(),
            mode: .authoritative)
        let resultAuth = await runtimeAuth.dispatchTurn(
            input: input)
        XCTAssertEqual(
            resultObs.emittedDeltas.count,
            resultAuth.emittedDeltas.count,
            "ch 994 CRITICAL: dispatcher output MUST be " +
            "mode-agnostic — same emitted-delta count " +
            "regardless of mode。 Mode is a host-side signal " +
            "about how to CONSUME the result,not a switch " +
            "that changes substrate behavior。")
    }

    // MARK: - Helpers

    private func makeRoster() -> BASAgentTurnRoster {
        BASAgentTurnRoster(
            scout: BASAgentSpec(
                agentID: "scout.1",
                role: .scout,
                writeDomains: [.situationField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            planner: BASAgentSpec(
                agentID: "planner.1",
                role: .planner,
                writeDomains: [.candidateFrontier],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            risk: BASAgentSpec(
                agentID: "risk.1",
                role: .risk,
                writeDomains: [.riskField],
                defaultLeaseProfile: .hotSeat,
                visibility: .high),
            surface: BASAgentSpec(
                agentID: "surface.1",
                role: .surface,
                writeDomains: [.renderFrame],
                defaultLeaseProfile: .hotSeat,
                visibility: .high))
    }

    private func makeInput() -> BASAgentTurnInput {
        BASAgentTurnInput(
            turnID: "t.1",
            plannerCandidates: [
                BASPlannerCandidate(
                    candidateID: "c.1",
                    title: "test",
                    actionSummary: "a",
                    confidence: 0.8),
            ],
            risk: BASRiskInput(candidates: [
                BASRiskCandidate(
                    candidateID: "c.1",
                    reversibility: 0.8),
            ]),
            surface: BASSurfaceInput(
                acceptedCandidateID: "c.1",
                riskBand: .low,
                reversibility: 0.8))
    }
}
