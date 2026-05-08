// MARK: - BASChapter403EntropyDoctrineTests — chapter 四百三 / M962
//
// Locks the chapter 四百三 system-entropy reduction work as a
// single grep-able landmark。Mirrors M951 + M952 chapter 四百二
// closure pattern。

import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASChapter403EntropyDoctrineTests: XCTestCase {

    // MARK: - Doctrine constants

    func testChapterTag() {
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.chapterTag,
            "chapter 四百三")
    }

    func testMNumberRange() {
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.mNumberFirst, 953)
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.mNumberLast, 962)
    }

    func testKnivesLedgerCovers10Cuts() {
        XCTAssertEqual(
            BASChapter403EntropyDoctrine.knives.count, 10)
    }

    func testKnivesLedgerCoversFullMRange() {
        let mNumbers = BASChapter403EntropyDoctrine
            .knives.map { $0.mNumber }
        XCTAssertEqual(mNumbers, Array(953...962))
    }

    func testEntropyClassesNonEmpty() {
        XCTAssertFalse(
            BASChapter403EntropyDoctrine
                .entropyClassesAttacked.isEmpty)
    }

    func testPinHeldContainsKeyPins() {
        let pins = BASChapter403EntropyDoctrine.pinHeld
        XCTAssertTrue(pins.contains("不变量 #1"))
        XCTAssertTrue(pins.contains("chapter 二百一一"))
        XCTAssertTrue(pins.contains("chapter 三百九二"))
        XCTAssertTrue(pins.contains("ADR-014"))
        XCTAssertTrue(pins.contains("系统熵 reduction"))
    }

    func testSummaryNonEmpty() {
        XCTAssertFalse(
            BASChapter403EntropyDoctrine.summary.isEmpty)
    }

    // MARK: - Cross-doctrine consistency

    func testChapter402DoctrineUnaffected() {
        // chapter 四百二 (Phase 1) doctrine still pinned。
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberFirst,
            941)
        XCTAssertEqual(
            BASMemoryAtomEventSourcingDoctrine.mNumberLast,
            952)
    }

    func testChapter402AndChapter403MNumbersDoNotOverlap() {
        let p1Range = BASMemoryAtomEventSourcingDoctrine
            .mNumberFirst
            ...
            BASMemoryAtomEventSourcingDoctrine.mNumberLast
        let p2Range = BASChapter403EntropyDoctrine
            .mNumberFirst
            ...
            BASChapter403EntropyDoctrine.mNumberLast
        // Ranges adjacent,non-overlapping
        XCTAssertEqual(p1Range.upperBound + 1,
            p2Range.lowerBound)
    }

    // MARK: - M953-M962 surfaces all reachable

    func testAllChapter403SurfacesReachable() {
        // M953
        let ctx = BASFrameContext(
            sessionID: "s", turnID: "t", emittedAt: Date())
        XCTAssertEqual(ctx.sessionID, "s")
        // M955 protocol
        let _: any BASEventReducer.Type =
            BASMemoryAtomReducer.self
        // M959 matrix
        XCTAssertFalse(BASNamingMatrix.entries.isEmpty)
        // M960 bundle
        struct Item: Sendable, Equatable, Codable {
            let v: String
        }
        let bundle = BASBundle<Item>(items: [Item(v: "x")])
        XCTAssertEqual(bundle.count, 1)
        // M961 builder
        let builder = BASTurnFrameBuilder(
            frameContext: ctx)
        XCTAssertEqual(builder.frameContext, ctx)
    }
}
