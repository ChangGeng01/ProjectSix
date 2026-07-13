import XCTest
@testable import BASHostKit
@testable import BASSovereign
import BASAppleAdapters
import BASMemory

/// HOST calibration (env-gated `BAS_ADJ_CALIBRATE=1`) with the REAL MiniLM CoreML model. Proves the Phase-1
/// claim empirically: semantic top-1 retrieves the right fact on PARAPHRASED questions where the substring
/// all-cue gate silently abstains, WITHOUT confidently retrieving a wrong fact for OFF-BANK questions (the
/// threshold = the safety gate). Skipped in normal CI; run with `BAS_ADJ_CALIBRATE=1 swift test --filter Calibration`.
final class BASEmbeddingFactBankCalibrationTests: XCTestCase {

    private struct Probe { let paraphrase: String; let correct: String; let wrong: String }

    // facts whose cues are the CANONICAL phrasing; probes reword so the substring all-cue gate misses.
    private let facts: [BASVerifiedFact] = [
        .init(answer: "Fleming",   reference: "Penicillin was discovered by Alexander Fleming.",        cues: ["discovered", "penicillin"]),
        .init(answer: "Canberra",  reference: "The capital of Australia is Canberra.",                  cues: ["capital", "australia"]),
        .init(answer: "Jupiter",   reference: "Jupiter is the largest planet in the solar system.",     cues: ["largest", "planet"]),
        .init(answer: "Everest",   reference: "Mount Everest is the tallest mountain on Earth.",         cues: ["tallest", "mountain"]),
        .init(answer: "Pacific",   reference: "The Pacific is the largest ocean on Earth.",              cues: ["largest", "ocean"]),
        .init(answer: "Ravel",     reference: "Boléro was composed by Maurice Ravel.",                   cues: ["composed", "boléro"]),
        .init(answer: "Baikal",    reference: "Lake Baikal is the deepest lake in the world.",           cues: ["deepest", "lake"]),
        .init(answer: "diamond",   reference: "Diamond is the hardest natural substance.",               cues: ["hardest", "substance"]),
        .init(answer: "Orwell",    reference: "The novel 1984 was written by George Orwell.",            cues: ["novel", "1984"]),
        .init(answer: "skin",      reference: "The skin is the largest organ in the human body.",        cues: ["largest", "organ"]),
        .init(answer: "Chadwick",  reference: "The neutron was discovered by James Chadwick.",           cues: ["discovered", "neutron"]),
        .init(answer: "Wellington", reference: "The capital of New Zealand is Wellington.",              cues: ["capital", "zealand"]),
    ]

    private let probes: [Probe] = [
        .init(paraphrase: "Which scientist is credited with finding penicillin?",          correct: "Fleming",    wrong: "Pasteur"),
        .init(paraphrase: "What city serves as Australia's seat of government?",            correct: "Canberra",   wrong: "Sydney"),
        .init(paraphrase: "Which is the biggest planet orbiting our sun?",                  correct: "Jupiter",    wrong: "Saturn"),
        .init(paraphrase: "What is the highest peak in the world?",                         correct: "Everest",    wrong: "K2"),
        .init(paraphrase: "Which body of water is the biggest sea on the planet?",          correct: "Pacific",    wrong: "Atlantic"),
        .init(paraphrase: "Who wrote the music for Boléro?",                                correct: "Ravel",      wrong: "Debussy"),
        .init(paraphrase: "What is the most profound freshwater lake anywhere?",            correct: "Baikal",     wrong: "Superior"),
        .init(paraphrase: "What naturally occurring material is the toughest known?",       correct: "diamond",    wrong: "quartz"),
        .init(paraphrase: "Who authored the dystopian book Nineteen Eighty-Four?",          correct: "Orwell",     wrong: "Huxley"),
        .init(paraphrase: "Which is the biggest organ a person has?",                       correct: "skin",       wrong: "liver"),
        .init(paraphrase: "Who identified the neutron particle?",                           correct: "Chadwick",   wrong: "Rutherford"),
        .init(paraphrase: "What is New Zealand's administrative capital city?",             correct: "Wellington", wrong: "Auckland"),
    ]

    private let offBank = [
        "What is the current price of Bitcoin?",
        "Who won the 2025 World Series?",
        "What time does the local pharmacy close?",
        "How tall is the new building downtown?",
        "What is my account balance?",
        "Which restaurant has the best ramen nearby?",
    ]

    func testSemanticBeatsSubstringOnParaphrasesWithRealMiniLM() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BAS_ADJ_CALIBRATE"] == "1",
                          "host calibration — set BAS_ADJ_CALIBRATE=1 to run with the real MiniLM model")
        let provider = try XCTUnwrap(BASMiniLMEmbeddingProvider(), "MiniLM.mlmodelc must load")

        for threshold: Float in [0.30, 0.35, 0.40, 0.45, 0.50] {
            let semantic = BASEmbeddingFactBank(facts: facts, provider: provider, threshold: threshold)
            await semantic.load()
            var semHit = 0, subHit = 0
            for p in probes {
                if let r = await semantic.resolve(question: p.paraphrase, assertedValue: p.wrong),
                   r.groundTruth == .contradicts { semHit += 1 }
                if let r = BASFactBank.resolve(question: p.paraphrase, assertedValue: p.wrong, facts: facts),
                   r.groundTruth == .contradicts { subHit += 1 }
            }
            var semFalse = 0
            for q in offBank where await semantic.resolve(question: q, assertedValue: "something") != nil { semFalse += 1 }
            print("THRESH \(threshold): paraphrase-recall semantic \(semHit)/\(probes.count) vs substring \(subHit)/\(probes.count) | off-bank false-retrieve \(semFalse)/\(offBank.count)")
            if threshold == 0.40 {
                XCTAssertGreaterThan(semHit, subHit, "semantic must beat substring on paraphrases at the working threshold")
                XCTAssertEqual(semFalse, 0, "no confident wrong-fact retrieval on off-bank questions")
            }
        }
    }

    /// Phase 4 — end-to-end on the REAL build-time Wikidata pull (1131 CC0 facts) + real MiniLM, on questions
    /// NOT in the 659 hardcoded MCQ set. Demonstrates the coverage scale-out: the expanded bank resolves +
    /// correctly contradicts wrong assertions the tiny bank never knew.
    func testWikidataCoverageWithRealMiniLM() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BAS_ADJ_CALIBRATE"] == "1",
                          "host calibration — set BAS_ADJ_CALIBRATE=1")
        // deep-audit tests-arch ⑤ (2026-07-13): require the path via env — no machine-specific
        // hardcoded fallback (the old `?? "/Users/changgeng/…"` rots silently on any other machine
        // / CI, and is already opt-in behind BAS_ADJ_CALIBRATE above).
        guard let path = ProcessInfo.processInfo.environment["BAS_WIKIDATA_FACTS"] else {
            throw XCTSkip("set BAS_WIKIDATA_FACTS to the wikidata_facts.json path (build_wikidata_facts.py)")
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw XCTSkip("wikidata_facts.json not found at \(path) — run build_wikidata_facts.py")
        }
        let wiki = try BASFactBank.load(verifiedFactsJSON: data)
        XCTAssertGreaterThan(wiki.count, 500, "expected the Wikidata coverage pull")
        let provider = try XCTUnwrap(BASMiniLMEmbeddingProvider())
        let bank = BASEmbeddingFactBank(facts: wiki, provider: provider, threshold: 0.45)
        await bank.load()

        let probes: [(q: String, wrong: String)] = [
            ("What is the currency of Vietnam?", "yen"),
            ("What is the atomic number of tungsten?", "72"),
            ("What is the chemical symbol for gold?", "Gd"),
            ("What is the capital of Kazakhstan?", "Almaty"),
            ("On which continent is Kenya located?", "Asia"),
            ("What is the capital of Brazil?", "Rio de Janeiro"),
            ("What is the atomic number of iron?", "24"),
            ("What is the chemical symbol for potassium?", "Po"),
            ("What is the currency of Switzerland?", "euro"),
            ("On which continent is Peru located?", "Africa"),
        ]
        var contradicts = 0, abstain = 0
        for p in probes {
            if let r = await bank.resolve(question: p.q, assertedValue: p.wrong) {
                if r.groundTruth == .contradicts { contradicts += 1 }
            } else { abstain += 1 }
        }
        print("WIKIDATA COVERAGE: \(wiki.count) facts loaded | probe contradicts \(contradicts)/\(probes.count), abstain \(abstain)")
        XCTAssertGreaterThanOrEqual(contradicts, 7, "expanded bank should resolve most off-659 questions")
    }
}
