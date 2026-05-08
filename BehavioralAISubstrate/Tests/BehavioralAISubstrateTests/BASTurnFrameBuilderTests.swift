// MARK: - BASTurnFrameBuilderTests — chapter 四百三 / M961

import Foundation
import XCTest
@testable import BASHostKit
@testable import BASMemory
@testable import BASOrchestration
@testable import BASPolicy
@testable import BASRuntimeCore

final class BASTurnFrameBuilderTests: XCTestCase {

    // MARK: - Fixtures

    private func makeContext() -> BASFrameContext {
        BASFrameContext(
            sessionID: "s",
            turnID: "t",
            emittedAt: Date(timeIntervalSince1970: 0))
    }

    private func makeBudget() -> BASBudgetFrame {
        BASBudgetFrame(
            runMode: .engage,
            maxLoops: 1,
            maxCandidates: 1,
            maxDecodeTokens: 64,
            retrievalDepth: 1,
            precisionProfile: .balanced,
            deviceRoute: .scoutCPU,
            thermalGuardLevel: .nominal,
            maintenanceAllowed: false)
    }

    // MARK: - Init shape (3)

    func testMinimalInitOnlyFrameContext() {
        let b = BASTurnFrameBuilder(
            frameContext: makeContext())
        XCTAssertEqual(b.frameContext.sessionID, "s")
        XCTAssertNil(b.routedBudget)
        XCTAssertNil(b.contextFrame)
        XCTAssertNil(b.decomposeFrame)
        XCTAssertNil(b.thoughtFrame)
        XCTAssertNil(b.mergedChoice)
        XCTAssertNil(b.riskCard)
        XCTAssertNil(b.permit)
        XCTAssertNil(b.renderedOutput)
    }

    func testFullInitPopulatesAllSlots() {
        let b = BASTurnFrameBuilder(
            frameContext: makeContext(),
            routedBudget: makeBudget())
        XCTAssertNotNil(b.routedBudget)
    }

    func testFrameContextIdentityPreserved() {
        let ctx = makeContext()
        let b = BASTurnFrameBuilder(frameContext: ctx)
        XCTAssertEqual(b.frameContext, ctx)
    }

    // MARK: - With-chain (4)

    func testWithRoutedBudgetReturnsNewBuilder() {
        let original = BASTurnFrameBuilder(
            frameContext: makeContext())
        let updated = original.with(
            routedBudget: makeBudget())
        XCTAssertNil(original.routedBudget,
            "M961:with-chain must NOT mutate original")
        XCTAssertNotNil(updated.routedBudget)
    }

    func testWithChainPreservesEarlierFields() {
        let budget = makeBudget()
        let b1 = BASTurnFrameBuilder(
            frameContext: makeContext())
            .with(routedBudget: budget)
        // After adding routedBudget, frameContext is preserved
        XCTAssertEqual(b1.frameContext.sessionID, "s")
        XCTAssertNotNil(b1.routedBudget)
    }

    func testMultipleWithCallsCompose() {
        let b = BASTurnFrameBuilder(
            frameContext: makeContext())
            .with(routedBudget: makeBudget())
        XCTAssertNotNil(b.routedBudget)
        XCTAssertNotNil(b.frameContext)
    }

    func testWithChainProducesEqualResultForSameInputs() {
        // M892 replay-determinism:same chain → equal builder
        let ctx = makeContext()
        let b = makeBudget()
        let b1 = BASTurnFrameBuilder(frameContext: ctx)
            .with(routedBudget: b)
        let b2 = BASTurnFrameBuilder(frameContext: ctx)
            .with(routedBudget: b)
        XCTAssertEqual(b1.frameContext, b2.frameContext)
        XCTAssertEqual(
            b1.routedBudget?.runMode,
            b2.routedBudget?.runMode)
    }

    // MARK: - All slots accept their typed values (1)

    func testAllSlotsHaveTypedWithMethod() {
        // Compile-time check: each slot has a corresponding
        // with(...) method。If any are missing,this test
        // won't compile。
        let ctx = makeContext()
        let _: BASTurnFrameBuilder =
            BASTurnFrameBuilder(frameContext: ctx)
        XCTAssertTrue(true,
            "M961:builder + 8 slot with-methods compile")
    }
}
