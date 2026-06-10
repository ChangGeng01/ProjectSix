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

    /// Like `makeConfig` but records the MEMORY sink + the logger (the cache sink is a no-op here).
    private func makeMemConfig() -> (MLXRuntimeConfig, Recorder) {
        let rec = Recorder()
        let cfg = MLXRuntimeConfig(
            sink: { _ in }, memorySink: { rec.sink($0) }, logger: { rec.log($0) })
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

    // MARK: - memoryLimit (ADR-041 §C — independent process-global, bounds the LOAD peak)

    func testMemoryFirstApplySetsTheValueAndHitsTheSink() {
        let (cfg, rec) = makeMemConfig()
        let r = cfg.applyMemoryLimit(bytes: 2 * 1024 * 1024 * 1024, precedence: .adapterDefault)
        XCTAssertEqual(r, .applied(bytes: 2 * 1024 * 1024 * 1024))
        XCTAssertEqual(rec.sinks, [2 * 1024 * 1024 * 1024])
        XCTAssertEqual(cfg.currentMemoryLimitBytes, 2 * 1024 * 1024 * 1024)
        XCTAssertNil(cfg.currentCacheLimitBytes, "memory + cache are independent globals")
    }

    func testMemoryConflictingAdapterDefaultIsRejectedFirstWins() {
        let (cfg, rec) = makeMemConfig()
        cfg.applyMemoryLimit(bytes: 2048, precedence: .adapterDefault)
        let r = cfg.applyMemoryLimit(bytes: 4096, precedence: .adapterDefault)
        XCTAssertEqual(r, .rejectedConflict(kept: 2048, ignored: 4096))
        XCTAssertEqual(cfg.currentMemoryLimitBytes, 2048, "first memory default must win")
        XCTAssertEqual(rec.sinks, [2048])
        XCTAssertEqual(rec.logs.count, 1)
        XCTAssertTrue(rec.logs[0].contains("memoryLimit"), "diagnostic must name memoryLimit, not cacheLimit")
        XCTAssertTrue(rec.logs[0].contains("CONFLICT"))
    }

    func testMemoryExplicitOverrideWinsAndIsLogged() {
        let (cfg, rec) = makeMemConfig()
        cfg.applyMemoryLimit(bytes: 2048, precedence: .adapterDefault)
        let r = cfg.applyMemoryLimit(bytes: 1024, precedence: .explicitOverride)
        XCTAssertEqual(r, .overrodeConflict(from: 2048, to: 1024))
        XCTAssertEqual(cfg.currentMemoryLimitBytes, 1024)
        XCTAssertEqual(rec.sinks, [2048, 1024])
        XCTAssertTrue(rec.logs[0].contains("memoryLimit"))
        XCTAssertTrue(rec.logs[0].contains("OVERRIDE"))
    }

    func testMemoryAndCacheLimitsAreIndependent() {
        let cacheRec = Recorder(); let memRec = Recorder()
        let cfg = MLXRuntimeConfig(
            sink: { cacheRec.sink($0) }, memorySink: { memRec.sink($0) }, logger: { _ in })
        cfg.applyCacheLimit(bytes: 512, precedence: .adapterDefault)
        cfg.applyMemoryLimit(bytes: 2048, precedence: .adapterDefault)
        XCTAssertEqual(cfg.currentCacheLimitBytes, 512)
        XCTAssertEqual(cfg.currentMemoryLimitBytes, 2048)
        XCTAssertEqual(cacheRec.sinks, [512], "cache sink saw only the cache value")
        XCTAssertEqual(memRec.sinks, [2048], "memory sink saw only the memory value (no cross-talk)")
    }

    func testProductionSingletonExists() {
        // The production seam exists + is reachable (its sink is the real gated MLX.Memory writer — NOT
        // invoked here, so no metallib load). Just prove the accessor doesn't trap.
        XCTAssertNotNil(MLXRuntimeConfig.shared)
    }
}
