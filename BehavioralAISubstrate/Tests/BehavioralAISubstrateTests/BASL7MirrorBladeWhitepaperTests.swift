import XCTest
@testable import BASOrchestration
@testable import BASRuntimeCore
@testable import BASAdmin

/// M112 — L7 `镜刃层` whitepaper §5 closure tests.
///
/// L7 §5 lists 14 documentation-only target objects in the
/// "parallel object family". Pre-M112 substrate had 9 matching
/// (BASFactShard / BASClaimShard / BASGoalSpineLocal /
/// BASPressureVector / BASManipulationPattern / BASBoundaryTouch
/// / BASMirrorDraft / BASCanonicalCognitiveFrame /
/// BASDecomposeFrame authoritative). 5 gaps:
///
/// 1. BASIntentVector — missing
/// 2. BASAffectLayer — missing
/// 3. BASUnknownSet — missing (BASUnknownRecord is per-item, not
///    the §5 5-list container)
/// 4. BASContradictionNode — name drift (BASContradictionRecord
///    exists with matching shape)
/// 5. BASCognitiveDissectionFrame — missing (§5.2 whitepaper
///    aggregator with 16 fields; BASDecomposeFrame is the
///    substrate-canonical runtime version)
///
/// M112 closes all 5.
final class BASL7MirrorBladeWhitepaperTests: XCTestCase {

    // MARK: - 1. New types schema versions

    func testAllNewL7TypesSchemaVersionOneDotZero() {
        XCTAssertEqual(
            BASIntentVector.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAffectLayer.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASUnknownSet.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASCognitiveDissectionFrame.currentSchemaVersion,
            "1.0.0")
    }

    // MARK: - 2. BASIntentVector

    func testIntentVectorBasicFields() {
        let iv = BASIntentVector(
            vectorID: "iv.1",
            explicitIntent: "send email",
            latentIntent: "avoid confrontation",
            steeringIntent: "make you volunteer",
            confidence: 0.7)
        XCTAssertEqual(iv.vectorID, "iv.1")
        XCTAssertEqual(iv.explicitIntent, "send email")
        XCTAssertEqual(iv.latentIntent, "avoid confrontation")
        XCTAssertEqual(iv.steeringIntent, "make you volunteer")
        XCTAssertEqual(iv.confidence, 0.7)
    }

    func testIntentVectorClampsConfidenceAndTrims() {
        let iv = BASIntentVector(
            vectorID: "  iv.2  ",
            explicitIntent: "  x  ",
            confidence: 1.5)
        XCTAssertEqual(iv.vectorID, "iv.2")
        XCTAssertEqual(iv.explicitIntent, "x")
        XCTAssertEqual(iv.confidence, 1.0)
    }

    func testIntentVectorCodableRoundTrip() throws {
        let orig = BASIntentVector(
            vectorID: "iv.rt",
            explicitIntent: "rt",
            confidence: 0.5)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASIntentVector.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 3. BASAffectLayer

    func testAffectLayerClampsAllUnitFields() {
        let a = BASAffectLayer(
            tone: "anxious",
            intensity: 1.5,
            volatility: -0.3,
            spilloverRisk: 0.9)
        XCTAssertEqual(a.intensity, 1.0)
        XCTAssertEqual(a.volatility, 0.0)
        XCTAssertEqual(a.spilloverRisk, 0.9)
    }

    func testAffectLayerCoupledGoalRefs() {
        let a = BASAffectLayer(
            tone: "resentful",
            intensity: 0.8,
            volatility: 0.5,
            spilloverRisk: 0.7,
            coupledGoalRefs: ["g.1", "g.2"])
        XCTAssertEqual(a.coupledGoalRefs, ["g.1", "g.2"])
    }

    func testAffectLayerCodableRoundTrip() throws {
        let orig = BASAffectLayer(
            tone: "rt",
            intensity: 0.4,
            volatility: 0.3,
            spilloverRisk: 0.2,
            coupledGoalRefs: ["a"])
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASAffectLayer.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 4. BASUnknownSet

    func testUnknownSetEmptyBaseline() {
        let u = BASUnknownSet.empty
        XCTAssertFalse(u.hasAny)
        XCTAssertEqual(u.missingFacts, [])
        XCTAssertEqual(u.ambiguityNotes, [])
    }

    func testUnknownSetHasAnyFiresWhenOneListNonEmpty() {
        let u = BASUnknownSet(
            missingFacts: ["when did Bob send the report?"])
        XCTAssertTrue(u.hasAny)
    }

    func testUnknownSetCodableRoundTrip() throws {
        let orig = BASUnknownSet(
            missingFacts: ["f1"],
            missingRoles: ["r1"],
            missingConstraints: ["c1"],
            unresolvedPermissions: ["p1"],
            ambiguityNotes: ["a1"])
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASUnknownSet.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 5. BASContradictionNode typealias

    func testContradictionNodeTypealiasResolvesToRecord() {
        let rec = BASContradictionRecord(
            nodeID: "cn.1",
            kind: .textual,
            summary: "A says X, A also says not X",
            severity: 0.8,
            unresolved: true)
        let node: BASContradictionNode = rec
        XCTAssertEqual(node.nodeID, "cn.1")
        XCTAssertTrue(
            BASContradictionNode.self
                == BASContradictionRecord.self,
            "typealias resolves to same metatype")
    }

    // MARK: - 6. BASCognitiveDissectionFrame

    func testCognitiveDissectionFrameBasicFields() {
        let f = BASCognitiveDissectionFrame(
            frameID: "cdf.1",
            situationRef: "sf.1",
            factShards: [],
            intentVectors: [],
            confidenceBand: 0.6)
        XCTAssertEqual(f.frameID, "cdf.1")
        XCTAssertEqual(f.situationRef, "sf.1")
        XCTAssertEqual(f.confidenceBand, 0.6)
        XCTAssertFalse(f.unknownSet.hasAny,
            "default unknownSet is empty")
    }

    func testCognitiveDissectionFrameAcceptsAllShardFamilies() {
        let fact = BASFactShard(
            shardID: "f.1",
            text: "test",
            status: .observed,
            sourceKind: .currentInput,
            certainty: 0.9)
        let claim = BASClaimShard(
            claimID: "c.1",
            text: "claim",
            claimType: .factClaim,
            supportLevel: 0.5,
            sourceKind: .currentInput,
            sourceRef: "ref.1")
        let iv = BASIntentVector(
            vectorID: "iv.1", confidence: 0.5)
        let al = BASAffectLayer(
            tone: "neutral",
            intensity: 0.3, volatility: 0.2,
            spilloverRisk: 0.1)

        let f = BASCognitiveDissectionFrame(
            frameID: "cdf.full",
            factShards: [fact],
            claimShards: [claim],
            intentVectors: [iv],
            affectLayers: [al])
        XCTAssertEqual(f.factShards.count, 1)
        XCTAssertEqual(f.claimShards.count, 1)
        XCTAssertEqual(f.intentVectors.count, 1)
        XCTAssertEqual(f.affectLayers.count, 1)
    }

    // MARK: - 7. Governance registry

    func testAllFourNewL7TypesRegistered() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(ids.contains("IntentVector"))
        XCTAssertTrue(ids.contains("AffectLayer"))
        XCTAssertTrue(ids.contains("UnknownSet"))
        XCTAssertTrue(ids.contains("CognitiveDissectionFrame"))
    }
}
