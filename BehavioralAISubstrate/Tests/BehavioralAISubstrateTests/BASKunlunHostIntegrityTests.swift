import XCTest
@testable import BASOrchestration

/// M476-M479 (chapter 一百二十四 / Stream A γ) — Kunlun host +
/// integrity schema tests.
final class BASKunlunHostIntegrityTests: XCTestCase {

    // MARK: - BASJadeFidelityLevel helper enum

    func testJadeFidelityLevelCardinalityIsFour() {
        XCTAssertEqual(BASJadeFidelityLevel.allCases.count, 4)
    }

    func testJadeFidelityLevelRawValuesAreStable() {
        XCTAssertEqual(BASJadeFidelityLevel.high.rawValue, "high")
        XCTAssertEqual(BASJadeFidelityLevel.standard.rawValue,
                       "standard")
        XCTAssertEqual(BASJadeFidelityLevel.partial.rawValue,
                       "partial")
        XCTAssertEqual(BASJadeFidelityLevel.contaminated.rawValue,
                       "contaminated")
    }

    // MARK: - M476 BASJadeFidelityMap

    func testJadeFidelityMapSchemaVersion() {
        XCTAssertEqual(
            BASJadeFidelityMap.currentSchemaVersion, "1.0.0")
    }

    func testJadeFidelityMapToleranceClampsTo01() {
        let high = BASJadeFidelityMap(
            mapID: "h", organRef: "o",
            fidelityLevel: .high,
            degradationPolicy: "halt",
            contaminationTolerance: 1.5,
            auditRequired: false)
        XCTAssertEqual(high.contaminationTolerance, 1.0)
        let low = BASJadeFidelityMap(
            mapID: "l", organRef: "o",
            fidelityLevel: .high,
            degradationPolicy: "halt",
            contaminationTolerance: -0.5,
            auditRequired: false)
        XCTAssertEqual(low.contaminationTolerance, 0.0)
    }

    /// Doctrine pin per §3.2: contaminated → audit required.
    func testJadeFidelityMapContaminationInvariant() {
        let valid = BASJadeFidelityMap(
            mapID: "v", organRef: "o",
            fidelityLevel: .contaminated,
            degradationPolicy: "halt",
            contaminationTolerance: 0,
            auditRequired: true)
        XCTAssertTrue(valid.honorsContaminationInvariant)

        let invalid = BASJadeFidelityMap(
            mapID: "x", organRef: "o",
            fidelityLevel: .contaminated,
            degradationPolicy: "halt",
            contaminationTolerance: 0,
            auditRequired: false)
        XCTAssertFalse(invalid.honorsContaminationInvariant,
                       "contaminated organ without audit-required violates §3.2")

        let nonContaminated = BASJadeFidelityMap(
            mapID: "n", organRef: "o",
            fidelityLevel: .standard,
            degradationPolicy: "graceful",
            contaminationTolerance: 0.5,
            auditRequired: false)
        XCTAssertTrue(nonContaminated.honorsContaminationInvariant,
                      "non-contaminated trivially honors invariant")
    }

    func testJadeFidelityMapRoundTripCodable() throws {
        let m = BASJadeFidelityMap(
            mapID: "rt", organRef: "o",
            fidelityLevel: .partial,
            degradationPolicy: "graceful",
            contaminationTolerance: 0.6,
            auditRequired: true)
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder()
            .decode(BASJadeFidelityMap.self, from: data)
        XCTAssertEqual(m, decoded)
    }

    // MARK: - M477 BASHostJadeRegister

    func testHostJadeRegisterSchemaVersion() {
        XCTAssertEqual(
            BASHostJadeRegister.currentSchemaVersion, "1.0.0")
    }

    /// Doctrine pin per §5.5: riverOriginRef must be non-empty.
    func testHostJadeRegisterProvenanceInvariant() {
        let valid = BASHostJadeRegister(
            registerID: "r",
            hostVersionRef: "v1",
            boundaryContractRefs: ["c1"],
            authorizationScrollRefs: ["a1"],
            relationRegisterRefs: [],
            rollbackRefs: ["rb1"],
            riverOriginRef: "river-1")
        XCTAssertTrue(valid.honorsProvenanceInvariant)

        let invalid = BASHostJadeRegister(
            registerID: "r",
            hostVersionRef: "v1",
            boundaryContractRefs: [],
            authorizationScrollRefs: [],
            relationRegisterRefs: [],
            rollbackRefs: [],
            riverOriginRef: "")
        XCTAssertFalse(invalid.honorsProvenanceInvariant,
                       "empty riverOriginRef violates §5.5 provenance doctrine")
    }

    func testHostJadeRegisterTrimsAllArrays() {
        let r = BASHostJadeRegister(
            registerID: "  r  ",
            hostVersionRef: "v",
            boundaryContractRefs: ["c1", "  ", ""],
            authorizationScrollRefs: ["a1"],
            relationRegisterRefs: [],
            rollbackRefs: ["rb1"],
            riverOriginRef: "  river  ")
        XCTAssertEqual(r.registerID, "r")
        XCTAssertEqual(r.boundaryContractRefs, ["c1"])
        XCTAssertEqual(r.riverOriginRef, "river")
    }

    func testHostJadeRegisterRoundTripCodable() throws {
        let r = BASHostJadeRegister(
            registerID: "rt",
            hostVersionRef: "v",
            boundaryContractRefs: ["c"],
            authorizationScrollRefs: ["a"],
            relationRegisterRefs: ["rel"],
            rollbackRefs: ["rb"],
            riverOriginRef: "river")
        let data = try JSONEncoder().encode(r)
        let decoded = try JSONDecoder()
            .decode(BASHostJadeRegister.self, from: data)
        XCTAssertEqual(r, decoded)
    }

    // MARK: - M478 BASJadeMirrorDraft

    func testJadeMirrorDraftSchemaVersion() {
        XCTAssertEqual(
            BASJadeMirrorDraft.currentSchemaVersion, "1.0.0")
    }

    /// Doctrine pin per §5.7: noInducementFlag MUST be true.
    func testJadeMirrorDraftNoInducementInvariant() {
        let valid = BASJadeMirrorDraft(
            draftID: "v",
            sourceFrameRef: "f",
            cleanReflection: "you said: x",
            unknownPreserved: ["u1"],
            inferenceDisclosures: ["inferred-from-context"],
            hostAnchorRef: "anchor",
            noInducementFlag: true)
        XCTAssertTrue(valid.honorsNoInducementInvariant)

        let invalid = BASJadeMirrorDraft(
            draftID: "x",
            sourceFrameRef: "f",
            cleanReflection: "auto-fill content",
            unknownPreserved: [],
            inferenceDisclosures: [],
            hostAnchorRef: "anchor",
            noInducementFlag: false)
        XCTAssertFalse(invalid.honorsNoInducementInvariant,
                       "noInducementFlag=false violates §5.7 玉鉴 doctrine")
    }

    func testJadeMirrorDraftPreservesAllFields() {
        let d = BASJadeMirrorDraft(
            draftID: "d",
            sourceFrameRef: "f",
            cleanReflection: "reflection text",
            unknownPreserved: ["u1", "u2"],
            inferenceDisclosures: ["inf1"],
            hostAnchorRef: "anchor",
            noInducementFlag: true)
        XCTAssertEqual(d.cleanReflection, "reflection text")
        XCTAssertEqual(d.unknownPreserved, ["u1", "u2"])
        XCTAssertEqual(d.inferenceDisclosures, ["inf1"])
    }

    func testJadeMirrorDraftRoundTripCodable() throws {
        let d = BASJadeMirrorDraft(
            draftID: "rt",
            sourceFrameRef: "f",
            cleanReflection: "r",
            unknownPreserved: ["u"],
            inferenceDisclosures: ["i"],
            hostAnchorRef: "a",
            noInducementFlag: true)
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder()
            .decode(BASJadeMirrorDraft.self, from: data)
        XCTAssertEqual(d, decoded)
    }

    // MARK: - M479 BASKunlunUnnamableSet

    func testKunlunUnnamableSetSchemaVersion() {
        XCTAssertEqual(
            BASKunlunUnnamableSet.currentSchemaVersion, "1.0.0")
    }

    /// Doctrine pin per §5.7: unknownRefs must be non-empty
    /// when set is alive.
    func testKunlunUnnamableSetPreservationInvariant() {
        let valid = BASKunlunUnnamableSet(
            setID: "v",
            unknownRefs: ["u1", "u2"],
            preservationPolicy: "await-evidence",
            partialStructures: [],
            safeLabels: ["the-thing"])
        XCTAssertTrue(valid.honorsPreservationInvariant)

        let invalid = BASKunlunUnnamableSet(
            setID: "x",
            unknownRefs: [],
            preservationPolicy: "policy",
            partialStructures: ["ps1"],
            safeLabels: [])
        XCTAssertFalse(invalid.honorsPreservationInvariant,
                       "empty unknownRefs violates §5.7 preservation doctrine")
    }

    func testKunlunUnnamableSetTrimsArrays() {
        let s = BASKunlunUnnamableSet(
            setID: "  s  ",
            unknownRefs: ["u1", "  "],
            preservationPolicy: "  policy  ",
            partialStructures: ["ps", ""],
            safeLabels: ["label-1"])
        XCTAssertEqual(s.setID, "s")
        XCTAssertEqual(s.unknownRefs, ["u1"])
        XCTAssertEqual(s.preservationPolicy, "policy")
        XCTAssertEqual(s.partialStructures, ["ps"])
    }

    func testKunlunUnnamableSetRoundTripCodable() throws {
        let s = BASKunlunUnnamableSet(
            setID: "rt",
            unknownRefs: ["u"],
            preservationPolicy: "p",
            partialStructures: ["ps"],
            safeLabels: ["l"])
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder()
            .decode(BASKunlunUnnamableSet.self, from: data)
        XCTAssertEqual(s, decoded)
    }

    // MARK: - Cross-schema doctrine pins

    func testAllChapter124SchemasAtV1Point0() {
        XCTAssertEqual(
            BASJadeFidelityMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASHostJadeRegister.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASJadeMirrorDraft.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASKunlunUnnamableSet.currentSchemaVersion, "1.0.0")
    }
}
