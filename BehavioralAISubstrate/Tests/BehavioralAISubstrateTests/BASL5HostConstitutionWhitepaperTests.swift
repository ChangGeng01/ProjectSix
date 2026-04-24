import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

/// M110 — L5 `宿纹层` whitepaper §6 closure tests.
///
/// L5 audit finds substrate structural parity already at very high
/// completeness — plan §0.1 labeled L5 as "80% most mature", and
/// 13/13 §6 concept objects have corresponding Swift structs.
/// M110 closes the remaining field-level drift:
///
/// 1. `BASHostConstitution.activeVersionID` (whitepaper §6)
///    alias → stored `activeVersion` (substrate name)
/// 2. `BASHostVersion.parentVersionID` — missing field added
///    (Optional, backward-compat)
/// 3. `BASHostVersion.signature` — missing field added
///    (Optional, backward-compat)
final class BASL5HostConstitutionWhitepaperTests: XCTestCase {

    // MARK: - 1. activeVersionID alias

    func testActiveVersionIDReadsActiveVersion() {
        let c = BASHostConstitution(
            hostID: "test.host",
            activeVersion: "host.v42")
        XCTAssertEqual(
            c.activeVersionID, "host.v42",
            "alias forwards whitepaper-literal activeVersionID " +
                "to stored activeVersion")
    }

    func testActiveVersionIDSetterForwardsToActiveVersion() {
        var c = BASHostConstitution(
            hostID: "test.host",
            activeVersion: "host.initial")
        c.activeVersionID = "host.upgraded.v2"
        XCTAssertEqual(
            c.activeVersion, "host.upgraded.v2",
            "setter forwards to stored field")
        XCTAssertEqual(
            c.activeVersionID, "host.upgraded.v2",
            "alias read reflects write")
    }

    // MARK: - 2. BASHostVersion new fields

    func testHostVersionDefaultsParentVersionIDAndSignatureNil() {
        // Pre-M110 call sites using positional init without the
        // new fields must keep working — defaults apply.
        let v = BASHostVersion(
            versionID: "v.1",
            changedFields: ["goals"],
            reason: "initial",
            approvedByPolicy: true)
        XCTAssertNil(v.parentVersionID,
            "default parentVersionID is nil (backward-compat)")
        XCTAssertNil(v.signature,
            "default signature is nil (backward-compat)")
    }

    func testHostVersionWithNewFieldsPopulated() {
        let v = BASHostVersion(
            versionID: "v.2",
            changedFields: ["boundaries"],
            reason: "added-crisis-line",
            rollbackRef: "v.1",
            approvedByPolicy: true,
            parentVersionID: "v.1",
            signature: "sha256:abc")
        XCTAssertEqual(v.parentVersionID, "v.1")
        XCTAssertEqual(v.signature, "sha256:abc")
    }

    func testHostVersionTrimsNewFieldStringsOnInit() {
        let v = BASHostVersion(
            versionID: "v.3",
            changedFields: [],
            reason: "test",
            approvedByPolicy: false,
            parentVersionID: "  v.0  ",
            signature: "\n sig \t")
        XCTAssertEqual(v.parentVersionID, "v.0")
        XCTAssertEqual(v.signature, "sig")
    }

    // MARK: - 3. Backward-compat legacy Codable fixture

    func testLegacyHostVersionJSONDecodesWithNilNewFields()
        throws {
        // Pre-M110 JSON payload with no parentVersionID / signature
        // must still decode, with both fields defaulting to nil.
        let legacyJSON = """
        {
            "schemaVersion": "1.0.0",
            "versionID": "v.legacy",
            "createdAt": 1700000000,
            "changedFields": ["values"],
            "reason": "legacy-payload",
            "approvedByPolicy": true
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            BASHostVersion.self, from: legacyJSON)
        XCTAssertEqual(decoded.versionID, "v.legacy")
        XCTAssertNil(decoded.parentVersionID,
            "legacy fixture: parentVersionID = nil")
        XCTAssertNil(decoded.signature,
            "legacy fixture: signature = nil")
    }

    func testNewHostVersionCodableRoundTrip() throws {
        let orig = BASHostVersion(
            versionID: "v.rt",
            createdAt: Date(timeIntervalSince1970: 1800000000),
            changedFields: ["style"],
            reason: "rt-test",
            rollbackRef: "v.rt-prev",
            approvedByPolicy: true,
            parentVersionID: "v.rt-prev",
            signature: "ed25519:payload")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(orig)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(
            BASHostVersion.self, from: data)
        XCTAssertEqual(decoded.parentVersionID, "v.rt-prev")
        XCTAssertEqual(decoded.signature, "ed25519:payload")
    }

    // MARK: - 4. L5 §6 all 13 concept objects exist

    func testAllThirteenL5ConceptObjectsExist() {
        // Compile-time presence via schemaVersion access.
        XCTAssertEqual(
            BASHostConstitution.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASIdentityLattice.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASValueAxisSet.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASGoalSpine.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASBoundaryVeil.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRelationGravityMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASRhythmCanopy.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASStyleGenome.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASConsentLattice.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASNarrativeLoom.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASProtectionRing.currentSchemaVersion, "1.0.0")
        XCTAssertTrue(
            BASHostChangeCandidate.currentSchemaVersion
                .hasPrefix("1."))
        XCTAssertEqual(
            BASHostVersionTree.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASForgetRequest.currentSchemaVersion, "1.0.0")
    }
}
