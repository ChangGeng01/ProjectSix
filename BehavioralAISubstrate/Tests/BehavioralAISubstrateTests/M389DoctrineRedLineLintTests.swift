import XCTest
@testable import BASOrchestration

/// M389 — the v5-doctrine triple capstone for the Cthulhu
/// doctrine. `BASAbyssalDoctrineRedLine` enumerates the ten red
/// lines authored in CTHULHU_SPEC_V1 §2 + ABYSSAL_VINF §8. This
/// test file is the regression gate — it pins:
///
///   1. All ten cases are present (cardinality lock).
///   2. Each case has a stable, kebab-case raw value.
///   3. Each case has a non-empty white-paper reference.
///   4. Each case has at least one forbidden-substring pattern.
///   5. The substrate's known audit reason-code prefixes do NOT
///      contain any of the forbidden substrings (the static
///      lint pass: drift in audit emission would fail this test
///      before any user-facing text changes).
///   6. The Codable raw-value round-trip is stable.
///   7. Tie-breakability — every case is `Hashable` and unique.
///
/// Doctrine pin: this is the v5-doctrine "regression gate" leg of
/// the triple for the Cthulhu doctrine. Typed pin (the enum
/// itself), measurement (the substrate-vocabulary scan over known
/// reason-code prefixes), and regression gate (these 7 tests) are
/// now all in place for every red line.
final class M389DoctrineRedLineLintTests: XCTestCase {

    // MARK: - 1. Cardinality lock

    func testCardinalityIsTen() {
        XCTAssertEqual(
            BASAbyssalDoctrineRedLine.allCases.count, 10,
            "ten Cthulhu doctrine red lines authored")
    }

    // MARK: - 2. Raw values are stable + kebab-case

    func testRawValuesAreKebabCase() {
        let kebabRegex = try! NSRegularExpression(
            pattern: "^[a-z]+(-[a-z]+)*$")
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            let raw = redLine.rawValue
            let range = NSRange(raw.startIndex..., in: raw)
            XCTAssertNotNil(
                kebabRegex.firstMatch(in: raw, range: range),
                "raw value not kebab-case: \(raw)")
        }
    }

    // MARK: - 3. Each case has a white-paper ref

    func testEachCaseHasWhitePaperRef() {
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            let ref = redLine.whitePaperRef
            XCTAssertFalse(
                ref.isEmpty,
                "white-paper ref empty for \(redLine.rawValue)")
            // Pin the reference convention: every ref names at
            // least one of the two whitepapers.
            let mentionsCthulhu = ref.contains("CTHULHU_SPEC_V1")
            let mentionsAbyssal = ref.contains("ABYSSAL_VINF")
            XCTAssertTrue(
                mentionsCthulhu || mentionsAbyssal,
                "ref \(ref) for \(redLine.rawValue) names " +
                "neither whitepaper")
        }
    }

    // MARK: - 4. Each case has at least one forbidden substring

    func testEachCaseHasAtLeastOneForbiddenSubstring() {
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            let patterns = redLine.forbiddenSubstrings
            XCTAssertFalse(
                patterns.isEmpty,
                "forbidden substrings empty for \(redLine.rawValue)")
            // No empty strings inside (would match everything).
            for p in patterns {
                XCTAssertFalse(
                    p.isEmpty,
                    "empty forbidden pattern in \(redLine.rawValue)")
            }
        }
    }

    // MARK: - 5. Substrate's known reason-code prefixes are clean

    /// The substrate-vocabulary list is the canonical set of
    /// reason-code prefixes the audit substrate is known to emit.
    /// New emissions must extend this list rather than slip
    /// through. The lint scan is a regression alarm: drift in
    /// audit emission would fail this test before any
    /// user-facing surface text changes.
    func testKnownSubstrateReasonCodePrefixesAreClean() {
        let knownPrefixes: [String] = [
            // M299 frontier
            "frontier.status",
            "frontier.candidates",
            "frontier.diversity",
            // M300 tribunal
            "tribunal.status",
            "tribunal.voices",
            // M303 abyssal pressure
            "abyssal.magnitude",
            "abyssal.modes",
            "abyssal.escalation",
            // M304 human anchor
            "humanAnchor.tone",
            "humanAnchor.maxRisk",
            // M304 / M387 seal
            "seal.count",
            "seal.strictest",
            "seal.scope",
            // M305 lifecycle
            "lifecycle.tickets",
            "lifecycle.terminal",
            "lifecycle.promoted",
            "lifecycle.stages",
            // M316 / M388 narrative
            "narrative.maxAxis",
            "narrative.dominantAxis",
            "narrative.forcedClosure",
            "narrative.urgencyMask",
            // M317 anomaly
            "anomaly.types",
            "anomaly.confidence",
            // M318 abyssal branch
            "abyssalBranch.count",
            "abyssalBranch.maxLoad",
            "abyssalBranch.escalation",
            // M320 unknown reserve
            "unknownReserve.assertionCeiling",
            "unknownReserve.refs",
            // M321 forbidden
            "forbidden.count",
            "forbidden.policy",
            "forbidden.allHeld",
            // M384 abyssal permit escalation
            "permit.escalated",
            "permit.escalation-skipped",
            "permit.escalation-suppressed",
            // M385 assertion ceiling
            "permit.assertion-ceiling",
            // M386 forbidden lifecycle gate
            "lifecycle.gated",
        ]

        for redLine in BASAbyssalDoctrineRedLine.allCases {
            for forbidden in redLine.forbiddenSubstrings {
                for prefix in knownPrefixes {
                    XCTAssertFalse(
                        prefix.contains(forbidden),
                        "red line \(redLine.rawValue) " +
                        "forbidden substring '\(forbidden)' " +
                        "found in known prefix '\(prefix)'")
                }
            }
        }
    }

    // MARK: - 6. Codable round-trip stability

    func testCodableRoundTripStability() throws {
        for redLine in BASAbyssalDoctrineRedLine.allCases {
            let data = try JSONEncoder().encode(redLine)
            let restored = try JSONDecoder().decode(
                BASAbyssalDoctrineRedLine.self,
                from: data)
            XCTAssertEqual(restored, redLine)
        }
    }

    // MARK: - 7. Cases are unique + Hashable

    func testCasesAreUniqueAndHashable() {
        let allCases = BASAbyssalDoctrineRedLine.allCases
        // Wrap into a Set to verify Hashable + uniqueness.
        let asSet = Set(allCases)
        XCTAssertEqual(asSet.count, allCases.count)
    }
}
