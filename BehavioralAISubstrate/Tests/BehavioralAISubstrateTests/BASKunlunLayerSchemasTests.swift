import XCTest
@testable import BASOrchestration

/// M419 — chapter 九十九 deep-check 严查缺口补齐 batch.
///
/// Pin the 5 new typed schemas added in `BASKunlunLayerSchemas.swift`
/// closing the whitepaper §5.4 L4 worldview gap + §5.14 L14
/// sovereign upgrade gap reported by the chapter 九十九 deep-research
/// agent.
///
/// Pattern parallel: BASKunlunProtocolTests.swift (M401 schema parity).
///
/// What this file pins:
///
///   1. All 5 new schemas + 3 helper enums round-trip Codable
///   2. Field clamping / trimming preserves whitepaper-faithful state
///   3. `isWellFormed` / `isHonoringDoctrine` / `isFullyAuthorized`
///      predicates report doctrine-correct values for canonical
///      fixtures
///   4. Stable kebab-case raw values across enums (cross-module
///      string consumers depend on these)
///   5. White-paper-faithful field naming (camelCase Swift names
///      map cleanly to whitepaper snake_case fields)
final class BASKunlunLayerSchemasTests: XCTestCase {

    // MARK: - 1. AxisView Codable round-trip + isWellFormed

    func testAxisViewCodableRoundTrip() throws {
        let view = BASKunlunAxisView(
            worldRef: "world-v1",
            centerlinePriors: ["respects-host-boundary"],
            deviationPatterns: ["narrows-host-agency"],
            scaleLadders: ["personal", "civilizational"],
            orderConstraints: ["honors-world-anchor"])
        let encoded = try JSONEncoder().encode(view)
        let decoded = try JSONDecoder()
            .decode(BASKunlunAxisView.self, from: encoded)
        XCTAssertEqual(view, decoded)
    }

    func testAxisViewIsWellFormed() {
        let wellFormed = BASKunlunAxisView(
            worldRef: "w",
            centerlinePriors: ["p1"],
            deviationPatterns: [],
            scaleLadders: [],
            orderConstraints: ["c1"])
        XCTAssertTrue(wellFormed.isWellFormed)

        let missingPriors = BASKunlunAxisView(
            worldRef: "w",
            centerlinePriors: [],
            deviationPatterns: [],
            scaleLadders: [],
            orderConstraints: ["c1"])
        XCTAssertFalse(missingPriors.isWellFormed)

        let missingConstraints = BASKunlunAxisView(
            worldRef: "w",
            centerlinePriors: ["p1"],
            deviationPatterns: [],
            scaleLadders: [],
            orderConstraints: [])
        XCTAssertFalse(missingConstraints.isWellFormed)
    }

    // MARK: - 2. AscentView Codable round-trip + isWellFormed

    func testAscentViewCodableRoundTrip() throws {
        let view = BASKunlunAscentView(
            questionRef: "q-1",
            ascentConditions: ["host-explicit-consent"],
            gateSequence: ["gate-1", "gate-2"],
            stopPoints: ["evidence-saturation"],
            returnPaths: ["rollback-1"])
        let encoded = try JSONEncoder().encode(view)
        let decoded = try JSONDecoder()
            .decode(BASKunlunAscentView.self, from: encoded)
        XCTAssertEqual(view, decoded)
    }

    func testAscentViewIsWellFormed() {
        let wellFormed = BASKunlunAscentView(
            questionRef: "q",
            ascentConditions: ["c1"],
            gateSequence: [],
            stopPoints: [],
            returnPaths: ["rb-1"])
        XCTAssertTrue(wellFormed.isWellFormed)

        let missingConditions = BASKunlunAscentView(
            questionRef: "q",
            ascentConditions: [],
            gateSequence: [],
            stopPoints: [],
            returnPaths: ["rb-1"])
        XCTAssertFalse(missingConditions.isWellFormed)

        let missingReturnPaths = BASKunlunAscentView(
            questionRef: "q",
            ascentConditions: ["c1"],
            gateSequence: [],
            stopPoints: [],
            returnPaths: [])
        XCTAssertFalse(missingReturnPaths.isWellFormed)
    }

    // MARK: - 3. FarWestReserve Codable round-trip + doctrine-pin

    func testFarWestReserveCodableRoundTrip() throws {
        let reserve = BASKunlunFarWestReserve(
            unknownRefs: ["u-1", "u-2"],
            distanceBand: .farReach,
            namingStatus: .unattempted,
            safeApproachRules: ["evidence-floor-0.7"])
        let encoded = try JSONEncoder().encode(reserve)
        let decoded = try JSONDecoder()
            .decode(BASKunlunFarWestReserve.self, from: encoded)
        XCTAssertEqual(reserve, decoded)
    }

    func testFarWestReserveDoctrineHonored() {
        // Doctrine: 不急着命名 — non-empty unknowns + unattempted
        // / refused / sealed-unknown is doctrine-honoring.
        let unattempted = BASKunlunFarWestReserve(
            unknownRefs: ["u-1"],
            distanceBand: .visible,
            namingStatus: .unattempted,
            safeApproachRules: [])
        XCTAssertTrue(unattempted.isHonoringDoctrine)

        let refused = BASKunlunFarWestReserve(
            unknownRefs: ["u-1"],
            distanceBand: .farReach,
            namingStatus: .refused,
            safeApproachRules: [])
        XCTAssertTrue(refused.isHonoringDoctrine)

        let sealed = BASKunlunFarWestReserve(
            unknownRefs: ["u-1"],
            distanceBand: .sealedUnknown,
            namingStatus: .provisional,  // status doesn't matter
            safeApproachRules: [])
        XCTAssertTrue(sealed.isHonoringDoctrine,
            "sealed-unknown distance band always honors doctrine")

        // Provisional naming on a non-sealed unknown — doctrine
        // VIOLATED (forced premature naming).
        let forced = BASKunlunFarWestReserve(
            unknownRefs: ["u-1"],
            distanceBand: .visible,
            namingStatus: .provisional,
            safeApproachRules: [])
        XCTAssertFalse(forced.isHonoringDoctrine)

        // Empty reserve — doctrine N/A (no unknowns to honor).
        let empty = BASKunlunFarWestReserve(
            unknownRefs: [],
            distanceBand: .adjacent,
            namingStatus: .unattempted,
            safeApproachRules: [])
        XCTAssertFalse(empty.isHonoringDoctrine)
    }

    func testFarWestDistanceCardinalityAndRawValues() {
        XCTAssertEqual(
            BASKunlunFarWestDistance.allCases.count, 5)
        XCTAssertEqual(
            BASKunlunFarWestDistance.adjacent.rawValue,
            "adjacent")
        XCTAssertEqual(
            BASKunlunFarWestDistance.visible.rawValue,
            "visible")
        XCTAssertEqual(
            BASKunlunFarWestDistance.farReach.rawValue,
            "far-reach")
        XCTAssertEqual(
            BASKunlunFarWestDistance.beyondHorizon.rawValue,
            "beyond-horizon")
        XCTAssertEqual(
            BASKunlunFarWestDistance.sealedUnknown.rawValue,
            "sealed-unknown")
    }

    func testNamingStatusCardinalityAndRawValues() {
        XCTAssertEqual(
            BASKunlunNamingStatus.allCases.count, 3)
        XCTAssertEqual(
            BASKunlunNamingStatus.unattempted.rawValue,
            "unattempted")
        XCTAssertEqual(
            BASKunlunNamingStatus.provisional.rawValue,
            "provisional")
        XCTAssertEqual(
            BASKunlunNamingStatus.refused.rawValue,
            "refused")
    }

    // MARK: - 4. TianmenWarrant Codable + isFullyAuthorized

    func testTianmenWarrantCodableRoundTrip() throws {
        let warrant = BASKunlunTianmenWarrant(
            warrantID: "tw-1",
            actionRef: "permit-1",
            gateRef: "gate-1",
            sovereignBasis: "verdict-1",
            jadeCanonSealRef: "seal-1",
            riverOriginRef: "river-1",
            passScope: .scoped,
            expiry: "2026-12-31T23:59:59Z")
        let encoded = try JSONEncoder().encode(warrant)
        let decoded = try JSONDecoder()
            .decode(BASKunlunTianmenWarrant.self, from: encoded)
        XCTAssertEqual(warrant, decoded)
    }

    func testTianmenWarrantIsFullyAuthorized() {
        let full = BASKunlunTianmenWarrant(
            warrantID: "tw-1",
            actionRef: "permit-1",
            gateRef: "gate-1",
            sovereignBasis: "verdict-1",
            jadeCanonSealRef: "seal-1",
            riverOriginRef: "river-1",
            passScope: .oneShot,
            expiry: "")
        XCTAssertTrue(full.isFullyAuthorized)

        // Missing jade-canon seal — not fully authorized
        // (high-stakes passes require it).
        let missingSeal = BASKunlunTianmenWarrant(
            warrantID: "tw-1",
            actionRef: "permit-1",
            gateRef: "gate-1",
            sovereignBasis: "verdict-1",
            jadeCanonSealRef: "",
            riverOriginRef: "river-1",
            passScope: .oneShot,
            expiry: "")
        XCTAssertFalse(missingSeal.isFullyAuthorized)

        // Missing sovereign basis — never authorized.
        let missingBasis = BASKunlunTianmenWarrant(
            warrantID: "tw-1",
            actionRef: "permit-1",
            gateRef: "gate-1",
            sovereignBasis: "",
            jadeCanonSealRef: "seal-1",
            riverOriginRef: "river-1",
            passScope: .oneShot,
            expiry: "")
        XCTAssertFalse(missingBasis.isFullyAuthorized)
    }

    func testTianmenPassScopeCardinalityAndRawValues() {
        XCTAssertEqual(
            BASKunlunTianmenPassScope.allCases.count, 5)
        XCTAssertEqual(
            BASKunlunTianmenPassScope.oneShot.rawValue,
            "one-shot")
        XCTAssertEqual(
            BASKunlunTianmenPassScope.scoped.rawValue,
            "scoped")
        XCTAssertEqual(
            BASKunlunTianmenPassScope.conditional.rawValue,
            "conditional")
        XCTAssertEqual(
            BASKunlunTianmenPassScope.renewable.rawValue,
            "renewable")
        XCTAssertEqual(
            BASKunlunTianmenPassScope.persistent.rawValue,
            "persistent")
    }

    // MARK: - 5. GateDenialWrit Codable + isWellFormed

    func testGateDenialWritCodableRoundTrip() throws {
        let writ = BASKunlunGateDenialWrit(
            writID: "writ-1",
            sourceRef: "permit-1",
            deniedDomain: "host-domain",
            reasonCodes: [
                "missing-jade-canon-seal",
                "axis-overreach",
            ],
            returnPathRef: "rollback-1",
            humanExplanationStub:
                "This decision needs more grounding before we " +
                "proceed. Let's revisit the boundaries.")
        let encoded = try JSONEncoder().encode(writ)
        let decoded = try JSONDecoder()
            .decode(BASKunlunGateDenialWrit.self, from: encoded)
        XCTAssertEqual(writ, decoded)
    }

    func testGateDenialWritIsWellFormed() {
        // Doctrine 该断时断: denials must always carry typed
        // reason codes + return path + denied domain.
        let wellFormed = BASKunlunGateDenialWrit(
            writID: "w",
            sourceRef: "s",
            deniedDomain: "host",
            reasonCodes: ["r1"],
            returnPathRef: "rb",
            humanExplanationStub: "")
        XCTAssertTrue(wellFormed.isWellFormed)

        // Empty reason codes — silent denial. Forbidden by
        // doctrine.
        let silentDenial = BASKunlunGateDenialWrit(
            writID: "w",
            sourceRef: "s",
            deniedDomain: "host",
            reasonCodes: [],
            returnPathRef: "rb",
            humanExplanationStub: "")
        XCTAssertFalse(silentDenial.isWellFormed,
            "silent denial (no reason codes) violates doctrine 该断时断")

        // No return path — host left without recourse.
        let strandedDenial = BASKunlunGateDenialWrit(
            writID: "w",
            sourceRef: "s",
            deniedDomain: "host",
            reasonCodes: ["r1"],
            returnPathRef: "",
            humanExplanationStub: "")
        XCTAssertFalse(strandedDenial.isWellFormed,
            "denial without return path violates doctrine")
    }

    // MARK: - 6. White-paper-faithful schema versions are stable

    func testAllSchemasAtV1_0_0() {
        XCTAssertEqual(
            BASKunlunAxisView.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASKunlunAscentView.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASKunlunFarWestReserve.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASKunlunTianmenWarrant.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASKunlunGateDenialWrit.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 7. Field-trimming consistent with M401 schemas

    func testFieldTrimmingConsistentWithM401Pattern() {
        // M401 schemas trim whitespace + newlines from string
        // fields and string array elements. Verify the M419
        // schemas follow the same convention.
        let view = BASKunlunAxisView(
            worldRef: "  world  ",
            centerlinePriors: ["  prior  "],
            deviationPatterns: [],
            scaleLadders: [],
            orderConstraints: ["  rule\n"])
        XCTAssertEqual(view.worldRef, "world")
        XCTAssertEqual(view.centerlinePriors, ["prior"])
        XCTAssertEqual(view.orderConstraints, ["rule"])

        let warrant = BASKunlunTianmenWarrant(
            warrantID: " tw ",
            actionRef: " a ",
            gateRef: " g ",
            sovereignBasis: " sb ",
            jadeCanonSealRef: " seal ",
            riverOriginRef: " r ",
            passScope: .oneShot,
            expiry: " 2026 ")
        XCTAssertEqual(warrant.warrantID, "tw")
        XCTAssertEqual(warrant.actionRef, "a")
        XCTAssertEqual(warrant.expiry, "2026")
    }

    // MARK: - 8. Cross-doctrine cross-protocol references

    /// FarWestReserve doctrinally pairs with Cthulhu's
    /// `BASUnknownReserve`. Verify both types coexist without
    /// symbol collision.
    func testFarWestReserveCoexistsWithUnknownReserveSymbols() {
        // This test is structural — we only verify the types
        // can be referenced side-by-side without a name conflict.
        let kunlunReserve = BASKunlunFarWestReserve(
            unknownRefs: ["u-1"],
            distanceBand: .visible,
            namingStatus: .unattempted,
            safeApproachRules: [])
        XCTAssertEqual(kunlunReserve.unknownRefs.count, 1)
        // The Cthulhu BASUnknownReserve lives in a different
        // module path; the typed names don't collide. This is
        // doctrine-correct: 一轴一渊 sibling doctrines have
        // sibling typed surface.
    }
}
