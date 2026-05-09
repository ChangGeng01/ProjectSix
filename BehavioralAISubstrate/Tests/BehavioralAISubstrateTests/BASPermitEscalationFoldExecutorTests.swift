// MARK: - BASPermitEscalationFoldExecutorTests — chapter 四百二十五 / M1070

import XCTest
@testable import BASPolicy

final class BASPermitEscalationFoldExecutorTests: XCTestCase {

    // MARK: - Identity factory produces no-op chain

    func testIdentityFactoryProducesNoOpChain() async {
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: ["init"])
        let executor = BASPermitEscalationFoldExecutor
            .identity()
        let results = await executor.fold(
            initialPermit: initial)
        XCTAssertEqual(results.initialPermit, initial)
        XCTAssertEqual(results.abyssal.outputPermit, initial)
        XCTAssertEqual(
            results.assertionCeiling.outputPermit, initial)
        XCTAssertEqual(results.kunlun.outputPermit, initial)
        XCTAssertEqual(
            results.cthulhuAssertionCeiling.outputPermit,
            initial)
        XCTAssertEqual(
            results.cthulhuEscalation.outputPermit, initial)
        XCTAssertEqual(results.finalPermit, initial)
        XCTAssertEqual(results.firedStepCount, 0)
    }

    // MARK: - Sequential threading: each step receives
    // previous step's output

    func testSequentialThreadingPassesOutputToNextInput() async {
        // Each step appends its name to reasonCodes,
        // demonstrating that the input it received was
        // the previous step's output。
        let executor = BASPermitEscalationFoldExecutor(
            abyssal: { permit in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: permit.mode,
                        reasonCodes: permit.reasonCodes
                            + ["abyssal"]),
                    reasonCodes: ["a"])
            },
            assertionCeiling: { permit in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: permit.mode,
                        reasonCodes: permit.reasonCodes
                            + ["assertion"]),
                    reasonCodes: ["b"])
            },
            kunlun: { permit in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: permit.mode,
                        reasonCodes: permit.reasonCodes
                            + ["kunlun"]),
                    reasonCodes: ["c"])
            },
            cthulhuAssertionCeiling: { permit in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: permit.mode,
                        reasonCodes: permit.reasonCodes
                            + ["cthulhu-assertion"]),
                    reasonCodes: ["d"])
            },
            cthulhuEscalation: { permit in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: permit.mode,
                        reasonCodes: permit.reasonCodes
                            + ["cthulhu-escalation"]),
                    reasonCodes: ["e"])
            })
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: ["init"])
        let results = await executor.fold(
            initialPermit: initial)
        // Final permit's reasonCodes must show all 5
        // stages threaded sequentially in canonical order
        XCTAssertEqual(
            results.finalPermit.reasonCodes,
            [
                "init", "abyssal", "assertion", "kunlun",
                "cthulhu-assertion",
                "cthulhu-escalation"
            ],
            "fold must thread input → output sequentially")
    }

    // MARK: - Toledger() matches direct M970 build

    func testToLedgerMatchesM970PositionalBuild() async {
        let executor = BASPermitEscalationFoldExecutor
            .identity()
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let results = await executor.fold(
            initialPermit: initial)
        let viaFold = results.toLedger()
        let viaPositional = BASPermitEscalationLedger.build(
            initialPermit: initial,
            afterAbyssal: initial,
            afterAssertionCeiling: initial,
            afterKunlun: initial,
            afterCthulhuAssertionCeiling: initial,
            afterCthulhuEscalation: initial)
        XCTAssertEqual(viaFold, viaPositional,
            "fold output must be byte-equal to direct " +
            "M970 .build() of the same step results")
    }

    // MARK: - Determinism — same closures + same input
    // → same output

    func testFoldIsDeterministic() async {
        let executor = BASPermitEscalationFoldExecutor
            .identity()
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: ["x"])
        let r1 = await executor.fold(
            initialPermit: initial)
        let r2 = await executor.fold(
            initialPermit: initial)
        XCTAssertEqual(r1, r2,
            "fold must be deterministic (chapter 三百九二)")
    }

    // MARK: - Fired-step counting via ledger

    func testFiredStepsCountedAfterRealEscalation() async {
        // Only abyssal + cthulhu-escalation fire (rebind
        // the permit);others are identity。
        let initial = BASActionPermit(
            mode: .answer, reasonCodes: [])
        let bumped = BASActionPermit(
            mode: .delay, reasonCodes: ["bump"])
        let executor = BASPermitEscalationFoldExecutor(
            abyssal: { _ in
                BASPermitEscalationStepResult(
                    outputPermit: bumped,
                    reasonCodes: ["abyssal-fired"])
            },
            assertionCeiling: { p in
                BASPermitEscalationStepResult.identity(of: p)
            },
            kunlun: { p in
                BASPermitEscalationStepResult.identity(of: p)
            },
            cthulhuAssertionCeiling: { p in
                BASPermitEscalationStepResult.identity(of: p)
            },
            cthulhuEscalation: { p in
                BASPermitEscalationStepResult(
                    outputPermit: BASActionPermit(
                        mode: .block, reasonCodes: ["c-fired"]),
                    reasonCodes: ["cthulhu-fired"])
            })
        let results = await executor.fold(
            initialPermit: initial)
        // 2 stages fired (abyssal + cthulhu-escalation)
        XCTAssertEqual(
            results.firedStepCount, 2,
            "only abyssal + cthulhuEscalation fired")
    }

    // MARK: - All 5 stages executed exactly once

    func testAllFiveStepsExecutedExactlyOnce() async {
        // Use a counter to verify each step closure is
        // called exactly once。
        let counter = AsyncCounter()
        let step: BASPermitEscalationFoldExecutor
            .EscalationStep = { permit in
            await counter.increment()
            return BASPermitEscalationStepResult
                .identity(of: permit)
        }
        let executor = BASPermitEscalationFoldExecutor(
            abyssal: step,
            assertionCeiling: step,
            kunlun: step,
            cthulhuAssertionCeiling: step,
            cthulhuEscalation: step)
        _ = await executor.fold(
            initialPermit: BASActionPermit(
                mode: .answer, reasonCodes: []))
        let count = await counter.value
        XCTAssertEqual(count, 5,
            "exactly 5 step closure invocations")
    }
}

// MARK: - Test helper

/// Async-safe counter for the closure-invocation test。
private actor AsyncCounter {
    private(set) var value: Int = 0
    func increment() {
        value += 1
    }
}
