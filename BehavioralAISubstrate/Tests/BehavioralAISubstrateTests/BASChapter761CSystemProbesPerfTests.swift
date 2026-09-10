// MARK: - BASChapter761CSystemProbesPerfTests
// chapter 七百六十一 第四刀 / M2459
//
// DEEPER LAYER-MIGRATION ARC perf measurement for the L1 C
// system probes (chapter 七百六十一 第一-三刀)。 Compares:
//
//   1. DispatchTime.now().uptimeNanoseconds (V1 Swift baseline)
//   2. bas_monotonic_nanos (sleep-EXCLUDED C clock,chapter 七百三)
//   3. bas_wallclock_nanos (sleep-INCLUDED C clock,chapter 七百六十一)
//   4. Date().timeIntervalSince1970 (V1 Swift wall-clock baseline)
//   5. bas_task_phys_footprint (memory probe,no V1 equivalent)
//
// Per the plan:expect 1.2-1.5× speedup for C clock vs DispatchTime
// on hot loops。 Memory probe has no V1 baseline,so we only measure
// absolute timing。

import XCTest
import Foundation
@testable import BASRuntimeCore

final class BASChapter761CSystemProbesPerfTests: XCTestCase {

    // MARK: - Perf measurement (release-mode advisory only)

    /// Number of iterations for the perf measurement loop。 100k
    /// matches the chapter 七百六十一 plan target。
    private let perfIters: Int = 100_000

    /// Measure elapsed nanoseconds for a closure。 Uses
    /// `DispatchTime.now()` itself (which is what we're measuring
    /// alternatives against — this is the universal timer)。
    private func measureNanos(_ body: () -> Void) -> UInt64 {
        let start = DispatchTime.now().uptimeNanoseconds
        body()
        let end = DispatchTime.now().uptimeNanoseconds
        return end - start
    }

    // MARK: - DispatchTime baseline

    func testV1DispatchTimeBaseline() {
        var sink: UInt64 = 0
        let nanos = measureNanos {
            for _ in 0..<perfIters {
                sink = sink &+ DispatchTime.now().uptimeNanoseconds
            }
        }
        XCTAssertGreaterThan(sink, 0,
            "sink prevents the compiler from eliding the loop")
        print("[chapter 七百六十一] V1 DispatchTime.now():" +
              " \(nanos) ns over \(perfIters) iters" +
              " (\(nanos / UInt64(perfIters)) ns/call)")
        // No assert on absolute timing — hardware varies。
    }

    // MARK: - C monotonic clock (sleep-excluded)

    func testV2BasMonotonicNanosThroughput() throws {
        var sink: UInt64 = 0
        let nanos = measureNanos {
            for _ in 0..<perfIters {
                if let v = try? BASMonotonicNanos.rawCNanos() {
                    sink = sink &+ v
                }
            }
        }
        XCTAssertGreaterThan(sink, 0)
        print("[chapter 七百六十一] V2 bas_monotonic_nanos:" +
              " \(nanos) ns over \(perfIters) iters" +
              " (\(nanos / UInt64(perfIters)) ns/call)")
    }

    // MARK: - C wallclock (sleep-included)

    func testV2BasWallclockNanosThroughput() throws {
        var sink: UInt64 = 0
        let nanos = measureNanos {
            for _ in 0..<perfIters {
                if let v = try? BASWallclockNanos.rawCNanos() {
                    sink = sink &+ v
                }
            }
        }
        XCTAssertGreaterThan(sink, 0)
        print("[chapter 七百六十一] V2 bas_wallclock_nanos:" +
              " \(nanos) ns over \(perfIters) iters" +
              " (\(nanos / UInt64(perfIters)) ns/call)")
    }

    // MARK: - Swift Date baseline (wall-clock)

    func testV1DateBaseline() {
        var sink: Double = 0
        let nanos = measureNanos {
            for _ in 0..<perfIters {
                sink += Date().timeIntervalSince1970
            }
        }
        XCTAssertGreaterThan(sink, 0)
        print("[chapter 七百六十一] V1 Date.timeIntervalSince1970:" +
              " \(nanos) ns over \(perfIters) iters" +
              " (\(nanos / UInt64(perfIters)) ns/call)")
    }

    // MARK: - Memory probe (no V1 baseline)

    func testV2BasTaskPhysFootprintThroughput() throws {
        var sink: UInt64 = 0
        // 10k iterations — task_info is heavier than a clock read,
        // so we use a smaller N to keep test runtime reasonable。
        let iters = 10_000
        let nanos = measureNanos {
            for _ in 0..<iters {
                if let s = try? BASTaskVmInfoProbe.rawSnapshot() {
                    sink = sink &+ s.physFootprintBytes
                }
            }
        }
        XCTAssertGreaterThan(sink, 0)
        print("[chapter 七百六十一] V2 bas_task_phys_footprint:" +
              " \(nanos) ns over \(iters) iters" +
              " (\(nanos / UInt64(iters)) ns/call)")
    }

    // MARK: - 5-axis decision aggregate

    func testChapter761FiveAxisDecisionAggregate() throws {
        // Run all 5 measurements + emit a summary print。
        // Axis 1 (perf) decision happens at knife 5 / M2460 based
        // on these numbers。
        print("")
        print("================================================")
        print("Chapter 七百六十一 第四刀 / M2459 perf scorecard")
        print("================================================")

        // V1 monotonic
        var s1: UInt64 = 0
        let t1 = measureNanos {
            for _ in 0..<perfIters {
                s1 = s1 &+ DispatchTime.now().uptimeNanoseconds
            }
        }
        let v1Mono = t1 / UInt64(perfIters)

        // V2 monotonic C
        var s2: UInt64 = 0
        let t2 = measureNanos {
            for _ in 0..<perfIters {
                if let v = try? BASMonotonicNanos.rawCNanos() {
                    s2 = s2 &+ v
                }
            }
        }
        let v2Mono = t2 / UInt64(perfIters)

        // V1 wall-clock
        var s3: Double = 0
        let t3 = measureNanos {
            for _ in 0..<perfIters {
                s3 += Date().timeIntervalSince1970
            }
        }
        let v1Wall = t3 / UInt64(perfIters)

        // V2 wall-clock C
        var s4: UInt64 = 0
        let t4 = measureNanos {
            for _ in 0..<perfIters {
                if let v = try? BASWallclockNanos.rawCNanos() {
                    s4 = s4 &+ v
                }
            }
        }
        let v2Wall = t4 / UInt64(perfIters)

        print("  Monotonic clock (sleep-excluded):")
        print("    V1 DispatchTime.now():       \(v1Mono) ns/call")
        print("    V2 bas_monotonic_nanos:      \(v2Mono) ns/call")
        if v2Mono > 0 {
            let ratio = Double(v1Mono) / Double(v2Mono)
            print("    Speedup (V2 vs V1):          \(String(format: "%.2f", ratio))×")
        }
        print("  Wall-clock (sleep-included):")
        print("    V1 Date.timeIntervalSince1970: \(v1Wall) ns/call")
        print("    V2 bas_wallclock_nanos:        \(v2Wall) ns/call")
        if v2Wall > 0 {
            let ratio = Double(v1Wall) / Double(v2Wall)
            print("    Speedup (V2 vs V1):            \(String(format: "%.2f", ratio))×")
        }
        print("================================================")
        print("Plan expectation: 1.2-1.5× speedup for C clock")
        print("================================================")

        // Sink to prevent compiler from eliding loops。
        XCTAssertGreaterThan(s1, 0)
        XCTAssertGreaterThan(s2, 0)
        XCTAssertGreaterThan(s3, 0)
        XCTAssertGreaterThan(s4, 0)
    }
}
