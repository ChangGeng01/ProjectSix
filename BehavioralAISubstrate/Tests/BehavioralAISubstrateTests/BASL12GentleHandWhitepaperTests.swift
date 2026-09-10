import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M117 — L12 `柔手层` whitepaper §5 closure tests.
///
/// L12 §5 lists 13 concept objects. Pre-M117 substrate had 1
/// (`BASProtectiveSubstitute` shared with L11) plus the existing
/// `BASMirrorMode` enum. All other 12 types + 2 new enums missing.
///
/// M117 adds:
/// - 3 enums: BASOutputSurfaceType (8-case), BASBoundaryScriptType
///   (6-case); reuses existing BASMirrorMode (3-case)
/// - 12 new structs: RenderFrame / OutputSurface / ToneWeaveProfile
///   / ForceCurve / MirrorResponse / BoundaryScript / ComparePanel
///   / StepBundle / DelayPacket / AgencyHandle / DisclosureProfile
///   / SilentStub
/// - Reuses BASProtectiveSubstitute from L11 (§5.10 shared concept)
///
/// Note: whitepaper §5 calls the tone-axis struct `ToneProfile`
/// but substrate uses `BASToneWeaveProfile` to avoid collision
/// with the existing `BASToneProfile` enum (categorical tone).
/// The "Weave" prefix matches L12 §4.2 "Tone Weave Loom".
final class BASL12GentleHandWhitepaperTests: XCTestCase {

    // MARK: - 1. New types schema presence

    func testAllTwelveNewL12TypesSchemaVersionOneDotZero() {
        XCTAssertEqual(
            BASRenderFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASOutputSurface.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASToneWeaveProfile.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASForceCurve.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASMirrorResponse.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASBoundaryScript.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASComparePanel.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASStepBundle.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASDelayPacket.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAgencyHandle.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASDisclosureProfile.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASSilentStub.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. Enum raw values

    func testOutputSurfaceTypeHasEightWhitepaperCases() {
        let expected: Set<String> = [
            "answer", "mirror", "comparePanel", "draftShell",
            "localStep", "boundaryScript", "delayPacket",
            "silentStub"
        ]
        XCTAssertEqual(
            Set(BASOutputSurfaceType.allCases.map(\.rawValue)),
            expected)
    }

    func testBoundaryScriptTypeHasSixWhitepaperCases() {
        let expected: Set<String> = [
            "block", "delay", "localOnly", "draftOnly",
            "noEscalation", "noTool"
        ]
        XCTAssertEqual(
            Set(BASBoundaryScriptType.allCases.map(\.rawValue)),
            expected)
    }

    func testReuseExistingMirrorModeThreeCases() {
        let expected: Set<String> = [
            "silent", "soft", "hard"
        ]
        XCTAssertEqual(
            Set(BASMirrorMode.allCases.map(\.rawValue)),
            expected)
    }

    // MARK: - 3. ToneWeaveProfile 8-axis clamping

    func testToneWeaveProfileClampsAllEightAxes() {
        let t = BASToneWeaveProfile(
            warmth: 1.5,
            firmness: -0.3,
            distance: 0.5,
            density: 1.2,
            pace: 0.7,
            explicitness: -0.1,
            authority: 0.9,
            tenderness: 2.0)
        XCTAssertEqual(t.warmth, 1.0)
        XCTAssertEqual(t.firmness, 0.0)
        XCTAssertEqual(t.distance, 0.5)
        XCTAssertEqual(t.density, 1.0)
        XCTAssertEqual(t.pace, 0.7)
        XCTAssertEqual(t.explicitness, 0.0)
        XCTAssertEqual(t.authority, 0.9)
        XCTAssertEqual(t.tenderness, 1.0)
    }

    // MARK: - 4. ForceCurve 3-force clamping

    func testForceCurveClampsThreeForceSegments() {
        let fc = BASForceCurve(
            openingForce: 1.2,
            middleForce: -0.1,
            closingForce: 0.5,
            boundaryAnchorStrength: 1.5)
        XCTAssertEqual(fc.openingForce, 1.0)
        XCTAssertEqual(fc.middleForce, 0.0)
        XCTAssertEqual(fc.closingForce, 0.5)
        XCTAssertEqual(fc.boundaryAnchorStrength, 1.0)
    }

    // MARK: - 5. RenderFrame aggregator

    func testRenderFrameAcceptsAllThirteenRefs() {
        let f = BASRenderFrame(
            frameID: "rf.1",
            mergedChoiceRef: "mc.1",
            actionPermitRef: "ap.1",
            agencyReservationRef: "ar.1",
            hostStyleRef: "hs.1",
            situationRef: "sf.1",
            mirrorRef: "mr.1",
            substituteRef: "ps.1",
            sovereignSurfaceRef: "ss.1",
            outputSurfaceRef: "os.1",
            toneProfileRef: "tp.1",
            forceCurveRef: "fc.1",
            disclosureProfileRef: "dp.1")
        XCTAssertEqual(f.frameID, "rf.1")
        XCTAssertEqual(f.mergedChoiceRef, "mc.1")
        XCTAssertEqual(f.disclosureProfileRef, "dp.1")
    }

    // MARK: - 6. MirrorResponse

    func testMirrorResponseBasicFields() {
        let r = BASMirrorResponse(
            responseID: "mr.1",
            mirrorMode: .hard,
            summary: "calibration reflection",
            calibrationPoints: ["p1", "p2"],
            emotionalLoad: 0.6,
            nonInductiveGuard: true)
        XCTAssertEqual(r.mirrorMode, .hard)
        XCTAssertEqual(r.calibrationPoints, ["p1", "p2"])
        XCTAssertEqual(r.emotionalLoad, 0.6)
        XCTAssertTrue(r.nonInductiveGuard)
    }

    // MARK: - 7. BoundaryScript

    func testBoundaryScriptDefaultsDignityGuardTrue() {
        let bs = BASBoundaryScript(
            scriptID: "bs.1",
            scriptType: .block)
        XCTAssertTrue(bs.dignityGuard)
        XCTAssertEqual(bs.firmnessLevel, 0.5)
    }

    // MARK: - 8. ComparePanel

    func testComparePanelDefaultsChooseLaterAllowed() {
        let p = BASComparePanel(panelID: "cp.1")
        XCTAssertTrue(p.chooseLaterAllowed)
    }

    // MARK: - 9. AgencyHandle

    func testAgencyHandleDefaultsHostSovereign() {
        let h = BASAgencyHandle(handleID: "ah.1")
        XCTAssertTrue(h.userFinalSay,
            "defaults preserve host sovereignty")
        XCTAssertTrue(h.chooseLaterAllowed)
    }

    // MARK: - 10. DisclosureProfile

    func testDisclosureProfileDefaultsHideChainOfThought() {
        let dp = BASDisclosureProfile(profileID: "dp.1")
        XCTAssertTrue(
            dp.chainOfThoughtHidden,
            "chain-of-thought hidden by default (sovereign redaction)")
    }

    // MARK: - 11. SilentStub

    func testSilentStubDefaultsDignityAndNoLeak() {
        let s = BASSilentStub(stubID: "ss.1")
        XCTAssertTrue(s.dignityGuard)
        XCTAssertTrue(s.noExtraLeak)
    }

    // MARK: - 12. Codable round-trip sample

    func testRenderFrameCodableRoundTrip() throws {
        let orig = BASRenderFrame(
            frameID: "rt",
            mergedChoiceRef: "mc.rt",
            outputSurfaceRef: "os.rt",
            toneProfileRef: "tp.rt")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASRenderFrame.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testToneWeaveProfileCodableRoundTrip() throws {
        let orig = BASToneWeaveProfile(
            warmth: 0.3, firmness: 0.7,
            distance: 0.4, density: 0.5,
            pace: 0.6, explicitness: 0.2,
            authority: 0.8, tenderness: 0.9)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASToneWeaveProfile.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 13. Registry membership

    func testAllTwelveNewL12TypesRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        let l12Names: Set<String> = [
            "RenderFrame", "OutputSurface",
            "ToneWeaveProfile", "ForceCurve",
            "MirrorResponse", "BoundaryScript",
            "ComparePanel", "StepBundle",
            "DelayPacket", "AgencyHandle",
            "DisclosureProfile", "SilentStub"
        ]
        let present = l12Names.intersection(ids)
        XCTAssertEqual(
            present.count, 12,
            "all 12 L12 §5 types registered")
    }
}
