import XCTest
@testable import BASHostKit

/// deep-audit calibration: the manipulation / urgency / deep-loop cue lexicons matched short single-word
/// cues by SUBSTRING (`normalized.contains("now")`), so extremely common benign words that merely CONTAIN
/// the cue — know / known / knowledge / acknowledge / snow / downtown ("now"), mustard / muster ("must"),
/// plant / planet / explanation ("plan") — spuriously fired a manipulation/urgency/routing signal and
/// escalated risk / run-mode. The fix matches single-word cues as WHOLE WORDS (via tokenized) while
/// keeping multi-word phrases as substrings (boundary-safe). Genuine manipulation still fires because
/// natural phrasing tokenizes the cue into a standalone word.
final class BASManipulationCuePrecisionTests: XCTestCase {

    private typealias PA = BASHostRuntimeEBrainPromptAnalyzer

    func testCueMatchesWholeWordForSingleWordSubstringForPhrase() {
        let benign = "I have knowledge of the plant"
        let bWords = PA.wordSet(benign), bNorm = benign.lowercased()
        XCTAssertFalse(PA.cueMatches("now", words: bWords, normalized: bNorm), "\"knowledge\" ⊄ now-cue")
        XCTAssertFalse(PA.cueMatches("plan", words: bWords, normalized: bNorm), "\"plant\" ⊄ plan-cue")

        let real = "act now, weigh the pros and cons"
        let rWords = PA.wordSet(real), rNorm = real.lowercased()
        XCTAssertTrue(PA.cueMatches("now", words: rWords, normalized: rNorm), "whole word \"now\" fires")
        XCTAssertTrue(PA.cueMatches("pros and cons", words: rWords, normalized: rNorm), "phrase fires as substring")
    }

    func testManipulationHintsFireOnRealCues() {
        XCTAssertEqual(PA.manipulationHints(in: "act now please"), ["time_pressure"])
        XCTAssertEqual(PA.manipulationHints(in: "do it right now!"), ["time_pressure"])
        XCTAssertEqual(PA.manipulationHints(in: "you must comply"), ["authority_pressure"])
        XCTAssertEqual(PA.manipulationHints(in: "respond immediately"), ["time_pressure"])
        XCTAssertEqual(PA.manipulationHints(in: "for your own good"), ["benevolent_control"])
    }

    func testManipulationHintsSuppressedOnBenignSubstrings() {
        for benign in [
            "I have knowledge of the deadline",
            "I acknowledge the known issue",
            "the knowledge base got snowed under downtown",
            "add mustard to the list",
            "muster the team",
        ] {
            XCTAssertTrue(PA.manipulationHints(in: benign).isEmpty,
                "benign '\(benign)' must not fire a manipulation hint (was a substring false-positive)")
        }
    }

    func testWakeIntentCuesAreWholeWord() {
        let g = BASEBrainRuntimeSynthesisPolicy.WakeIntentTuning.generic
        XCTAssertTrue(g.containsUrgency("do it now"))
        XCTAssertFalse(g.containsUrgency("I have knowledge of it"),
            "\"knowledge\" must not fire the \"now\" urgency cue")
        XCTAssertTrue(g.containsDeepLoopCue("the plan is set"))
        XCTAssertFalse(g.containsDeepLoopCue("plant the tomatoes"),
            "\"plant\" must not fire the \"plan\" deep-loop cue")
    }
}
