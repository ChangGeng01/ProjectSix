import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M111 — L6 `临在眼` whitepaper §5 closure tests.
///
/// L6 audit: §5 lists 10 key objects. Pre-M111 substrate had 8
/// matching structs (RoleGeometry / PowerGradient / EmotionalWeather
/// / UrgencyTruth / ConsequenceHorizon / ManipulationTrace /
/// HostResonance / ContinuityAnchor) plus `BASContextRouteHint`
/// semantically matching `RouteHint` (name drift). The 2 gaps:
///
/// 1. `SituationField` (§5 aggregator with 15 whitepaper fields)
///    — missing struct
/// 2. `RouteHint` — name drift (BASContextRouteHint exists)
///
/// Plus 1 field-level gap: `RoleGeometry.edges[]` (whitepaper §5
/// lists edges; substrate had `relationClass: String` summary
/// only).
///
/// M111 closes all three:
/// - Adds `BASSituationField` (15 whitepaper-literal fields,
///   auto-clamped numerics, auto-trimmed strings)
/// - Adds `typealias BASRouteHint = BASContextRouteHint`
/// - Adds `BASRoleGeometry.edges: [String]` with custom decoder
///   for pre-M111 backward-compat
final class BASL6PresenceEyeWhitepaperTests: XCTestCase {

    // MARK: - 1. BASSituationField existence + field round-trip

    func testSituationFieldSchemaVersionStable() {
        XCTAssertEqual(
            BASSituationField.currentSchemaVersion, "1.0.0")
    }

    func testSituationFieldAllFieldsRoundTripThroughInit() {
        let sf = BASSituationField(
            sceneID: "s.1",
            utteranceRef: "u.1",
            channelType: "private_chat",
            sceneType: "informal_conversation",
            actorSet: ["alice", "bob"],
            roleGeometryRef: "rg.1",
            powerGradientRef: "pg.1",
            emotionalWeatherRef: "ew.1",
            urgencyTruthRef: "ut.1",
            consequenceHorizonRef: "ch.1",
            ambiguityBand: 0.3,
            manipulationTraceRef: "mt.1",
            hostResonanceRef: "hr.1",
            continuityAnchorRef: "ca.1",
            confidenceBand: 0.7)
        XCTAssertEqual(sf.sceneID, "s.1")
        XCTAssertEqual(sf.utteranceRef, "u.1")
        XCTAssertEqual(sf.channelType, "private_chat")
        XCTAssertEqual(sf.sceneType, "informal_conversation")
        XCTAssertEqual(sf.actorSet, ["alice", "bob"])
        XCTAssertEqual(sf.roleGeometryRef, "rg.1")
        XCTAssertEqual(sf.ambiguityBand, 0.3)
        XCTAssertEqual(sf.confidenceBand, 0.7)
    }

    func testSituationFieldClampsAmbiguityAndConfidence() {
        let sf = BASSituationField(
            sceneID: "s.clamp",
            channelType: "ch",
            sceneType: "st",
            ambiguityBand: 1.5,
            confidenceBand: -0.5)
        XCTAssertEqual(sf.ambiguityBand, 1.0)
        XCTAssertEqual(sf.confidenceBand, 0.0)
    }

    func testSituationFieldTrimsStringFields() {
        let sf = BASSituationField(
            sceneID: "  s.trim  ",
            utteranceRef: "  u.trim  ",
            channelType: " ch ",
            sceneType: " st ",
            roleGeometryRef: "  rg  ")
        XCTAssertEqual(sf.sceneID, "s.trim")
        XCTAssertEqual(sf.utteranceRef, "u.trim")
        XCTAssertEqual(sf.channelType, "ch")
        XCTAssertEqual(sf.sceneType, "st")
        XCTAssertEqual(sf.roleGeometryRef, "rg")
    }

    func testSituationFieldCodableRoundTrip() throws {
        let orig = BASSituationField(
            sceneID: "s.rt",
            channelType: "voice",
            sceneType: "crisis",
            actorSet: ["host"],
            ambiguityBand: 0.4,
            confidenceBand: 0.6)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASSituationField.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 2. BASRouteHint typealias

    func testRouteHintTypealiasResolvesToContextRouteHint() {
        // Compile-time check: assigning a BASContextRouteHint to
        // a BASRouteHint variable must work (same type).
        let underlying = BASContextRouteHint(
            preferredMode: "scout",
            sovereignHintLevel: "low")
        let alias: BASRouteHint = underlying
        XCTAssertEqual(alias.preferredMode, "scout")
        XCTAssertEqual(alias.sovereignHintLevel, "low")
        XCTAssertTrue(
            BASRouteHint.self == BASContextRouteHint.self,
            "typealias resolves to same metatype")
    }

    // MARK: - 3. BASRoleGeometry.edges new field

    func testRoleGeometryDefaultsEdgesEmpty() {
        let rg = BASRoleGeometry(relationClass: "peer")
        XCTAssertEqual(rg.edges, [],
            "default edges is empty (backward-compat)")
    }

    func testRoleGeometryExplicitEdges() {
        let rg = BASRoleGeometry(
            actors: ["alice", "bob", "charlie"],
            roleTypes: ["peer", "peer", "manager"],
            relationClass: "mixed",
            asymmetryFlags: ["authority_alice_bob"],
            intimacyDistance: 0.7,
            edges: [
                "alice:peer:bob",
                "alice:report_to:charlie",
                "bob:report_to:charlie",
            ])
        XCTAssertEqual(rg.edges.count, 3)
        XCTAssertTrue(rg.edges.contains("alice:peer:bob"))
    }

    func testLegacyRoleGeometryJSONDecodesWithEmptyEdges()
        throws {
        // Pre-M111 JSON (no edges key) must decode with edges = [].
        let legacyJSON = """
        {
            "schemaVersion": "1.0.0",
            "actors": ["alice", "bob"],
            "roleTypes": ["peer", "peer"],
            "relationClass": "coworkers",
            "asymmetryFlags": [],
            "intimacyDistance": 0.5
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASRoleGeometry.self, from: legacyJSON)
        XCTAssertEqual(decoded.actors, ["alice", "bob"])
        XCTAssertEqual(decoded.edges, [],
            "legacy fixture: edges defaults to []")
    }

    func testRoleGeometryEdgesRoundTripPreservesOrder() throws {
        let orig = BASRoleGeometry(
            actors: ["a", "b"],
            relationClass: "close",
            edges: ["a:trusts:b", "b:mentors:a"])
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASRoleGeometry.self, from: data)
        XCTAssertEqual(
            decoded.edges,
            ["a:trusts:b", "b:mentors:a"],
            "edges order preserved")
    }

    // MARK: - 4. SituationField in governance registry

    func testSituationFieldRegisteredInGovernance() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(ids.contains("SituationField"))
    }
}
