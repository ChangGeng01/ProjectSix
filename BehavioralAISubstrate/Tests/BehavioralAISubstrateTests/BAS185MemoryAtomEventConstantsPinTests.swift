// MARK: - BAS185MemoryAtomEventConstantsPinTests
// chapter 四百二 / M950 — chapter 一百八十五 anti-magic-number pin
//
// Doctrine guardrail tests:every coefficient introduced by
// M941-M948 must be a named typed constant,not an inline magic
// number。If a future commit re-introduces inline literals,
// these tests catch the regression。

import Foundation
import XCTest
@testable import BASMemory
@testable import BASRuntimeCore

final class BAS185MemoryAtomEventConstantsPinTests:
    XCTestCase
{

    // MARK: - M941 constants

    func testMemoryAtomEventActionTagIsNamed() {
        XCTAssertFalse(
            BASEventLogEntry.memoryAtomEventActionTag.isEmpty)
        XCTAssertEqual(
            BASEventLogEntry.memoryAtomEventActionTag,
            "memory-atom-event")
    }

    func testM942TiebreakRuleIsNamed() {
        // chapter 一百八十五:tiebreak rule is a static let,
        // not inline。Tests pin the rule's value。
        XCTAssertEqual(
            BASMemoryAtomReducer
                .admissionConfidenceTiebreakKeepsExisting,
            true)
    }

    // MARK: - M945 knowledge graph extractor constants

    func testM945NodeWeightIsNamed() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomNodeWeight,
            0.6)
    }

    func testM945CausesEdgeWeightIsNamed() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomCausesEdgeWeight,
            0.4)
    }

    func testM945TouchesEdgeWeightIsNamed() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomTouchesEdgeWeight,
            0.5)
    }

    func testM945DecayEdgeWeightIsNamed() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomDecayEdgeWeight,
            0.3)
    }

    func testM945ReasonCodePrefixIsNamed() {
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomReasonCodePrefix,
            "knowledge-graph-extract:memory-atom")
    }

    func testM945ActionTagMatchesM941() {
        // chapter 二百一一:single source of truth — both
        // BASEventLogEntry.memoryAtomEventActionTag (M941) and
        // BASKnowledgeGraphEventExtractor.memoryAtomEventActionTag
        // (M945) must agree on the tag string。
        XCTAssertEqual(
            BASKnowledgeGraphEventExtractor
                .memoryAtomEventActionTag,
            BASEventLogEntry.memoryAtomEventActionTag)
    }
}
