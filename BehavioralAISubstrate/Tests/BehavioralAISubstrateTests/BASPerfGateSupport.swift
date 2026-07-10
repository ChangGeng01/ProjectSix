import XCTest
import Foundation

/// audit tests-arch ⑤ — opt-in gate for wall-clock THRESHOLD assertions.
///
/// ~18 perf tests asserted a hard wall-clock upper bound BY DEFAULT (e.g. "100 classify() calls
/// < 1s"), which false-REDS under CI / parallel-test load though nothing regressed. `assertBelow`
/// enforces the bound only when `BAS_PERF_GATE=1`; otherwise it RECORDS the measurement. The
/// functional work in each test still runs, so the smoke-coverage (does it complete without
/// crashing?) is unchanged — only the flaky timing assertion is made opt-in.
enum BASPerfGate {
    static let envKey = "BAS_PERF_GATE"

    static func enabled(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        env[envKey] == "1"
    }

    /// Enforce `value < bound` ONLY when the perf gate is enabled; otherwise record and continue.
    static func assertBelow<T: Comparable>(
        _ value: T, _ bound: T, _ label: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        if enabled() {
            XCTAssertLessThan(value, bound, label, file: file, line: line)
        } else {
            let tag = label.isEmpty ? "perf" : label
            print("[perf] \(tag): \(value) (bound \(bound); set BAS_PERF_GATE=1 to enforce)")
        }
    }
}
