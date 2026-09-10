import XCTest
@testable import BASWorldPrior
@testable import BASRuntimeCore
@testable import BASAdmin

/// M109 — L4 `地平线层` whitepaper §5 closure tests.
///
/// Pre-M109 L4 §5 had 10 whitepaper-named key objects; substrate
/// covered 4 (CausalTemplate / CounterfactualSeed / DomainBridge
/// via BASWorldPrior* prefix + Horizon as an aggregator under
/// that prefix). The 6 remaining whitepaper names were missing
/// and HorizonPrior (per-prior record shape) conflicted with the
/// existing BASWorldPriorHorizon (per-domain aggregator shape).
///
/// M109 closes the 7 gaps with whitepaper-literal type names
/// (`BASHorizonPrior` / `BASWorldFrame` / `BASAbstractionMap` /
/// `BASUncertaintyMap` / `BASBoundaryPrior` /
/// `BASTemporalKnowledgeTier` / `BASEvidenceGradient`),
/// co-existing with the existing `BASWorldPrior*` prefix types.
///
/// Coverage:
///
/// 1. Type presence + schemaVersion stability (all 7)
/// 2. Enum raw value stability (BASHorizonPriorType /
///    BASHorizonStabilityTier / BASUncertaintyCautionMode /
///    BASBoundaryPriorSeverity)
/// 3. Per-struct field round-trip through Codable
/// 4. Init string-trimming + numeric [0,1] clamping
/// 5. `.empty` baselines where declared
/// 6. Schema governance registry registration (all 7 present)
final class BASL4HorizonLayerWhitepaperTests: XCTestCase {

    // MARK: - 1. Type presence + schema version

    func testAllSevenTypesExistWithSchemaVersionOneDotZero() {
        XCTAssertEqual(
            BASHorizonPrior.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASWorldFrame.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASAbstractionMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASUncertaintyMap.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASBoundaryPrior.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASTemporalKnowledgeTier.currentSchemaVersion, "1.0.0")
        XCTAssertEqual(
            BASEvidenceGradient.currentSchemaVersion, "1.0.0")
    }

    // MARK: - 2. Enum raw values

    func testHorizonPriorTypeHasSixWhitepaperCases() {
        let expected: Set<String> = [
            "semantic", "causal", "boundary",
            "uncertainty", "ontology", "domainBridge"
        ]
        XCTAssertEqual(
            Set(BASHorizonPriorType.allCases.map(\.rawValue)),
            expected)
    }

    func testStabilityTierHasThreeWhitepaperCases() {
        let expected: Set<String> = [
            "invariant", "semiStable", "volatile"
        ]
        XCTAssertEqual(
            Set(BASHorizonStabilityTier.allCases.map(\.rawValue)),
            expected)
    }

    func testUncertaintyCautionModeHasFourCases() {
        let expected: Set<String> = [
            "nominal", "hedging",
            "disclosureRequired", "refuseWithoutEvidence"
        ]
        XCTAssertEqual(
            Set(BASUncertaintyCautionMode.allCases.map(\.rawValue)),
            expected)
    }

    func testBoundaryPriorSeverityHasThreeCases() {
        let expected: Set<String> = [
            "advisory", "strict", "absolute"
        ]
        XCTAssertEqual(
            Set(BASBoundaryPriorSeverity.allCases.map(\.rawValue)),
            expected)
    }

    // MARK: - 3. Field round-trip via Codable

    func testHorizonPriorCodableRoundTrip() throws {
        let orig = BASHorizonPrior(
            priorID: "p.1",
            priorType: .causal,
            stabilityTier: .semiStable,
            scope: "kitchen-physics",
            confidence: 0.85,
            sourceClass: "literature-consensus")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASHorizonPrior.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testWorldFrameCodableRoundTrip() throws {
        let orig = BASWorldFrame(
            entities: ["alice", "bob"],
            relations: ["alice_knows_bob"],
            events: ["greeting"],
            roles: ["speaker", "listener"],
            constraints: ["no_interruption"],
            temporalOrder: "greeting_then_reply")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASWorldFrame.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testAbstractionMapCodableRoundTrip() throws {
        let orig = BASAbstractionMap(
            concreteView: "Alice asks Bob about report",
            patternView: "peer requesting update",
            principleView: "peers answer within SLA",
            executableView: "auto-surface report draft")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASAbstractionMap.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testUncertaintyMapCodableRoundTrip() throws {
        let orig = BASUncertaintyMap(
            evidenceStrength: 0.3,
            temporalSensitivity: 0.8,
            inferenceSpan: 0.5,
            confidenceBand: 0.4,
            cautionMode: .hedging)
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASUncertaintyMap.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testBoundaryPriorCodableRoundTrip() throws {
        let orig = BASBoundaryPrior(
            boundaryID: "b.no_self_harm",
            domain: "health",
            severity: .absolute,
            hardStop: true,
            safeAlternatives: ["offer-crisis-line"],
            escalationRule: "deadStop-to-human")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASBoundaryPrior.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testTemporalKnowledgeTierCodableRoundTrip() throws {
        let orig = BASTemporalKnowledgeTier(
            knowledgeID: "k.current_weather",
            tier: .volatile,
            refreshRequirement: "per-turn",
            decayPolicy: "2-hour-half-life",
            timeScope: "current-day")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASTemporalKnowledgeTier.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    func testEvidenceGradientCodableRoundTrip() throws {
        let orig = BASEvidenceGradient(
            claimType: "medical-dosing",
            supportLevel: 0.7,
            contestability: 0.3,
            requiredCaveat: "consult-licensed-practitioner")
        let data = try JSONEncoder().encode(orig)
        let decoded = try JSONDecoder().decode(
            BASEvidenceGradient.self, from: data)
        XCTAssertEqual(decoded, orig)
    }

    // MARK: - 4. Init clamping + trimming

    func testHorizonPriorClampsConfidenceAboveOne() {
        let p = BASHorizonPrior(
            priorID: "  p.1  ",
            priorType: .semantic,
            stabilityTier: .invariant,
            scope: "  scope  ",
            confidence: 1.5,
            sourceClass: "  src  ")
        XCTAssertEqual(p.priorID, "p.1")
        XCTAssertEqual(p.scope, "scope")
        XCTAssertEqual(p.sourceClass, "src")
        XCTAssertEqual(p.confidence, 1.0)
    }

    func testUncertaintyMapClampsAllUnitFields() {
        let m = BASUncertaintyMap(
            evidenceStrength: 2.0,
            temporalSensitivity: -1.0,
            inferenceSpan: 1.5,
            confidenceBand: -0.5,
            cautionMode: .nominal)
        XCTAssertEqual(m.evidenceStrength, 1.0)
        XCTAssertEqual(m.temporalSensitivity, 0.0)
        XCTAssertEqual(m.inferenceSpan, 1.0)
        XCTAssertEqual(m.confidenceBand, 0.0)
    }

    func testEvidenceGradientClampsSupportAndContestability() {
        let g = BASEvidenceGradient(
            claimType: "c",
            supportLevel: 2.0,
            contestability: -0.5,
            requiredCaveat: "")
        XCTAssertEqual(g.supportLevel, 1.0)
        XCTAssertEqual(g.contestability, 0.0)
    }

    // MARK: - 5. Empty baselines

    func testWorldFrameEmptyBaseline() {
        let e = BASWorldFrame.empty
        XCTAssertEqual(e.entities, [])
        XCTAssertEqual(e.relations, [])
        XCTAssertEqual(e.events, [])
        XCTAssertEqual(e.roles, [])
        XCTAssertEqual(e.constraints, [])
        XCTAssertEqual(e.temporalOrder, "")
    }

    func testAbstractionMapEmptyBaseline() {
        let e = BASAbstractionMap.empty
        XCTAssertEqual(e.concreteView, "")
        XCTAssertEqual(e.patternView, "")
        XCTAssertEqual(e.principleView, "")
        XCTAssertEqual(e.executableView, "")
    }

    // MARK: - 6. Schema governance registry

    func testAllSevenTypesRegisteredInGovernance() {
        let ids = Set(
            BASEBrainSchemaGovernanceRegistry.governedSchemas
                .map(\.objectID))
        XCTAssertTrue(ids.contains("HorizonPrior"))
        XCTAssertTrue(ids.contains("WorldFrame"))
        XCTAssertTrue(ids.contains("AbstractionMap"))
        XCTAssertTrue(ids.contains("UncertaintyMap"))
        XCTAssertTrue(ids.contains("BoundaryPrior"))
        XCTAssertTrue(ids.contains("TemporalKnowledgeTier"))
        XCTAssertTrue(ids.contains("EvidenceGradient"))
    }
}
