import XCTest
@testable import BASOrchestration

/// M388 — pin doctrine red line 7 (watcher 只 hint 不裁决) on the
/// three watcher schemas (`BASNarrativeDistortion`,
/// `BASAnomalyTrace`, `BASAbyssalBranch`). The test surface is
/// schema-level: each schema must produce stable readout values
/// that the audit emitter can use as reason codes WITHOUT giving
/// the schema authority to widen permits or escalate verdicts. The
/// sister coordinator-level coverage lives in the existing
/// `BASEBrainSchemaCoreTests` (which exercises full L11/L14 turn
/// shape and would catch any contract drift in the schemas →
/// permit/verdict path).
///
/// What this file pins:
///
///   1. `BASNarrativeDistortion.dominantAxisName` returns the
///      canonical kebab-case white-paper name for whichever axis
///      equals `maxAxis`, or `"none"` when every axis is zero.
///   2. The 5-name tie-break order (`reality-denial` ≻
///      `history-rewrite` ≻ `forced-closure` ≻ `role-inversion`
///      ≻ `urgency-mask`) is deterministic.
///   3. `dominantAxisName` is observationally consistent with
///      `maxAxis` (the named axis's value equals `maxAxis` for
///      every input).
///   4. `isNonTrivial` and `dominantAxisName == "none"` agree:
///      `isNonTrivial == false` ⟺ `dominantAxisName == "none"`.
///   5. `BASAnomalyTrace` round-trip Codable preserves all fields.
///   6. `BASAbyssalBranch` round-trip Codable preserves all fields
///      including the closure-conditions list (red line 7 doctrine
///      pin: branch annotation is a hint, never a self-promoting
///      decision; Codable round-trip is the contract).
final class M388WatcherHintRedLineTests: XCTestCase {

    // MARK: - Fixture helpers

    private func distortion(
        rd: Double = 0,
        hr: Double = 0,
        fc: Double = 0,
        ri: Double = 0,
        um: Double = 0
    ) -> BASNarrativeDistortion {
        BASNarrativeDistortion(
            distortionID: "d-test",
            realityDenial: rd,
            historyRewrite: hr,
            forcedClosure: fc,
            roleInversion: ri,
            urgencyMask: um,
            confidence: 0.5)
    }

    // MARK: - 1. dominantAxisName matches each axis when others are zero

    func testDominantAxisNameMatchesActiveAxis() {
        XCTAssertEqual(
            distortion(rd: 0.7).dominantAxisName,
            "reality-denial")
        XCTAssertEqual(
            distortion(hr: 0.7).dominantAxisName,
            "history-rewrite")
        XCTAssertEqual(
            distortion(fc: 0.7).dominantAxisName,
            "forced-closure")
        XCTAssertEqual(
            distortion(ri: 0.7).dominantAxisName,
            "role-inversion")
        XCTAssertEqual(
            distortion(um: 0.7).dominantAxisName,
            "urgency-mask")
    }

    // MARK: - 2. Tie-break order is canonical

    func testTieBreakOrderIsCanonical() {
        // All equal — first wins (reality-denial).
        XCTAssertEqual(
            distortion(rd: 0.5, hr: 0.5, fc: 0.5,
                       ri: 0.5, um: 0.5).dominantAxisName,
            "reality-denial")
        // Skip reality-denial → history-rewrite next.
        XCTAssertEqual(
            distortion(hr: 0.5, fc: 0.5, ri: 0.5,
                       um: 0.5).dominantAxisName,
            "history-rewrite")
        // Skip history-rewrite → forced-closure.
        XCTAssertEqual(
            distortion(fc: 0.5, ri: 0.5,
                       um: 0.5).dominantAxisName,
            "forced-closure")
        // Skip forced-closure → role-inversion.
        XCTAssertEqual(
            distortion(ri: 0.5, um: 0.5).dominantAxisName,
            "role-inversion")
        // Only urgency-mask.
        XCTAssertEqual(
            distortion(um: 0.5).dominantAxisName,
            "urgency-mask")
    }

    // MARK: - 3. dominantAxisName consistent with maxAxis

    func testDominantAxisNameConsistentWithMaxAxis() {
        let cases = [
            distortion(rd: 0.4, hr: 0.7, fc: 0.5),
            distortion(rd: 0.1, hr: 0.2, fc: 0.3, ri: 0.9),
            distortion(rd: 0.55, hr: 0.55, ri: 0.6),
            distortion(rd: 0.5, um: 1.0),
        ]
        for d in cases {
            let name = d.dominantAxisName
            let value: Double
            switch name {
            case "reality-denial": value = d.realityDenial
            case "history-rewrite": value = d.historyRewrite
            case "forced-closure": value = d.forcedClosure
            case "role-inversion": value = d.roleInversion
            case "urgency-mask": value = d.urgencyMask
            default:
                XCTFail("unexpected axis name: \(name)")
                return
            }
            XCTAssertEqual(value, d.maxAxis,
                           accuracy: 0.0001,
                           "axis \(name) value should equal maxAxis")
        }
    }

    // MARK: - 4. Trivial distortion → "none"

    func testTrivialDistortionDominantAxisIsNone() {
        let d = distortion()  // all zero
        XCTAssertFalse(d.isNonTrivial)
        XCTAssertEqual(d.dominantAxisName, "none")
    }

    // MARK: - 5. Anomaly trace Codable round-trip

    func testAnomalyTraceCodableRoundTrip() throws {
        let trace = BASAnomalyTrace(
            traceID: "t-1",
            anomalyTypes: [.forcedClosure, .falseUrgency],
            pressureVector: nil,
            relationShift: "observer→subject inversion",
            sourceRefs: ["src-1", "src-2"],
            confidence: 0.66)
        let data = try JSONEncoder().encode(trace)
        let restored = try JSONDecoder().decode(
            BASAnomalyTrace.self, from: data)
        XCTAssertEqual(restored, trace)
    }

    // MARK: - 6. Abyssal branch Codable round-trip

    func testAbyssalBranchCodableRoundTrip() throws {
        let branch = BASAbyssalBranch(
            branchID: "b-1",
            sourceCandidateRef: "c-1",
            triggerReasons: ["high-unknown"],
            unknownLoad: 0.7,
            manipulationLoad: 0.4,
            ontologyDistortion: 0.3,
            protectivePathRefs: ["pp-1"],
            requiredClosureConditions: [
                "evidence-gathered",
                "sovereign-review-passed",
            ])
        let data = try JSONEncoder().encode(branch)
        let restored = try JSONDecoder().decode(
            BASAbyssalBranch.self, from: data)
        XCTAssertEqual(restored, branch)
        // Red line 7 pin: the branch carries closure conditions
        // but does NOT carry any "promote me" or "skip review"
        // flag. The pin here is simply that the schema's stored
        // shape stays declarative — every field listed in the
        // initialiser is the only thing the audit consumer can
        // read.
        XCTAssertEqual(restored.requiredClosureConditions.count, 2)
        XCTAssertTrue(
            restored.requiredClosureConditions.contains(
                "sovereign-review-passed"))
    }
}
