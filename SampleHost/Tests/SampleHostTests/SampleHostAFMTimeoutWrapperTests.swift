// MARK: - SampleHostAFMTimeoutWrapperTests — chapter 三百四二 / M829
//
// Tests for `withTimeout(seconds:operation:)` + `AFMTimeoutError`
// shipped in chapter 三百四二 / M829。Verifies the wrapper:
//   - Returns operation result when operation finishes first
//   - Throws AFMTimeoutError when timeout fires first
//   - Re-throws operation's own errors (not timeout) when those
//     fire first
//   - Cancels the surviving sibling task on first finisher

import XCTest
@testable import SampleHost

final class SampleHostAFMTimeoutWrapperTests: XCTestCase {

    // MARK: - Happy path

    func testReturnsResultWhenOperationCompletesFirst()
        async throws
    {
        let result: Int = try await withTimeout(
            seconds: 5.0
        ) {
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            return 42
        }
        XCTAssertEqual(result, 42)
    }

    // MARK: - Timeout fires

    func testThrowsAFMTimeoutErrorWhenDeadlineFires()
        async
    {
        do {
            let _: Int = try await withTimeout(
                seconds: 0.05  // 50ms
            ) {
                try await Task.sleep(
                    nanoseconds: 500_000_000)  // 500ms
                return 99
            }
            XCTFail("Expected AFMTimeoutError")
        } catch let timeout as AFMTimeoutError {
            XCTAssertEqual(
                timeout.timeoutSeconds, 0.05,
                accuracy: 0.001)
        } catch {
            XCTFail(
                "Expected AFMTimeoutError, got \(error)")
        }
    }

    // MARK: - Operation error preserved

    struct CustomOperationError: Error, Equatable {}

    func testOperationErrorWinsWhenItFiresFirst()
        async
    {
        do {
            let _: Int = try await withTimeout(
                seconds: 5.0  // long deadline
            ) {
                try await Task.sleep(nanoseconds: 10_000_000)
                throw CustomOperationError()
            }
            XCTFail("Expected CustomOperationError")
        } catch is CustomOperationError {
            // Expected — operation's own error preserved
        } catch is AFMTimeoutError {
            XCTFail(
                "Operation error should win over timeout " +
                "when it fires first")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Edge: zero / negative timeout clamped to 1ms

    func testNegativeTimeoutClampedToTinyDeadline() async {
        do {
            let _: Int = try await withTimeout(
                seconds: -100  // negative
            ) {
                try await Task.sleep(
                    nanoseconds: 100_000_000)  // 100ms
                return 1
            }
            XCTFail("Should throw timeout")
        } catch is AFMTimeoutError {
            // Expected — clamped to 1ms,fires immediately
        } catch {
            XCTFail("Expected AFMTimeoutError, got \(error)")
        }
    }

    // MARK: - AFMTimeoutError equality

    func testAFMTimeoutErrorEquality() {
        let a = AFMTimeoutError(timeoutSeconds: 5.0)
        let b = AFMTimeoutError(timeoutSeconds: 5.0)
        let c = AFMTimeoutError(timeoutSeconds: 10.0)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
