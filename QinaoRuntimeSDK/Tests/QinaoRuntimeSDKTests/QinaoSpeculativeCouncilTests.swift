import XCTest
@testable import QinaoSeats

/// 六十五.5 — speculative council tests.
final class QinaoSpeculativeCouncilTests: XCTestCase {

    func test_committedWhenNoVeto() async {
        let outcome =
            await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { 42 },
                    veto: {
                        (false, "")
                    })
        switch outcome {
        case .committed(let value):
            XCTAssertEqual(value, 42)
        case .vetoed:
            XCTFail("expected committed")
        }
    }

    func test_vetoedDiscardResult() async {
        let outcome =
            await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { "speculative-result" },
                    veto: {
                        (true, "sovereign-halt")
                    })
        switch outcome {
        case .committed:
            XCTFail("expected vetoed")
        case .vetoed(let reason):
            XCTAssertEqual(
                reason, "sovereign-halt")
        }
    }

    func test_sovereignVetoConvenienceCommitted()
        async
    {
        let outcome:
            QinaoSpeculativeOutcome<Int>
            = await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { 99 },
                    sovereignVeto: { false })
        switch outcome {
        case .committed(let v):
            XCTAssertEqual(v, 99)
        case .vetoed:
            XCTFail()
        }
    }

    func test_sovereignVetoConvenienceVetoed() async {
        let outcome:
            QinaoSpeculativeOutcome<Int>
            = await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: { 99 },
                    sovereignVeto: { true },
                    vetoReason: "test-veto")
        switch outcome {
        case .committed:
            XCTFail()
        case .vetoed(let reason):
            XCTAssertEqual(reason, "test-veto")
        }
    }

    func test_concurrentExecution() async {
        // Simulate council that takes time + veto that
        // returns immediately. Ensures both run
        // concurrently — total time ~ slower of the two.
        let start = Date()
        let outcome =
            await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: {
                        // ~50ms work simulated.
                        try? await Task.sleep(
                            nanoseconds: 50_000_000)
                        return "ok"
                    },
                    veto: { (false, "") })
        let elapsed = Date()
            .timeIntervalSince(start)
        XCTAssertLessThan(
            elapsed, 0.5,
            "speculative + veto must be concurrent")
        if case .committed(let v) = outcome {
            XCTAssertEqual(v, "ok")
        } else {
            XCTFail("expected committed")
        }
    }

    func test_genericResultType() async {
        struct CustomResult: Sendable, Equatable {
            let payload: String
        }
        let outcome:
            QinaoSpeculativeOutcome<CustomResult>
            = await QinaoSpeculativeCouncil
                .runSpeculatively(
                    council: {
                        CustomResult(payload: "x")
                    },
                    veto: { (false, "") })
        if case .committed(let r) = outcome {
            XCTAssertEqual(r.payload, "x")
        } else {
            XCTFail()
        }
    }
}
