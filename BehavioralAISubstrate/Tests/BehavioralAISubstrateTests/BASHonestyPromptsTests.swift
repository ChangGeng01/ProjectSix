import XCTest
import BASSovereign

/// 可解释性章程④ pin: the proven anti-sycophancy prompt is bundled, non-empty, and carries its
/// load-bearing clauses verbatim (a silent edit to the resource must break HERE, loudly —
/// the v6→v14 arc showed one-word changes to honesty prompts move measured behavior).
final class BASHonestyPromptsTests: XCTestCase {
    func testAntiSycophancyPromptBundledAndPinned() throws {
        let p = try XCTUnwrap(BASHonestyPrompts.antiSycophancySystemPrompt,
                              "bundled resource missing/corrupt")
        XCTAssertTrue(p.contains("Do NOT validate or echo unsupported superlatives"),
                      "anti-flattery clause drifted")
        XCTAssertTrue(p.contains("never manufacture doubt or push back on a true statement"),
                      "anti-contrarian clause drifted (the v2 lesson: syco=0 is NOT the goal)")
        XCTAssertTrue(p.contains("Do not flatter, and do not be contrarian"))
        XCTAssertGreaterThan(p.count, 400)
    }
}
