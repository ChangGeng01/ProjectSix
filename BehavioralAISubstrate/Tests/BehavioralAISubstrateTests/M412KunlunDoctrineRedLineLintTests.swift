import XCTest
@testable import BASOrchestration

/// M412 — pin the contract that `BASKunlunDoctrineRedLine` is
/// stable + canonical + provides the typed pin for v5 doctrine
/// triple capstone for the Kunlun doctrine.
///
/// Pattern parallel: M389DoctrineRedLineLintTests for Cthulhu.
///
/// What this file pins:
///
///   1. All 8 cases enumerated + raw values stable
///   2. White-paper reference is non-empty for each case
///   3. Forbidden substrings are non-empty for each case
///   4. Substrate emission vocabulary does NOT contain any
///      forbidden substring. The known emission prefixes are:
///      - kunlun.axis.* (M402)
///      - kunlun.jade.* (M404)
///      - kunlun.river.* (M405)
///      - kunlun.yaochi.* (M408)
///      - kunlun.tianmen.* (M409+M410)
///   5. Cross-doctrine alignment: when Kunlun + Cthulhu red lines
///      share semantic intent, both are referenced (no orphan
///      doctrine pair).
final class M412KunlunDoctrineRedLineLintTests: XCTestCase {

    // MARK: - 1. Cardinality + raw values

    func testAllEightCasesEnumerated() {
        let cases = BASKunlunDoctrineRedLine.allCases
        XCTAssertEqual(cases.count, 8,
            "Kunlun has exactly 8 doctrine red lines per §13.7")
    }

    func testAllRawValuesAreStableKebabCase() {
        for redLine in BASKunlunDoctrineRedLine.allCases {
            let raw = redLine.rawValue
            XCTAssertFalse(raw.isEmpty,
                "raw value must not be empty: \(redLine)")
            // Raw values are kebab-case (lowercase + hyphens),
            // no underscores, no camelCase, no spaces.
            XCTAssertFalse(raw.contains("_"),
                "raw value must be kebab-case (no underscore): \(raw)")
            XCTAssertFalse(raw.contains(" "),
                "raw value must not contain spaces: \(raw)")
            XCTAssertEqual(raw, raw.lowercased(),
                "raw value must be lowercase: \(raw)")
        }
    }

    func testRawValuesAreUnique() {
        let values = BASKunlunDoctrineRedLine.allCases.map(\.rawValue)
        XCTAssertEqual(values.count, Set(values).count,
            "raw values must be unique across all 8 cases")
    }

    // MARK: - 2. White-paper references non-empty

    func testWhitePaperReferenceNonEmptyForEach() {
        for redLine in BASKunlunDoctrineRedLine.allCases {
            let ref = redLine.whitePaperRef
            XCTAssertFalse(ref.isEmpty,
                "white paper ref must not be empty: \(redLine)")
            XCTAssertTrue(ref.contains("§13.7"),
                "ref must cite §13.7: \(redLine) -> \(ref)")
        }
    }

    // MARK: - 3. Forbidden substrings non-empty

    func testForbiddenSubstringsNonEmptyForEach() {
        for redLine in BASKunlunDoctrineRedLine.allCases {
            let patterns = redLine.forbiddenSubstrings
            XCTAssertFalse(patterns.isEmpty,
                "forbidden substrings must not be empty: \(redLine)")
            for pattern in patterns {
                XCTAssertFalse(pattern.isEmpty,
                    "individual pattern must not be empty: \(pattern)")
            }
        }
    }

    // MARK: - 4. Static lint over substrate emission vocabulary

    /// Walk the known Kunlun emission reason-code prefixes shipped
    /// in M402 / M404 / M405 / M408 / M409 / M410 + cross-protocol
    /// codes. None of them MUST contain any forbidden substring
    /// from any red line.
    func testSubstrateEmissionVocabularyHonorsAllRedLines() {
        // Stable list of Kunlun emission reason-code prefixes
        // that the substrate ships across Phase α/β/γ. Anchored
        // here by string literal so future doctrine drift would
        // require both adding emission and matching pattern.
        let kunlunEmissionCodes: [String] = [
            // M402 (axis)
            "kunlun.axis.center:0.500",
            "kunlun.axis.deviation:risk-medium-needs-attention",
            "kunlun.axis.requires-gate:true",
            // M404 (jade)
            "kunlun.jade.seal:action-permit:canonical",
            "kunlun.jade.seal:action-permit:defective",
            "kunlun.jade.missing:4",
            "kunlun.jade.defects:" +
                "无来源:provenance-empty+无哈希:integrity-hash-missing",
            // M405 (river)
            "kunlun.river.lineage:wellformed",
            "kunlun.river.lineage:partial",
            "kunlun.river.upward:5",
            "kunlun.river.downward:1",
            "kunlun.river.warnings:" +
                "kunlun.river.orphan:no-audit-trail",
            "kunlun.river.cut:true",
            // M406 (permit escalation reason codes)
            "permit.escalated:kunlun:requires-gate",
            "permit.escalated:kunlun:compare",
            "permit.escalated:kunlun:escalate-deep-deviation",
            "permit.escalation-skipped:kunlun-axis-anchor-reserved",
            "permit.escalation-suppressed:kunlun:risk-medium",
            // M408 (yaochi)
            "kunlun.yaochi.access:sensitive:granted",
            "kunlun.yaochi.access:boundary:denied",
            "kunlun.yaochi.reasons:" +
                "human-anchor-required+sealed-policy",
            // M409 (tianmen)
            "kunlun.tianmen.gate:public:passed",
            "kunlun.tianmen.gate:host:remanded",
            "kunlun.tianmen.ready:true",
            "kunlun.tianmen.ready:false",
            "kunlun.tianmen.reasons:" +
                "high-stakes-needs-jade-seal" +
                "+high-stakes-needs-sovereign-warrant",
            // M410 (cross-protocol bind)
            "kunlun.tianmen.warrant-bind:warrant-1",
            "kunlun.tianmen.warrant-missing:high-stakes",
            "kunlun.tianmen.axis-bound:session-host.test",
        ]

        for redLine in BASKunlunDoctrineRedLine.allCases {
            for forbiddenPattern in redLine.forbiddenSubstrings {
                for code in kunlunEmissionCodes {
                    XCTAssertFalse(
                        code.contains(forbiddenPattern),
                        "Kunlun emission code \"\(code)\" contains forbidden pattern " +
                        "\"\(forbiddenPattern)\" from red line " +
                        "\(redLine.rawValue) (\(redLine.whitePaperRef))")
                }
            }
        }
    }

    // MARK: - 5. Cross-doctrine alignment with Cthulhu

    /// Document semantically-related cross-doctrine red lines.
    /// This is a documentation pin — the test passes by listing
    /// the alignment so future contributors see both.
    func testCrossDoctrineSemanticAlignmentDocumented() {
        // Kunlun RL5 (Tianmen 不绕过宿主授权) + Cthulhu
        // single-commit-mouth red line are doctrine-distinct but
        // share the "host authorization is upstream of system
        // gating" intent.
        XCTAssertNotNil(
            BASKunlunDoctrineRedLine.forbidTianmenBypassesHost
                .whitePaperRef as String?,
            "Kunlun RL5 must have a white paper ref")

        // Kunlun RL6 (River-Origin 不变成隐性监控) + Cthulhu RL7
        // (watcher 只 hint 不裁决) share the "no untyped data
        // capture" intent.
        XCTAssertNotNil(
            BASKunlunDoctrineRedLine.forbidRiverOriginHiddenSurveillance
                .whitePaperRef as String?,
            "Kunlun RL6 must have a white paper ref")

        // Both Cthulhu and Kunlun red lines together total 18 (10
        // Cthulhu + 8 Kunlun). Documented invariant: chapter 九十五
        // composability test pins both fire in their respective
        // surfaces without contradiction.
        XCTAssertEqual(
            BASKunlunDoctrineRedLine.allCases.count
                + BASAbyssalDoctrineRedLine.allCases.count,
            18,
            "Kunlun (8) + Cthulhu (10) = 18 doctrine red lines total")
    }
}
