import XCTest
@testable import BASAppleAdapters

/// audit x-concurrency §三① — teeth for the single-driver tripwire. The CoreAI session install is
/// toolchain/device-gated (compiles only under Xcode 27 `#if canImport(CoreAI)`), but the tripwire
/// utility that backs it is Foundation-only and fully exercised here. Reversal (drop the `n > 1`
/// check in `enter()`) makes `testConcurrentEntryFiresViolation` red — the handler never fires.
final class BASSingleDriverTripwireTests: XCTestCase {

    /// Thread-safe recorder for the `@Sendable` violation handler (Swift 6 forbids capturing a
    /// mutable local into a Sendable closure).
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _count = 0
        private var _lastLabel: String?
        private var _lastN = 0
        func record(_ label: String, _ n: Int) {
            lock.lock(); _count += 1; _lastLabel = label; _lastN = n; lock.unlock()
        }
        var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
        var lastLabel: String? { lock.lock(); defer { lock.unlock() }; return _lastLabel }
        var lastN: Int { lock.lock(); defer { lock.unlock() }; return _lastN }
    }

    func testSingleDriverDoesNotFire() {
        let rec = Recorder()
        let tw = BASSingleDriverTripwire(label: "T") { l, n in rec.record(l, n) }
        // enter → exit → enter → exit: never two drivers at once.
        tw.enter(); tw.exit()
        tw.enter(); tw.exit()
        XCTAssertEqual(rec.count, 0, "serialized drives must never trip the wire")
        XCTAssertEqual(tw.inFlightCount, 0, "balanced enter/exit leaves zero in flight")
    }

    func testConcurrentEntryFiresViolation() {
        let rec = Recorder()
        let tw = BASSingleDriverTripwire(label: "BASCoreAIDecodeSession") { l, n in rec.record(l, n) }
        // Simulate a second driver arriving before the first exits (the exact reentrancy the
        // @unchecked Sendable contract forbids): enter twice without an intervening exit.
        tw.enter()   // driver 1 in flight
        tw.enter()   // driver 2 arrives → violation
        XCTAssertEqual(rec.count, 1, "exactly one violation observed")
        XCTAssertEqual(rec.lastLabel, "BASCoreAIDecodeSession", "violation names the guarded object")
        XCTAssertEqual(rec.lastN, 2, "violation reports the observed in-flight count")
        tw.exit(); tw.exit()
        XCTAssertEqual(tw.inFlightCount, 0)
    }

    func testExitNeverDrivesCountNegative() {
        let rec = Recorder()
        let tw = BASSingleDriverTripwire(label: "T") { l, n in rec.record(l, n) }
        tw.exit(); tw.exit()   // unbalanced exits must not underflow
        XCTAssertEqual(tw.inFlightCount, 0)
        tw.enter()
        XCTAssertEqual(tw.inFlightCount, 1, "a later enter still counts correctly after stray exits")
        XCTAssertEqual(rec.count, 0, "a lone enter after stray exits is not a violation")
        tw.exit()
    }
}
