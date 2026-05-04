import XCTest
import BASSovereign

/// M517 (chapter 一百三十) — pin BASSovereignDomainScope 6-case
/// typed boundary + linter per audit Point 5 doctrine. Ensures
/// L14 emissions stay within sovereign-domain bounds (BR-014
/// typed pin: L14 must be a nuclear button, not a master
/// control panel).
final class BASSovereignDomainScopeTests: XCTestCase {

    // MARK: - 1. Cardinality (6 sovereign domains)

    func testCardinality() {
        XCTAssertEqual(
            BASSovereignDomainScope.allCases.count, 6,
            "exactly 6 sovereign domains per audit Point 5 doctrine")
    }

    // MARK: - 2. Stable kebab-case raw values

    func testRawValuesStable() {
        let rawValues = Set(
            BASSovereignDomainScope.allCases.map(\.rawValue))
        XCTAssertEqual(
            rawValues,
            ["legitimacy", "delete-rollback",
             "privilege-escalation", "artifact-integrity",
             "lineage-pollution", "high-consequence-commit"],
            "stable kebab-case raw values for cross-module grep")
    }

    // MARK: - 3. Codable round-trip

    func testCodableRoundTrip() throws {
        for scope in BASSovereignDomainScope.allCases {
            let encoded = try JSONEncoder().encode(scope)
            let decoded = try JSONDecoder().decode(
                BASSovereignDomainScope.self, from: encoded)
            XCTAssertEqual(decoded, scope,
                "\(scope.rawValue) round-trips byte-equal")
        }
    }

    // MARK: - 4. WhitePaperRef + policyDescription populated

    func testWhitePaperRefAndPolicyPopulated() {
        for scope in BASSovereignDomainScope.allCases {
            XCTAssertFalse(
                scope.whitePaperRef.isEmpty,
                "\(scope.rawValue) MUST carry whitePaperRef")
            XCTAssertFalse(
                scope.policyDescription.isEmpty,
                "\(scope.rawValue) MUST carry policyDescription")
        }
    }

    // MARK: - 5. BR-014 lint — clean reason codes pass

    /// **BR-014 typed pin** — reason codes within 6 sovereign
    /// domains MUST be lint-clean (no power-creep substrings).
    func testCleanReasonCodesPassLint() {
        let cleanCodes = [
            "sovereign.verdict:rollback",
            "sovereign.warrant:high-consequence-commit",
            "sovereign.verdict:privilege-escalation",
            "sovereign.verdict:lineage-pollution",
            "sovereign.token:legitimacy",
            "sovereign.verdict:artifact-integrity",
        ]
        for code in cleanCodes {
            XCTAssertTrue(
                BASSovereignDomainScopeLinter
                    .isWithinSovereignScope(code),
                "clean code \(code) MUST be lint-clean")
            XCTAssertEqual(
                BASSovereignDomainScopeLinter.violations(
                    in: code), [],
                "clean code \(code) MUST have 0 violations")
        }
    }

    // MARK: - 6. BR-014 lint — power-creep reason codes flagged

    /// **BR-014 typed pin** — reason codes containing forbidden
    /// substrings (style-preference / product-experience /
    /// casual-risk / tool-routine / ux-polish / compare-mode-pick)
    /// indicate L14 power creep beyond 6 sovereign domains. Lint
    /// MUST flag them.
    func testPowerCreepReasonCodesFailLint() {
        let creepingCodes: [(String, String)] = [
            ("sovereign.verdict:style-preference",
             "style-preference"),
            ("sovereign.verdict:product-experience",
             "product-experience"),
            ("sovereign.verdict:casual-risk",
             "casual-risk"),
            ("sovereign.verdict:tool-routine",
             "tool-routine"),
            ("sovereign.verdict:ux-polish",
             "ux-polish"),
            ("sovereign.verdict:compare-mode-pick",
             "compare-mode-pick"),
        ]
        for (code, expectedViolation) in creepingCodes {
            XCTAssertFalse(
                BASSovereignDomainScopeLinter
                    .isWithinSovereignScope(code),
                "creeping code \(code) MUST fail lint (BR-014 power-creep detection)")
            XCTAssertTrue(
                BASSovereignDomainScopeLinter
                    .violations(in: code)
                    .contains(expectedViolation),
                "violations MUST flag \(expectedViolation)")
        }
    }
}
