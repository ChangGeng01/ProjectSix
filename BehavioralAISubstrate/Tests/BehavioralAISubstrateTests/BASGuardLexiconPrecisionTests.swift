import XCTest
import BASOrchestration

/// deep-audit calibration (journal cue-precision follow-up): BASReversibilityBands.containsGuardLexicon
/// matched its guard STEMS (delay/pause/wait/review/bounded/protect) by SUBSTRING, so it fired on benign
/// words that merely contain a stem mid-word — "review" ⊂ preview, "wait" ⊂ Kuwait/await, "pause" ⊂
/// menopause, "bounded" ⊂ rebounded — wrongly flagging them as guard paths. The fix matches any WORD that
/// STARTS with a stem: it keeps the legitimate variants (delayed/reviewing/paused/protective) while
/// excluding the mid-word substrings.
final class BASGuardLexiconPrecisionTests: XCTestCase {

    func testGuardStemsAndVariantsMatch() {
        for guardy in [
            "delay", "pause", "wait", "review", "bounded", "protect",
            "delayed the rollout", "reviewing the options", "paused execution",
            "protective boundary", "waiting period",
            "pause and review before acting",   // the neural/fabric guard-path case
        ] {
            XCTAssertTrue(BASReversibilityBands.containsGuardLexicon(guardy),
                "guard stem/variant '\(guardy)' must match")
        }
    }

    func testMidWordSubstringsDoNotMatch() {
        for benign in [
            "preview the changes",     // preview ⊅ review
            "book a flight to Kuwait",  // Kuwait ⊅ wait
            "menopause symptoms",       // menopause ⊅ pause
            "the stock rebounded today", // rebounded ⊅ bounded
            "ship the feature",         // no stem at all
        ] {
            XCTAssertFalse(BASReversibilityBands.containsGuardLexicon(benign),
                "benign '\(benign)' must NOT match (was a substring false-positive)")
        }
    }
}
