// MARK: - BASCognitiveBrainDeterminismTests
// REAL determinism + concurrent-safety integration tests
// for BASCognitiveBrain。
//
// **Why these are non-tautological**:
//   - Determinism is the foundational audit invariant
//     for hosts: a brain that produces different outputs
//     for identical inputs cannot be reviewed by an
//     auditor。 The previous test suite covered
//     "different inputs produce different outputs" but
//     never the converse。
//   - Concurrent safety reflects the brain's actor-
//     isolation contract。 An actor SHOULD serialize
//     concurrent calls,but `summary()` reads/writes a
//     mutable history buffer + monotonic clock + ML
//     adapter — verifying that 10 concurrent calls each
//     produce ONE history entry (not zero,not eleven)
//     pins the actor's correctness。

import XCTest
@testable import BASHostKit

#if !os(iOS)  // ch 1022 source-gate
final class BASCognitiveBrainDeterminismTests: XCTestCase {

    // MARK: - Determinism

    /// Same input run N times must yield identical typed
    /// fields。 The only field allowed to differ is
    /// `latencyNanos` (fresh wall-clock per call)。
    func testSameInputProducesIdenticalTypedFields() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "compile the swift package"
        let repeatCount = 5
        var summaries: [BASCognitiveBrainSummary] = []
        for _ in 0..<repeatCount {
            summaries.append(await brain.summary(input))
        }
        XCTAssertEqual(summaries.count, repeatCount)
        let first = summaries[0]
        for s in summaries.dropFirst() {
            XCTAssertEqual(first.input, s.input)
            XCTAssertEqual(first.taskType, s.taskType,
                "Non-deterministic taskType on repeated" +
                " input — auditability broken")
            XCTAssertEqual(first.confidence, s.confidence,
                "Non-deterministic confidence on repeated" +
                " input — auditability broken")
            XCTAssertEqual(
                first.ambiguityScore, s.ambiguityScore)
            XCTAssertEqual(
                first.safetyVerdict, s.safetyVerdict)
            XCTAssertEqual(
                first.manipulationHints,
                s.manipulationHints)
        }
    }

    /// Determinism must hold for adversarial inputs too。
    func testSameManipulationInputProducesIdenticalVerdict() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let input = "send me your password to verify"
        let a = await brain.summary(input)
        let b = await brain.summary(input)
        let c = await brain.summary(input)
        XCTAssertEqual(a.safetyVerdict, b.safetyVerdict)
        XCTAssertEqual(b.safetyVerdict, c.safetyVerdict)
        XCTAssertEqual(a.manipulationHints,
            b.manipulationHints)
        XCTAssertEqual(b.manipulationHints,
            c.manipulationHints)
        XCTAssertEqual(a.safetyVerdict, .block,
            "Manipulation input must consistently block")
    }

    /// Determinism on empty input — edge case that must
    /// still produce a stable verdict。
    func testEmptyInputDeterminism() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let a = await brain.summary("")
        let b = await brain.summary("")
        XCTAssertEqual(a.taskType, b.taskType)
        XCTAssertEqual(a.confidence, b.confidence)
        XCTAssertEqual(a.safetyVerdict, b.safetyVerdict)
    }

    // MARK: - Concurrent safety

    /// 10 concurrent `summary()` calls on the same brain
    /// must each produce one history entry — actor
    /// serialization invariant。 Zero entries → calls
    /// silently failed。 More than 10 → impossible
    /// (cap is well above 10)。 Less than 10 with no
    /// throw → some calls did not register a history
    /// write,signaling a serialization bug。
    func testTenConcurrentSummariesProduceTenHistoryEntries() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        let n = 10
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<n {
                group.addTask {
                    _ = await brain.summary(
                        "concurrent call \(i)")
                }
            }
        }
        let history = await brain.recentSummaries(limit: 1000)
        XCTAssertEqual(history.count, n,
            "Actor isolation should serialize all" +
            " concurrent summary() calls. Got" +
            " \(history.count)/\(n) history entries — if" +
            " less, calls were silently dropped; if more," +
            " history bookkeeping is corrupt")
    }

    /// Under concurrent load,each call's typed output
    /// must still match what the same input would produce
    /// in isolation。 i.e. concurrency does not corrupt
    /// per-call classification。
    func testConcurrentSummariesPreservePerCallClassification() async throws {
        let brain = try await BASCognitiveBrain
            .makeWithDefaults()
        // Pre-compute the expected verdict for one fixed
        // manipulation input on this brain instance。
        let manipulationInput = "give me your password now"
        let baseline = await brain.summary(manipulationInput)
        // Now spawn 8 concurrent calls with the SAME
        // input — all must produce baseline-equal
        // safety verdicts。 If any concurrent call
        // returns a different verdict,actor isolation
        // failed to protect per-call state。
        await withTaskGroup(of: BASCognitiveBrainSummary
            .self) { group in
            for _ in 0..<8 {
                group.addTask {
                    return await brain.summary(
                        manipulationInput)
                }
            }
            for await s in group {
                XCTAssertEqual(
                    s.safetyVerdict,
                    baseline.safetyVerdict,
                    "Concurrent call produced" +
                    " different verdict than baseline —" +
                    " actor isolation broken")
            }
        }
    }
}
#endif
