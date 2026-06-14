import XCTest
@testable import BASOrgan
@testable import BASMLXAdapter

/// Doctrine→mechanism pins for the Saguaro lane: `BASDecodeLanePolicy.saguaroEligible` (BASOrgan, doctrine) +
/// `MLXOrganAdapter.shouldUseSaguaro` (BASMLXAdapter, mechanism). Same envelope as prompt-lookup: default-OFF
/// (ADR-014), and the GREEDY-only invariant (byte-identity is the target's argmax, valid only at temp 0).
final class BASSaguaroPolicyTests: XCTestCase {

    private func req(_ preset: BASOrganPreset) -> BASOrganRequest {
        BASOrganRequest(requestID: "saguaro-policy", role: .core,
                        preset: preset, instruction: "x", context: [])
    }

    func testSaguaroEligible_greedyLanesOnly() {
        XCTAssertTrue(BASDecodeLanePolicy.saguaroEligible(for: .factual))
        XCTAssertTrue(BASDecodeLanePolicy.saguaroEligible(for: .deterministic))
        XCTAssertFalse(BASDecodeLanePolicy.saguaroEligible(for: .creative))
        XCTAssertFalse(BASDecodeLanePolicy.saguaroEligible(for: .scoutDefault))
    }

    func testShouldUseSaguaro_defaultOff() {
        XCTAssertFalse(MLXOrganAdapter.shouldUseSaguaro(
            elect: false, request: req(.greedyDeterministic)),
            "no election → fall back to the normal path, byte-equal (ADR-014)")
    }

    func testShouldUseSaguaro_electedAndGreedyOnly() {
        XCTAssertTrue(MLXOrganAdapter.shouldUseSaguaro(
            elect: true, request: req(.greedyDeterministic)),
            "elected + greedy (temp 0) is the only routed case")
        XCTAssertFalse(MLXOrganAdapter.shouldUseSaguaro(
            elect: true, request: req(.core)),
            "elected but temp>0 → must NOT route (argmax-accept would change bytes)")
        XCTAssertFalse(MLXOrganAdapter.shouldUseSaguaro(
            elect: true, request: req(.scout)),
            "elected but temp 0.1 → must NOT route (not byte-valid)")
    }

    func testEligibilityImpliesGreedy() {
        for preset in [BASOrganPreset.greedyDeterministic, .scout, .core] {
            let routed = MLXOrganAdapter.shouldUseSaguaro(elect: true, request: req(preset))
            XCTAssertEqual(routed, preset.temperature == 0,
                "\(preset.name): routing must equal (elected && temperature==0)")
        }
    }
}
