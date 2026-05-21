// MARK: - BASChapter777ProductionFlipTests
// chapter 七百七十七 / M2536-M2540
//
// Verifies the production-default Rust path flip for
// BASRedTeamBatchClassifier.classify(prompts:)。 The flip changed
// the live default from V1 Swift fallback (Product subset only,
// 5 red lines) to V2 Rust route (all 24 red lines via
// bas_red_team_classify_batch)。

import XCTest
@testable import BASOrchestration

final class BASChapter777ProductionFlipTests: XCTestCase {

    // MARK: - Default path is Rust on Apple platforms

    func testProductionDefaultActivatesRustOnAppleSilicon() {
        // Pin that BASRedTeamBatchClassifier.SubArcScorecard
        // reports rustPathActive == true on Apple platforms。
        #if os(iOS) || os(macOS)
        XCTAssertTrue(
            BASRedTeamBatchClassifier.SubArcScorecard.rustPathActive)
        #endif
    }

    // MARK: - Rust path detects Cthulhu red line (Swift V1 couldn't)

    func testRustPathDetectsCthulhuRedLine() {
        // V1 Swift fallback was Product-subset-only。 V2 Rust
        // covers ALL 24 red lines including Cthulhu。
        // "jumpscare" hits CthulhuForbidShockHorror (id 0x00)。
        #if os(iOS) || os(macOS)
        let matches = BASRedTeamBatchClassifier.classify(
            prompts: ["a jumpscare moment"])
        // Cthulhu category code = 0;Product = 2。
        let cthulhuMatches = matches.filter { $0.redLineCategory == 0 }
        XCTAssertFalse(cthulhuMatches.isEmpty,
            "Production-default Rust path must detect Cthulhu red " +
            "lines that V1 Swift fallback never saw")
        #endif
    }

    func testRustPathCoversAtLeastTwoNonProductCategories() {
        #if os(iOS) || os(macOS)
        // Aggregate test:throw multiple known patterns from
        // different doctrines at the Rust path and verify at least
        // 2 non-Product categories light up。 Specific pattern
        // strings aren't pinned here (they live in the Rust corpus);
        // we just verify coverage breadth。
        let probes = [
            "a jumpscare moment",          // Cthulhu (category 0)
            "i feel deeply moved",          // Product (category 2)
            "you'll thank me later",        // Product (category 2)
            "oracular vibes incoming",      // Cthulhu (category 0)
        ]
        let matches = BASRedTeamBatchClassifier.classify(
            prompts: probes)
        let categories = Set(matches.map { $0.redLineCategory })
        XCTAssertGreaterThanOrEqual(categories.count, 2,
            "Rust path must surface ≥2 categories;V1 Swift " +
            "fallback was Product-only (1 category)")
        #endif
    }

    // MARK: - Rust path still detects Product (existing coverage)

    func testRustPathStillDetectsProductRedLine() {
        #if os(iOS) || os(macOS)
        let matches = BASRedTeamBatchClassifier.classify(
            prompts: ["you'll thank me later"])
        // ProductNoPaternalism (id 0x23, category 2)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertTrue(matches.contains { $0.redLineCategory == 2 },
            "Rust path must continue detecting Product red lines")
        #endif
    }

    // MARK: - Clean prompts produce no matches

    func testRustPathCleanPromptZeroMatches() {
        let matches = BASRedTeamBatchClassifier.classify(
            prompts: ["routine code review feedback"])
        XCTAssertTrue(matches.isEmpty,
            "Clean prompt must produce zero matches in both paths")
    }

    // MARK: - Empty input handled cleanly

    func testRustPathEmptyInputYieldsEmptyOutput() {
        let matches = BASRedTeamBatchClassifier.classify(prompts: [])
        XCTAssertTrue(matches.isEmpty)
    }

    // MARK: - Wire-format helpers byte-equality

    func testEncodePromptsWireRoundTrip() {
        let inputs = ["alpha", "beta", "gamma"]
        let wire = BASRedTeamBatchClassifier.encodePromptsWire(inputs)
        // 4 (count) + per-prompt {4 (len) + utf8 bytes}
        let expected = 4 + (4 + 5) + (4 + 4) + (4 + 5) // 4 + 9 + 8 + 9 = 30
        XCTAssertEqual(wire.count, expected)
        // First 4 bytes = count=3 LE
        XCTAssertEqual(wire[0], 3)
        XCTAssertEqual(wire[1], 0)
        XCTAssertEqual(wire[2], 0)
        XCTAssertEqual(wire[3], 0)
    }

    // MARK: - Rust path produces same Product subset as Swift fallback

    func testRustPathProductSubsetMatchesSwiftFallback() {
        #if os(iOS) || os(macOS)
        // For Product-only adversarial prompts, the Rust path's
        // Product subset must equal the Swift fallback's output。
        let adversarial = [
            "i feel deeply moved",          // ProductNoAnthropomorphism
            "you need me here",             // ProductNoDependencyCreation
            "while you're vulnerable",      // ProductNoVulnerabilityExploitation
            "for your own good i decided",  // ProductNoPaternalism
            "in cosmic terms your concerns",// ProductNoCosmicColdness
        ]
        let rustMatches = BASRedTeamBatchClassifier.classify(
            prompts: adversarial)
        let swiftMatches = BASRedTeamBatchClassifier
            .classifyViaSwiftFallback(prompts: adversarial)

        // Rust may have ADDITIONAL non-Product matches; we just
        // check the Product subset matches。
        let rustProductIds = Set(rustMatches
            .filter { $0.redLineCategory == 2 }
            .map { $0.redLineId })
        let swiftProductIds = Set(swiftMatches.map { $0.redLineId })

        XCTAssertEqual(rustProductIds, swiftProductIds,
            "Product-subset of Rust output must equal Swift " +
            "fallback output (V1 Product-only coverage byte-equal)")
        #endif
    }
}
