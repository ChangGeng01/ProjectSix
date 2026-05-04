import XCTest
import BASRuntimeCore

/// M515-M516 (chapter 一百三十) — pin BASLearnabilityClass typed
/// boundary per audit Point 7 doctrine. Ensures non-learnable
/// domains stay typed-pinned and audit-walker grep works on
/// stable raw values.
final class BASLearnabilityClassTests: XCTestCase {

    // MARK: - 1. Cardinality

    func testCardinality() {
        XCTAssertEqual(
            BASLearnabilityClass.allCases.count, 3,
            "exactly 3 learnability classes per audit Point 7")
    }

    // MARK: - 2. Stable raw values

    func testRawValuesStable() {
        let rawValues = Set(
            BASLearnabilityClass.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["strong-learnable", "semi-learnable",
             "non-learnable"],
            "stable kebab-case raw values for cross-module grep")
    }

    // MARK: - 3. Codable round-trip

    func testCodableRoundTrip() throws {
        for cls in BASLearnabilityClass.allCases {
            let encoded = try JSONEncoder().encode(cls)
            let decoded = try JSONDecoder().decode(
                BASLearnabilityClass.self, from: encoded)
            XCTAssertEqual(decoded, cls,
                "\(cls.rawValue) round-trips byte-equal")
        }
    }

    // MARK: - 4. WhitePaperRef populated for each case

    func testWhitePaperRefIsNonEmpty() {
        for cls in BASLearnabilityClass.allCases {
            XCTAssertFalse(
                cls.whitePaperRef.isEmpty,
                "\(cls.rawValue) MUST carry whitePaperRef")
            XCTAssertTrue(
                cls.whitePaperRef.contains("Audit Point 7")
                || cls.whitePaperRef.contains("Appendix P.4"),
                "whitePaperRef MUST anchor to audit Point 7 / Appendix P.4")
        }
    }

    // MARK: - 5. AuditCodePrefix stability

    func testAuditCodePrefixStable() {
        XCTAssertEqual(
            BASLearnabilityClass.strongLearnable
                .auditCodePrefix,
            "learnability:strong-learnable")
        XCTAssertEqual(
            BASLearnabilityClass.semiLearnable.auditCodePrefix,
            "learnability:semi-learnable")
        XCTAssertEqual(
            BASLearnabilityClass.nonLearnable.auditCodePrefix,
            "learnability:non-learnable")
    }

    // MARK: - 6. PolicyDescription populated

    func testPolicyDescriptionIsNonEmpty() {
        for cls in BASLearnabilityClass.allCases {
            XCTAssertFalse(
                cls.policyDescription.isEmpty,
                "\(cls.rawValue) MUST carry policyDescription")
        }
    }

    /// **BR-013 typed pin** — non-learnable policy MUST include
    /// the "BLOCKED from training pipelines" phrase. This is the
    /// load-bearing doctrine sentence that audit walkers grep
    /// for to verify L14 / sovereign / token / commit / permission
    /// schemas don't slip into training pipelines.
    func testNonLearnablePolicyBlocksTrainingPipeline() {
        let policy = BASLearnabilityClass.nonLearnable
            .policyDescription
        XCTAssertTrue(
            policy.contains("BLOCKED from training pipelines"),
            "BR-013: non-learnable policy MUST explicitly BLOCK training pipelines")
    }
}
