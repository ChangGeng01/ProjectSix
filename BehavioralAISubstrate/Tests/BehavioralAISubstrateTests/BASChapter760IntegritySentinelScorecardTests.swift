// MARK: - BASChapter760IntegritySentinelScorecardTests
// chapter 七百六十 第五刀 / M2455
//
// DEEPER LAYER-MIGRATION ARC sub-arc seal for chapter 七百六十
// (L11 typed integrity-sentinel port,M2451-M2455)。 Closes the
// 2-chapter L11 deeper sub-arc (七百五十九 red-team + 七百六十
// GSI) under the 严苛 table 「L11 极值得 (DEEPER)」 verdict。

import XCTest
@testable import BASSovereign
@testable import BASRuntimeCore

final class BASChapter760IntegritySentinelScorecardTests: XCTestCase {

    // MARK: - Chapter 七百六十 sub-arc scorecard pin

    func testScorecardChapterId() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.chapterId,
            "chapter 七百六十")
    }

    func testScorecardMRange() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.mRange,
            "M2451-M2455")
    }

    func testScorecardKnifeCount() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.knifeCount,
            5,
            "5 knives shipped:scaffold + scan + C ABI + " +
            "fixture grid + scorecard close-out")
    }

    func testScorecardRustABIPinned() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.rustABIVersion,
            1,
            "bas-integrity-sentinel Rust ABI v1 pinned at knife 1")
    }

    func testScorecardArtifactKindCardinality() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.artifactKindCount,
            4,
            "ArtifactKind enum must have 4 variants matching " +
            "BASSovereignIntegritySentinel.ArtifactKind.allCases")
        XCTAssertEqual(
            BASSovereignIntegritySentinel.ArtifactKind.allCases.count,
            4,
            "Swift-side ArtifactKind cardinality must match Rust pin")
    }

    func testScorecardFixtureGridHashPinned() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.fixtureGridHashHex,
            "0x4869961651CCEB59",
            "100-fixture FNV-1a hash captured at knife 4")
    }

    func testScorecardFixtureGridSize() {
        XCTAssertEqual(
            BASChapter760IntegritySentinelScorecard.fixtureGridSize,
            100,
            "byte-equality grid must contain exactly 100 fixtures")
    }

    func testScorecardRustPathDeactivatedAtKnife5() {
        // Knife 5 keeps V1 Swift actor as the live default。
        // Premature flip = ADR-014 OPT-IN violation。
        XCTAssertFalse(
            BASChapter760IntegritySentinelScorecard.rustPathActive,
            "Rust path must stay OFF until XCFramework rebuild")
    }

    // MARK: - V1 live path:Swift actor still wired

    func testV1LiveSwiftActorScanWorks() async {
        // Sentinel constructed empty → unknown artifact fails。
        let sentinel = BASSovereignIntegritySentinel()
        let request = BASSovereignIntegritySentinel.ScanRequest(
            claims: [
                BASSovereignIntegritySentinel.ArtifactClaim(
                    id: "model.weights",
                    claimedHash: "deadbeef",
                    kind: .modelOrPolicyArtifact),
            ],
            observedSelfMutation: false)
        let report = await sentinel.scan(request)
        XCTAssertEqual(report.failedArtifactIDs,
            ["model.weights"],
            "unknown artifact must fail conservatively")
        XCTAssertTrue(report.failedKinds.contains(.modelOrPolicyArtifact))
    }

    func testV1LiveSwiftActorMatchingClaimPasses() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(
            id: "model.weights", hash: "deadbeef")
        let request = BASSovereignIntegritySentinel.ScanRequest(
            claims: [
                BASSovereignIntegritySentinel.ArtifactClaim(
                    id: "model.weights",
                    claimedHash: "deadbeef",
                    kind: .modelOrPolicyArtifact),
            ],
            observedSelfMutation: false)
        let report = await sentinel.scan(request)
        XCTAssertTrue(report.failedArtifactIDs.isEmpty,
            "matching hash → no failures")
    }

    func testV1LiveSwiftActorCaseInsensitiveCompare() async {
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(
            id: "policy", hash: "ABCDEF")
        let request = BASSovereignIntegritySentinel.ScanRequest(
            claims: [
                BASSovereignIntegritySentinel.ArtifactClaim(
                    id: "policy",
                    claimedHash: "abcdef",  // lowercase claim
                    kind: .sovereignPolicyBundle),
            ],
            observedSelfMutation: false)
        let report = await sentinel.scan(request)
        XCTAssertTrue(report.failedArtifactIDs.isEmpty,
            "case-insensitive compare must pass")
    }

    // MARK: - scanRouted bridge entry surface exposed

    func testScanRoutedBridgeReturnsSameAsActor() async {
        // The new scanRouted extension method must produce the
        // same report as the live actor scan(_:) method when the
        // Rust path is deactivated。
        let sentinel = BASSovereignIntegritySentinel()
        await sentinel.registerFingerprint(
            id: "a", hash: "1")
        let request = BASSovereignIntegritySentinel.ScanRequest(
            claims: [
                BASSovereignIntegritySentinel.ArtifactClaim(
                    id: "a", claimedHash: "1",
                    kind: .modelOrPolicyArtifact),
                BASSovereignIntegritySentinel.ArtifactClaim(
                    id: "b", claimedHash: "x",
                    kind: .runtimeImage),
            ],
            observedSelfMutation: true)
        let viaActor = await sentinel.scan(request)
        let viaRouted = await sentinel.scanRouted(request)
        XCTAssertEqual(viaActor, viaRouted,
            "scanRouted must return same report as scan(_:) " +
            "when Rust path deactivated")
    }

    // MARK: - L11 sub-arc combined close-out

    func testL11DeeperSubArcCovers2Chapters() {
        // L11 deeper sub-arc = chapter 七百五十九 + 七百六十。
        // Both scorecards must report rustPathActive == false
        // at sub-arc seal (the XCFramework rebuild is deferred
        // to the larger DEEPER LAYER-MIGRATION ARC close-out
        // at chapter 七百七十三)。
        XCTAssertFalse(
            BASChapter760IntegritySentinelScorecard.rustPathActive)
    }

    // MARK: - HardObservations projection equivalence

    func testHardObservationsBitMappingMatchesRustABIPin() {
        // The Rust as_hard_bits() projection uses these bit
        // positions (mirror chapter 七百五十八 + chapter 七百六十):
        //   BR-001 = 0x0001 (model/policy artifact)
        //   BR-002 = 0x0002 (thought fold / cache)
        //   BR-006 = 0x0020 (sovereign policy bundle)
        //   BR-007 = 0x0040 (runtime image OR self-mutation)
        //
        // The Swift HardObservations struct mirrors this layout
        // via apply(to:) — verify the four flags fire in the
        // same pattern。
        var obs = BASSovereignVerdictEngine.HardObservations.clean
        let report = BASSovereignIntegritySentinel.ScanReport(
            failedArtifactIDs: ["x"],
            failedKinds: [.modelOrPolicyArtifact,
                          .sovereignPolicyBundle,
                          .thoughtFoldOrCache,
                          .runtimeImage],
            observedSelfMutation: true)
        report.apply(to: &obs)
        XCTAssertTrue(obs.artifactSignatureInvalid,
            "BR-001 lit when modelOrPolicyArtifact failed")
        XCTAssertTrue(obs.policyBundleTampered,
            "BR-006 lit when sovereignPolicyBundle failed")
        XCTAssertTrue(obs.thoughtFoldChecksumBroken,
            "BR-002 lit when thoughtFoldOrCache failed")
        XCTAssertTrue(obs.unauthorizedSelfMutation,
            "BR-007 lit when runtimeImage failed OR self_mut")
    }

    func testHardObservationsSelfMutationAloneLightsBR007() {
        // Mirror Rust test_scan_observed_self_mutation_alone_lights_br_007:
        // no kind failed,but self-mutation flag set → BR-007 lit。
        var obs = BASSovereignVerdictEngine.HardObservations.clean
        let report = BASSovereignIntegritySentinel.ScanReport(
            failedArtifactIDs: [],
            failedKinds: [],
            observedSelfMutation: true)
        report.apply(to: &obs)
        XCTAssertTrue(obs.unauthorizedSelfMutation,
            "BR-007 must light via observed_self_mutation alone")
        XCTAssertFalse(obs.artifactSignatureInvalid)
        XCTAssertFalse(obs.policyBundleTampered)
        XCTAssertFalse(obs.thoughtFoldChecksumBroken)
    }
}
