import XCTest
@testable import BASAdmin
import BASRuntimeCore

/// M516 (chapter 一百三十一) — pin BASSchemaGovernanceEntry's
/// learnabilityClass annotation per audit Point 7 + chapter 一百
/// 三十 Appendix P.4 doctrine. Verifies BR-013 typed pin: schemas
/// in load-bearing sovereign / token / commit / permission /
/// host-version domains MUST be `.nonLearnable`.
final class M516LearnabilityAnnotationTests: XCTestCase {

    // MARK: - 1. Default learnabilityClass is .semiLearnable

    func testDefaultLearnabilityIsSemiLearnable() {
        let entry = BASSchemaGovernanceEntry(
            objectID: "test",
            currentVersion: "1.0.0",
            compatibilityWindow: "2 minor versions",
            deprecationPolicy: "test",
            migrationTestIDs: [],
            rollbackPolicy: "test")
        XCTAssertEqual(
            entry.learnabilityClass, .semiLearnable,
            "default learnability MUST be .semiLearnable")
    }

    // MARK: - 2. BR-013 — non-learnable schemas pinned

    /// **BR-013 typed pin** — schemas in load-bearing sovereign /
    /// delete / token / commit / permission / host-version /
    /// host-jade-register / counter-host-check domains MUST be
    /// annotated as `.nonLearnable`. This test catches drift
    /// where future contributors add doctrine-load-bearing
    /// schemas without proper annotation.
    func testBR013NonLearnableSchemasPinned() {
        let mustBeNonLearnable: Set<String> = [
            "SovereignVerdict",
            "SovereignCommitToken",
            "SovereignWarrant",
            "QuarantineRecord",
            "SovereignAuditEntry",
            "HostVersion",
            "MemoryQuarantineRecord",
            "RuntimeTrace",
            "SealEnvelope",
            "ForbiddenKnowledgeCandidate",
            "JadeCanonSeal",
            "KunlunTianmenWarrant",
            "KunlunGateDenialWrit",
            "HostJadeRegister",
            "CounterHostCheck",
        ]
        for objectID in mustBeNonLearnable {
            let entry = BASEBrainSchemaGovernanceRegistry.entry(
                for: objectID)
            XCTAssertNotNil(entry,
                "doctrine-load-bearing schema \(objectID) MUST be in registry")
            XCTAssertEqual(
                entry?.learnabilityClass, .nonLearnable,
                "BR-013: schema \(objectID) MUST be .nonLearnable")
        }
    }

    // MARK: - 3. Codable backward-compat — v1 entries decode to .semiLearnable

    /// **Backward-compat pin** — v1 entries (without
    /// `learnabilityClass` field) MUST decode to
    /// `.semiLearnable` default. Same pattern as M463
    /// BASAbyssalPressure schema-bump.
    func testCodableV1EntryDecodesToSemiLearnable() throws {
        // Construct a v1-shape JSON without learnabilityClass.
        let v1Json = """
        {
          "objectID": "test-v1",
          "currentVersion": "1.0.0",
          "compatibilityWindow": "2 minor versions",
          "deprecationPolicy": "test",
          "migrationTestIDs": [],
          "rollbackPolicy": "test"
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(
            BASSchemaGovernanceEntry.self, from: v1Json)
        XCTAssertEqual(
            decoded.learnabilityClass, .semiLearnable,
            "v1 entry without learnabilityClass MUST decode to .semiLearnable")
    }

    // MARK: - 4. Codable round-trip with learnabilityClass

    func testCodableRoundTripWithLearnability() throws {
        let original = BASSchemaGovernanceEntry(
            objectID: "test",
            currentVersion: "1.0.0",
            compatibilityWindow: "2 minor versions",
            deprecationPolicy: "test",
            migrationTestIDs: [],
            rollbackPolicy: "test",
            learnabilityClass: .nonLearnable)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            BASSchemaGovernanceEntry.self, from: encoded)
        XCTAssertEqual(decoded, original,
            "BASSchemaGovernanceEntry round-trips with learnabilityClass")
        XCTAssertEqual(
            decoded.learnabilityClass, .nonLearnable,
            "non-learnable annotation preserved through round-trip")
    }
}
