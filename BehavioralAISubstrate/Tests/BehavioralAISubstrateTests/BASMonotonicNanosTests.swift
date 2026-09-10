// MARK: - BASMonotonicNanosTests
// chapter 七百三 / M2177 第三刀 — anti-drift PROOF tests
//                                  for the chapter 七百三
//                                  C pilot (BAS
//                                  MonotonicNanos Swift
//                                  actor + bas_monotonic_
//                                  nanos C function)。
//
// ## Coverage matrix (18 tests)
//
// **C ABI surface**
//   1. cBridgeABIVersion constant == 1
//   2. live C-side bas_monotonic_nanos_version == 1
//   3. cBridgeABIVersion equals liveCBridgeABIVersion
//
// **V1 baseline**
//   4. defaultV1Nanos returns non-zero
//   5. defaultV1Nanos is monotonically non-decreasing
//      across back-to-back reads
//
// **V2 raw C surface**
//   6. rawCNanos returns non-zero on success
//   7. rawCNanos is monotonically non-decreasing across
//      back-to-back reads
//   8. rawCNanos does not throw under nominal conditions
//
// **Dual-mode equivalence (BYTE-EQUALITY-CLASS proof)**
//   9. equivalenceDeltaNanos <= equivalenceBoundNanos
//      (1ms tolerance — 10× empirical headroom)
//  10. equivalenceBoundNanos pinned at 1_000_000 (1ms)
//
// **Actor + factory**
//  11. init(useCBridge: false) — isUsingCBridge false
//  12. init(useCBridge: true)  — isUsingCBridge true
//  13. current() with V1 actor returns non-zero (no
//      throw)
//  14. current() with V2 actor returns non-zero (no
//      throw)
//  15. make(flags:) default-off chooses V1 path
//  16. make(flags:) explicit-on chooses V2 path
//
// **Error case typing**
//  17. BASMonotonicNanosError Codable round-trip
//      preserves typed cases
//  18. Error.unknownReturnCode(42) preserves Int32 arg
//
// All tests are SYNC (no `async` keyword for the
// non-actor surfaces;the actor `current()` is called
// from sync tests via `Task { ... }` await — Diagnostic
// F pattern from chapter 六百九十七 / M2158)。

import XCTest
@testable import BASRuntimeCore

final class BASMonotonicNanosTests: XCTestCase {

    // MARK: - C ABI surface

    func testCBridgeABIVersionConstantIsOne() {
        XCTAssertEqual(
            BASMonotonicNanos.cBridgeABIVersion, 1,
            "Swift-side ABI pin must equal 1 to match" +
            " the M2175 C-side bas_monotonic_nanos_version" +
            " return value。 Bumping requires updating" +
            " BOTH simultaneously。")
    }

    func testLiveCBridgeVersionIsOne() {
        XCTAssertEqual(
            BASMonotonicNanos.liveCBridgeABIVersion(),
            1,
            "C-side bas_monotonic_nanos_version() must" +
            " return 1 at the M2175 contract version。")
    }

    func testCFunctionVersionPin() {
        // Anti-drift:both sides must agree。 This is
        // the test that catches a future C-side bump
        // that doesn't update the Swift-side pin。
        XCTAssertEqual(
            BASMonotonicNanos.cBridgeABIVersion,
            BASMonotonicNanos.liveCBridgeABIVersion())
    }

    // MARK: - V1 baseline

    func testDefaultV1NanosReturnsNonZero() {
        let value = BASMonotonicNanos.defaultV1Nanos()
        XCTAssertGreaterThan(value, 0,
            "V1 DispatchTime read should always return" +
            " a positive uptime nanoseconds value on" +
            " any running machine。")
    }

    func testDefaultV1NanosIsMonotonicallyNonDecreasing() {
        var prior = BASMonotonicNanos.defaultV1Nanos()
        for _ in 0 ..< 20 {
            let next = BASMonotonicNanos.defaultV1Nanos()
            XCTAssertGreaterThanOrEqual(next, prior,
                "DispatchTime.now().uptimeNanoseconds" +
                " must be monotonically non-decreasing。")
            prior = next
        }
    }

    // MARK: - V2 raw C surface

    func testRawCNanosReturnsNonZero() throws {
        let value = try BASMonotonicNanos.rawCNanos()
        XCTAssertGreaterThan(value, 0,
            "C-side clock_gettime_nsec_np(CLOCK_UPTIME_" +
            "RAW) should always return a positive value" +
            " on any running Apple platform。")
    }

    func testRawCNanosIsMonotonicallyNonDecreasing() throws {
        var prior = try BASMonotonicNanos.rawCNanos()
        for _ in 0 ..< 20 {
            let next = try BASMonotonicNanos.rawCNanos()
            XCTAssertGreaterThanOrEqual(next, prior,
                "C-side CLOCK_UPTIME_RAW must be" +
                " monotonically non-decreasing。")
            prior = next
        }
    }

    func testRawCNanosDoesNotThrowUnderNominalConditions() {
        XCTAssertNoThrow(
            try BASMonotonicNanos.rawCNanos())
    }

    // MARK: - Dual-mode equivalence (BYTE-EQUALITY-CLASS)

    func testEquivalenceDeltaIsWithinBound() throws {
        let delta = try BASMonotonicNanos
            .equivalenceDeltaNanos()
        XCTAssertLessThan(
            delta,
            BASMonotonicNanos.equivalenceBoundNanos,
            "V1 (DispatchTime) and V2 (C clock_gettime" +
            "_nsec_np) reads taken back-to-back must" +
            " differ by < 1ms。 Both APIs reduce to" +
            " mach_absolute_time under XNU,so they" +
            " should agree to within scheduler jitter。" +
            " Observed delta:\(delta) ns。")
    }

    func testEquivalenceBoundNanosPinnedAtOneMillisecond() {
        XCTAssertEqual(
            BASMonotonicNanos.equivalenceBoundNanos,
            1_000_000,
            "Bound pinned at 1ms (10× headroom over" +
            " empirically observed <100µs delta)。" +
            " Bumping requires explicit doctrine update。")
    }

    // MARK: - Actor + factory

    func testActorRespectsInitFlagFalse() {
        let actor = BASMonotonicNanos(useCBridge: false)
        let exp = expectation(
            description: "isUsingCBridge=false")
        Task {
            let isUsing = await actor.isUsingCBridge
            XCTAssertFalse(isUsing)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testActorRespectsInitFlagTrue() {
        let actor = BASMonotonicNanos(useCBridge: true)
        let exp = expectation(
            description: "isUsingCBridge=true")
        Task {
            let isUsing = await actor.isUsingCBridge
            XCTAssertTrue(isUsing)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testActorCurrentV1ReturnsNonZero() {
        let actor = BASMonotonicNanos(useCBridge: false)
        let exp = expectation(description: "current V1")
        Task {
            do {
                let value = try await actor.current()
                XCTAssertGreaterThan(value, 0)
            } catch {
                XCTFail("V1 path must not throw:\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testActorCurrentV2ReturnsNonZero() {
        let actor = BASMonotonicNanos(useCBridge: true)
        let exp = expectation(description: "current V2")
        Task {
            do {
                let value = try await actor.current()
                XCTAssertGreaterThan(value, 0)
            } catch {
                XCTFail("V2 path must not throw on Apple:\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testMakeWithFlagsDefaultChoosesV2AtChapter712() {
        // M2203 chapter 七百十二 — cBridgeEnabled flipped
        // default-true。 Factory now picks V2 C path。
        let exp = expectation(description: "make default")
        Task {
            let flags = BASLanguageAugmentationFeatureFlags()
            let defaultValue = await flags.isEnabled(
                .cBridgeEnabled)
            XCTAssertTrue(defaultValue,
                "M2203 wire-in:cBridgeEnabled now" +
                " defaults TRUE")
            let actor = await BASMonotonicNanos.make(
                flags: flags)
            let isUsing = await actor.isUsingCBridge
            XCTAssertTrue(isUsing,
                "make(flags:) with default cBridge" +
                "Enabled (true) picks V2 C path。")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    func testMakeWithFlagsExplicitlyOnChoosesV2() {
        let exp = expectation(description: "make on")
        Task {
            let flags = BASLanguageAugmentationFeatureFlags()
            await flags.setFlag(.cBridgeEnabled, to: true)
            let actor = await BASMonotonicNanos.make(
                flags: flags)
            let isUsing = await actor.isUsingCBridge
            XCTAssertTrue(isUsing,
                "make(flags:) with explicit-on cBridge" +
                "Enabled must pick V2 path。")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    // MARK: - Error case typing

    func testErrorCasesAreCodableRoundTrippable() throws {
        let cases: [BASMonotonicNanosError] = [
            .nullOutPointer,
            .clockGetTimeSyscallFailed,
            .unknownReturnCode(42)
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(
                BASMonotonicNanosError.self, from: data)
            XCTAssertEqual(decoded, original,
                "Error case '\(original)' must" +
                " Codable round-trip without value loss。")
        }
    }

    func testUnknownReturnCodePreservesAssociatedValue() {
        let err = BASMonotonicNanosError
            .unknownReturnCode(99)
        if case .unknownReturnCode(let code) = err {
            XCTAssertEqual(code, 99)
        } else {
            XCTFail("Wrong case captured")
        }
    }
}
