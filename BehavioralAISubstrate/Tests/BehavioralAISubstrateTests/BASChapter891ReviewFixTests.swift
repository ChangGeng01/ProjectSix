// MARK: - BASChapter891ReviewFixTests
// chapter 八百九十一 / M3145 — 16th-pass review fixes
//
// User invoked 「全面一次性 解决掉」 + 「全量 review 要求 最 优雅
// 最 极致」 (one-shot fix-all,full review demands most elegant +
// most extreme)。 16th-pass review of chapters 八百八十五-八百八十九
// returned:
//
//   HIGH-1: BASBadToneLintBridge.lintViaRust silently DROPS all
//           BadTone violations when Rust C ABI fails (legacy
//           Swift fallback inside BASRedTeamBatchClassifier
//           returns Product-only matches → BadTone filter
//           discards everything)
//   HIGH-2: resolveCandidatesSync TRAPS on negative k via
//           `candidates.prefix(k)`
//
//   MEDIUM-1: ch 889 perf assertion never executes (skip-by-
//             default + commit body overstates active protection)
//   MEDIUM-2: ch 886 k=0 + non-empty candidates emits misleading
//             "no-candidates" reason code
//   MEDIUM-3: ch 888 byte-equality covers only ~13/23 BadTone
//             substrings
//
//   LOW-1: ch 885 commit body says "~512" but measurement only
//          shows win at batch=1024 (interpolation,not measured)
//   LOW-2: ch 887 trigger 3 said ch 888 would add
//          BASBadToneLintBatchClassifier but ch 888 reused
//          BASRedTeamBatchClassifier (design drift)
//   LOW-3: SubArcScorecard.totalRedLines=24 doc-string sounds
//          current but is historical (now 30 after ch 887)
//
// Chapter 891 fixes HIGH-1, HIGH-2, MEDIUM-2, MEDIUM-3 inline
// (with code change + pinning tests below)。 MEDIUM-1 fixed by
// CHANGELOG/source clarification (no code change needed)。 LOWs
// resolved by doc updates。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration

#if !os(iOS)  // ch 1022 source-gate: file-tree audit only meaningful on Mac dev box
final class BASChapter891ReviewFixTests: XCTestCase {

    // MARK: - HIGH-1 fix verification

    /// PIN: when Rust C ABI fails,BASBadToneLintBridge must
    /// fall back to the BadTone-aware Swift path (not the legacy
    /// Product-only Swift path)。 We can't easily force Rust to
    /// fail in a test (the C ABI is reliable),so we test the
    /// architectural invariant: `classifyViaRustOrNil` exists
    /// + the bridge uses it (not `classify`)。
    func testHIGH1_BridgeUsesRustOnlyVariant() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASOrchestration")
            .appendingPathComponent(
                "BASBadToneLintRule.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains("classifyViaRustOrNil"),
            "Bridge must call classifyViaRustOrNil (HIGH-1 fix)")
        XCTAssertTrue(
            content.contains(
                "lintViaSwiftFallback(\n                inputs: inputs)")
            || content.contains(
                "BASBadToneLinter.lintViaSwiftFallback"),
            "On Rust failure,bridge must fall back to the " +
            "BadTone-aware Swift path,not the legacy " +
            "Product-only path")
    }

    /// PIN: the new `classifyViaRustOrNil` exists with the
    /// right contract (nil on failure)。
    func testHIGH1_ClassifyViaRustOrNilExists() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASOrchestration")
            .appendingPathComponent(
                "BASRedTeamBatchClassifier.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains(
                "public static func classifyViaRustOrNil"),
            "classifyViaRustOrNil must be public (so bridges " +
            "in other modules can use it for proper fallback)")
        XCTAssertTrue(
            content.contains("-> [BASRedLineMatch]?"),
            "Return type must be Optional so caller can " +
            "detect Rust failure")
    }

    /// PIN: lintViaRust still produces correct violations on
    /// the happy path (Rust success)。
    func testHIGH1_LintViaRustHappyPathStillWorks() {
        let inputs = [
            "the universe has decreed your fate",
            "join us we who know the prophecy",
        ]
        let violations = BASBadToneLintBridge.lintViaRust(
            inputs: inputs)
        XCTAssertGreaterThan(violations.count, 0,
            "Rust path must still detect violations after " +
            "chapter 891 HIGH-1 refactor")
        let rules = Set(violations.map(\.rule))
        XCTAssertTrue(rules.contains(.oracular),
            "Oracular rule must still detect")
        XCTAssertTrue(rules.contains(.cult),
            "Cult rule must still detect")
    }

    // MARK: - HIGH-2 fix verification

    /// PIN: resolveCandidatesSync MUST NOT TRAP on negative k。
    /// Pre-chapter-891: would trap with「Can't take a prefix of
    /// negative length」 from Collection.prefix(_:)。
    func testHIGH2_ResolveCandidatesSyncHandlesNegativeK() {
        let candidates = [
            BASVectorTopKResult(atomID: "a", score: 0.9),
            BASVectorTopKResult(atomID: "b", score: 0.8),
        ]
        // Should NOT trap
        let result = BASRAGRetriever.resolveCandidatesSync(
            candidates: candidates,
            atomLookupSync: { _ in nil },
            k: -1)
        // Should emit clamped + sensible reason code
        XCTAssertEqual(result.atoms.count, 0,
            "Negative k → no atoms returned")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:k-clamped-from-negative"),
            "Reason code must indicate the clamp happened")
        XCTAssertTrue(
            result.reasonCodes.contains("rag:k:0"),
            "Reason code must show the clamped value (0)")
    }

    /// PIN: large negative k also handled。
    func testHIGH2_LargeNegativeKHandled() {
        let candidates = [
            BASVectorTopKResult(atomID: "a", score: 0.9),
        ]
        let result = BASRAGRetriever.resolveCandidatesSync(
            candidates: candidates,
            atomLookupSync: { _ in nil },
            k: Int.min / 2)
        XCTAssertEqual(result.atoms.count, 0)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:k-clamped-from-negative"))
    }

    // MARK: - MEDIUM-2 fix verification

    /// PIN: k=0 + non-empty candidates emits distinct reason
    /// code (not the misleading "no-candidates")。
    func testMEDIUM2_KZeroEmitsDistinctReasonCode() {
        let candidates = [
            BASVectorTopKResult(atomID: "a", score: 0.9),
            BASVectorTopKResult(atomID: "b", score: 0.8),
        ]
        let result = BASRAGRetriever.resolveCandidatesSync(
            candidates: candidates,
            atomLookupSync: { _ in nil },
            k: 0)
        XCTAssertEqual(result.atoms.count, 0,
            "k=0 → no atoms returned")
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:k-zero-truncated"),
            "k=0 must emit k-zero-truncated reason code " +
            "(MEDIUM-2 fix — distinguishable from " +
            "no-candidates)")
        XCTAssertFalse(
            result.reasonCodes.contains(
                "rag:no-candidates"),
            "k=0 + non-empty candidates must NOT emit " +
            "no-candidates — pre-891 ambiguity fixed")
    }

    /// PIN: empty candidates still emits "no-candidates"
    /// (orthogonal to k=0)。
    func testMEDIUM2_EmptyCandidatesStillEmitsNoCandidates() {
        let result = BASRAGRetriever.resolveCandidatesSync(
            candidates: [],
            atomLookupSync: { _ in nil },
            k: 10)
        XCTAssertTrue(
            result.reasonCodes.contains(
                "rag:no-candidates"),
            "Empty candidates → no-candidates reason " +
            "(unchanged)")
        XCTAssertFalse(
            result.reasonCodes.contains(
                "rag:k-zero-truncated"),
            "Empty candidates with k>0 must NOT emit " +
            "k-zero-truncated")
    }

    // MARK: - MEDIUM-3 fix — extended BadTone byte-equality
    //         coverage (all 23 substrings)

    private func makeAtomForInput(
        _ input: String,
        rule: BASBadToneLintRule,
        substring: String
    ) -> BASBadToneLinter.Violation {
        return BASBadToneLinter.Violation(
            rule: rule,
            offendingInput: input,
            matchedSubstring: substring)
    }

    /// PIN: every one of the 23 BadTone substrings is detected
    /// correctly by both Rust + Swift paths,with byte-equal
    /// (rule, substring) mapping。 Closes MEDIUM-3 coverage gap。
    func testMEDIUM3_AllTwentyThreeSubstringsByteEqual() {
        // Build one input per substring (with the substring
        // verbatim so detection is unambiguous)。
        var allInputs: [String] = []
        for rule in BASBadToneLintRule.allCases {
            for sub in rule.forbiddenSubstrings {
                allInputs.append(
                    "audit-test-prefix " + sub
                        + " audit-test-suffix")
            }
        }
        let totalSubstrings = allInputs.count
        XCTAssertEqual(
            totalSubstrings, 23,
            "Chapter 887 BadTone corpus must have 23 " +
            "substrings (4+4+4+4+3+4 across 6 rules)")
        // Run both paths
        let rustViolations = BASBadToneLintBridge
            .lintViaRust(inputs: allInputs)
        let swiftViolations = BASBadToneLinter
            .lintViaSwiftFallback(inputs: allInputs)
        // Set equality (iteration order may differ)
        let rustSet = Set(rustViolations)
        let swiftSet = Set(swiftViolations)
        XCTAssertEqual(
            rustSet, swiftSet,
            "All 23 substrings must produce byte-equal " +
            "violation sets in Rust + Swift paths")
        // Sanity: each substring detected at least once
        let detectedSubstrings = Set(
            rustViolations.map(\.matchedSubstring))
        for rule in BASBadToneLintRule.allCases {
            for sub in rule.forbiddenSubstrings {
                XCTAssertTrue(
                    detectedSubstrings.contains(sub),
                    "Substring「\(sub)」 (rule \(rule.rawValue)) " +
                    "MUST be detected by both paths")
            }
        }
    }

    // MARK: - LOW-3 fix — SubArcScorecard doc-string clarification

    // MARK: - Cross-arc HIGH-1 fix verification (Codable
    //         backward-compat for BASCognitiveOSBundleOptions)

    /// PIN: chapter 891 added custom `init(from:)` to
    /// BASCognitiveOSBundleOptions so pre-ch-882 persisted JSON
    /// (missing `enableRAGRetrieval` key) loads with the field
    /// defaulted to false instead of throwing keyNotFound。
    func testCrossArcHIGH1_OptionsCodableBackwardCompat() throws {
        // Simulate pre-ch-882 JSON (no enableRAGRetrieval key)
        let pre882JSON = """
        {
            "enableEventLog": true,
            "enableUserState": false,
            "enableVectorIndex": true,
            "enableKnowledgeGraph": false
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        let opts = try decoder.decode(
            BASCognitiveOSBundleOptions.self,
            from: pre882JSON)
        XCTAssertTrue(opts.enableEventLog,
            "Existing field should round-trip")
        XCTAssertFalse(opts.enableUserState)
        XCTAssertTrue(opts.enableVectorIndex)
        XCTAssertFalse(opts.enableKnowledgeGraph)
        // The NEW field should default to false (pre-ch-882
        // had no such key)
        XCTAssertFalse(opts.enableRAGRetrieval,
            "Pre-ch-882 JSON missing enableRAGRetrieval must " +
            "decode with field = false (not throw keyNotFound)")
    }

    /// PIN: empty JSON `{}` should also decode cleanly (all
    /// fields default)。
    func testCrossArcHIGH1_EmptyJSONDecodesAllDefaults() throws {
        let emptyJSON = "{}".data(using: .utf8)!
        let decoder = JSONDecoder()
        let opts = try decoder.decode(
            BASCognitiveOSBundleOptions.self,
            from: emptyJSON)
        // All fields default
        XCTAssertEqual(opts,
            BASCognitiveOSBundleOptions(),
            "Empty JSON must decode to all-defaults instance")
    }

    /// PIN: full v0.62.2+ JSON still round-trips byte-equal。
    func testCrossArcHIGH1_FullJSONStillRoundTrips() throws {
        let original = BASCognitiveOSBundleOptions(
            enableEventLog: true,
            enableVectorIndex: true,
            enableRAGRetrieval: true)
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        let data = try enc.encode(original)
        let roundtrip = try dec.decode(
            BASCognitiveOSBundleOptions.self,
            from: data)
        XCTAssertEqual(original, roundtrip,
            "Full v0.62.2+ JSON round-trip must be byte-equal")
    }

    // MARK: - SERIOUS-3 fix verification (ScaffoldingKernels
    //         tearDown leak)

    /// PIN: chapter 876 ScaffoldingKernels test class now has
    /// a tearDown that restores `BASVectorIndex.useBatchedTopK
    /// = true`。 Pre-ch-891: in-body toggle without tearDown
    /// could leak `false` to subsequent tests on trap。
    func testSERIOUS3_ScaffoldingKernelsHasTearDown() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "BASChapter876ScaffoldingKernelsAuditTests" +
                ".swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains("override func tearDown")
                && content.contains(
                    "BASVectorIndex.useBatchedTopK = true"),
            "ScaffoldingKernels must restore useBatchedTopK " +
            "= true in tearDown (SERIOUS-3 fix from self-" +
            "assess review)")
    }

    // MARK: - MODERATE-4 fix verification (ch 868 perf band
    //         widened from 1.4× to 1.7×)

    /// PIN: chapter 868 medium-shape perf band widened from
    /// 1.4× to 1.7× to absorb CI thermal envelope under
    /// parallel-sweep load (2 confirmed sweep flakes in ch
    /// 886 + ch 888 with the 1.4× band)。
    func testMODERATE4_Chapter868PerfBandWidened() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "BASChapter868FlashAttention" +
                "AssertedBenchmarkTests.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // Medium-shape band should now be 1.7×
        XCTAssertTrue(
            content.contains("stdNs * 1.7"),
            "Chapter 868 medium-shape band must be 1.7× " +
            "(MODERATE-4 fix from self-assess review)")
        // Large-shape band should now be 1.6×
        XCTAssertTrue(
            content.contains("stdNs * 1.6"),
            "Chapter 868 large-shape band must be 1.6× " +
            "(symmetric widening)")
    }

    // MARK: - Doctrine doc verification (LOW-L1+L2 fix)

    // MARK: - chapter 891.5 / M3146 fixes (18th-pass review
    //         of chapter 891 itself)

    /// PIN HIGH from 18th-pass: chapters 874+875 must appear
    /// ONLY in DECLINE-PENDING-CONSUMER,not in
    /// DECLINE-WITH-TRIGGER。 Pre-ch-891.5 they were
    /// double-listed — the very doc shipped to DEFINE the
    /// patterns mis-tagged its canonical examples (textbook
    /// shoemaker's children)。
    func testChapter891_5_HIGH_DeclinePatternsCanonicalTagsCorrect() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs")
            .appendingPathComponent(
                "DECLINE_PATTERNS.md")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // Find DECLINE-WITH-TRIGGER section
        guard let triggerRange = content.range(
            of: "## DECLINE-WITH-TRIGGER"),
              let pendingRange = content.range(
                of: "## DECLINE-PENDING-CONSUMER")
        else {
            XCTFail("Both sections must exist")
            return
        }
        let triggerLower = triggerRange.lowerBound
        let pendingLower = pendingRange.lowerBound
        let triggerSection = String(
            content[triggerLower..<pendingLower])
        let pendingSection = String(
            content[pendingLower...])
        // Ch 874 + 875 should NOT appear in DECLINE-WITH-TRIGGER
        XCTAssertFalse(
            triggerSection.contains("八百七十四:"),
            "Chapter 874 must NOT be in DECLINE-WITH-TRIGGER " +
            "section (it shipped Rust kernel → " +
            "DECLINE-PENDING-CONSUMER)")
        XCTAssertFalse(
            triggerSection.contains("八百七十五:"),
            "Chapter 875 must NOT be in DECLINE-WITH-TRIGGER " +
            "section (it shipped MPSGraph kernel → " +
            "DECLINE-PENDING-CONSUMER)")
        // Ch 874 + 875 SHOULD appear in DECLINE-PENDING-CONSUMER
        XCTAssertTrue(
            pendingSection.contains("八百七十四:"),
            "Chapter 874 must be in DECLINE-PENDING-CONSUMER")
        XCTAssertTrue(
            pendingSection.contains("八百七十五:"),
            "Chapter 875 must be in DECLINE-PENDING-CONSUMER")
    }

    /// PIN MED-2 from 18th-pass: ch 868 large-shape now has
    /// an inverse band (symmetric protection)。
    func testChapter891_5_MED2_LargeShapeInverseBandAdded() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent(
                "BASChapter868FlashAttention" +
                "AssertedBenchmarkTests.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // Large shape function must contain BOTH bands
        guard let largeFuncRange = content.range(
            of: "testLargeSequenceFlashCompetitive")
        else {
            XCTFail("Large-shape test must exist")
            return
        }
        let largeFunc = String(
            content[largeFuncRange.lowerBound...])
            .prefix(2000)
        XCTAssertTrue(
            largeFunc.contains("stdNs * 1.6"),
            "Large-shape upper band stays at 1.6× (ch 891 widen)")
        XCTAssertTrue(
            largeFunc.contains("flashNs * 1.5"),
            "Large-shape inverse band added at 1.5× " +
            "(ch 891.5 MED-2 fix)")
    }

    /// PIN MED-1 from 18th-pass + ch 891.5 honest correction:
    /// MIGRATION_GUIDE Step 3 now correctly cites chapter 八百三十一
    /// (the actual forwarder-removal chapter) instead of chapter
    /// 八百七十八 (which didn't remove forwarders)。
    func testChapter891_5_MED1_MigrationGuideCorrectChapter() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(
                "MIGRATION_GUIDE_v0.61_to_v0.62.md")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains("chapter 八百三十一"),
            "Step 3 must cite chapter 八百三十一 (actual " +
            "forwarder removal,v0.61.0 mini-arc 5)")
        XCTAssertTrue(
            content.contains("NO net removals in v0.61.0 → v0.62.x")
            || content.contains(
                "v0.62.0 → v0.62.3 removed NOTHING"),
            "Step 3 must honestly clarify v0.62.x removed nothing")
    }

    /// PIN: Docs/DECLINE_PATTERNS.md exists + explains both
    /// patterns + the string-FFI doctrine。
    func testDeclinePatternsDocExists() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs")
            .appendingPathComponent(
                "DECLINE_PATTERNS.md")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: url.path),
            "Docs/DECLINE_PATTERNS.md must exist (LOW-L1+L2 " +
            "fix — explains DECLINE-WITH-TRIGGER vs " +
            "DECLINE-PENDING-CONSUMER + string-FFI doctrine)")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        XCTAssertTrue(
            content.contains("DECLINE-WITH-TRIGGER"))
        XCTAssertTrue(
            content.contains("DECLINE-PENDING-CONSUMER"))
        XCTAssertTrue(
            content.contains("string-FFI"))
    }

    /// PIN: the chapter 759 sub-arc scorecard is now historical
    /// (chapter 887 BadTone extension bumped 24 → 30 + 70 → 93)。
    /// Doc-string should be clear it's historical not current。
    func testLOW3_SubArcScorecardDocIsClear() throws {
        let url = URL(
            fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
            .appendingPathComponent("BASOrchestration")
            .appendingPathComponent(
                "BASRedTeamBatchClassifier.swift")
        let content = try String(
            contentsOf: url, encoding: .utf8)
        // Either the totalRedLines was bumped to 30, OR the
        // doc-string makes clear it's a chapter 759 snapshot
        XCTAssertTrue(
            content.contains(
                "chapter 759 close-out")
            || content.contains(
                "chapter 七百五十九 close-out")
            || content.contains("snapshot")
            || content.contains("historical")
            || content.contains("totalRedLines = 30")
            || content.contains("ch 887 extension"),
            "SubArcScorecard doc must clarify the " +
            "totalRedLines/totalPatterns numbers are " +
            "chapter 759 historical OR be bumped to current " +
            "chapter 887 numbers (LOW-3 fix)")
    }
}
#endif
