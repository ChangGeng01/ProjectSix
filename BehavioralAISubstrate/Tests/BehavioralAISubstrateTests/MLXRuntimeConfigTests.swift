import XCTest
import Foundation
@testable import BASMLXAdapter

/// #3 — converge the process-global `MLX.Memory.cacheLimit` behind one observable seam. These prove the
/// conflict policy deterministically with NO MLX dependency: the real `MLX.Memory.cacheLimit =` side effect is
/// injected as a recording `sink` (touching `MLX.Memory` on the macOS host forces a metallib load that aborts).
final class MLXRuntimeConfigTests: XCTestCase {

    /// Records every value pushed to the runtime + every diagnostic line. Thread-safe (the seam is locked).
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private(set) var sinks: [Int] = []
        private(set) var logs: [String] = []
        func sink(_ b: Int) { lock.lock(); sinks.append(b); lock.unlock() }
        func log(_ s: String) { lock.lock(); logs.append(s); lock.unlock() }
    }

    private func makeConfig() -> (MLXRuntimeConfig, Recorder) {
        let rec = Recorder()
        let cfg = MLXRuntimeConfig(sink: { rec.sink($0) }, logger: { rec.log($0) })
        return (cfg, rec)
    }

    func testFirstApplySetsTheValueAndHitsTheSink() {
        let (cfg, rec) = makeConfig()
        let r = cfg.applyCacheLimit(bytes: 512 * 1024 * 1024, precedence: .adapterDefault)
        XCTAssertEqual(r, .applied(bytes: 512 * 1024 * 1024))
        XCTAssertEqual(rec.sinks, [512 * 1024 * 1024])
        XCTAssertEqual(cfg.currentCacheLimitBytes, 512 * 1024 * 1024)
        XCTAssertTrue(rec.logs.isEmpty, "first apply is not a conflict — no diagnostic")
    }

    func testSameValueReapplyIsNoOp() {
        let (cfg, rec) = makeConfig()
        cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        let r = cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        XCTAssertEqual(r, .unchanged(bytes: 512))
        XCTAssertEqual(rec.sinks, [512], "same value must NOT re-hit the sink")
    }

    func testConflictingAdapterDefaultIsRejectedFirstWins() {
        let (cfg, rec) = makeConfig()
        cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        let r = cfg.applyCacheLimit(bytes: 768, precedence: .adapterDefault)   // a 2nd adapter, different default
        XCTAssertEqual(r, .rejectedConflict(kept: 512, ignored: 768))
        XCTAssertEqual(cfg.currentCacheLimitBytes, 512, "first default must win")
        XCTAssertEqual(rec.sinks, [512], "the rejected default must NOT touch the runtime")
        XCTAssertEqual(rec.logs.count, 1, "a conflict must be logged, never silent")
        XCTAssertTrue(rec.logs[0].contains("CONFLICT"))
    }

    func testExplicitOverrideWinsAndIsLogged() {
        let (cfg, rec) = makeConfig()
        cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        let r = cfg.applyCacheLimit(bytes: 384, precedence: .explicitOverride) // e.g. BAS_MLX_CACHE_LIMIT_MB
        XCTAssertEqual(r, .overrodeConflict(from: 512, to: 384))
        XCTAssertEqual(cfg.currentCacheLimitBytes, 384, "explicit override must win (last write)")
        XCTAssertEqual(rec.sinks, [512, 384], "the override must reach the runtime")
        XCTAssertEqual(rec.logs.count, 1)
        XCTAssertTrue(rec.logs[0].contains("OVERRIDE"))
    }

    func testOverrideThenConflictingDefaultStillRejected() {
        // After an explicit override, a later adapter default that differs is still rejected (override holds).
        let (cfg, rec) = makeConfig()
        cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        cfg.applyCacheLimit(bytes: 384, precedence: .explicitOverride)
        let r = cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        XCTAssertEqual(r, .rejectedConflict(kept: 384, ignored: 512))
        XCTAssertEqual(cfg.currentCacheLimitBytes, 384)
        XCTAssertEqual(rec.sinks, [512, 384], "no further runtime writes after the override")
    }

    func testProductionSingletonExists() {
        // The production seam exists + is reachable (its sink is the real gated MLX.Memory writer — NOT
        // invoked here, so no metallib load). Just prove the accessor doesn't trap.
        XCTAssertNotNil(MLXRuntimeConfig.shared)
    }
}
