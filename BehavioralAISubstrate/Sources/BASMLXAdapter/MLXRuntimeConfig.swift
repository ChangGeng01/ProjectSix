import Foundation
#if canImport(MLX)
import MLX
#endif

/// Single, observable owner of MLX's **process-global** runtime config (`MLX.Memory.cacheLimit` +
/// `MLX.Memory.memoryLimit`).
///
/// WHY: both are process-global statics. With each `MLXOrganAdapter` setting them on `loadModel`, multiple
/// coexisting adapters/models become a silent "last write wins" hazard — a later adapter could quietly move a
/// global cap out from under an earlier one (ADR-038 §11.8 notes this). This type converges every write behind
/// ONE seam that records the applied value, REJECTS a conflicting *adapter default* (first-default-wins + a
/// stderr diagnostic, never silent), and ALLOWS an *explicit* override (e.g. the runner's
/// `BAS_MLX_CACHE_LIMIT_MB`, which must win at runtime) — also logged.
///
/// **cacheLimit vs memoryLimit:** `cacheLimit` is MLX's free-buffer *recycling* ceiling — a soft cap that can be
/// set any time (it only bounds post-load buffer reuse). `memoryLimit` is harder: once exceeded, `malloc` WAITS
/// on scheduled tasks — so it must be set BEFORE the model load to bound the **LOAD-TIME peak** (the download/
/// materialize spike), which `cacheLimit` does not. Two independent process-globals, same conflict policy.
///
/// Byte-equality: this changes only WHEN/WHETHER a ceiling is set, never any math → the single production
/// adapter behaves identically (its defaults apply on first load; nothing conflicts).
///
/// Testability: the actual `MLX.Memory.* = …` side effects are injected as sinks. On the macOS test host
/// `canImport(MLX)` is true but touching `MLX.Memory` forces a metallib load that aborts — so unit tests
/// construct an instance with recording sinks and assert the conflict bookkeeping with NO MLX dependency.
public final class MLXRuntimeConfig: @unchecked Sendable {

    /// Who is asking to set a limit — drives the conflict policy.
    public enum Precedence: Sendable {
        /// An adapter applying ITS default on load. A conflicting value is REJECTED (first default wins).
        case adapterDefault
        /// A deliberate caller (host env override, explicit API). A conflicting value WINS (last write).
        case explicitOverride
    }

    /// What an apply did — returned so callers/tests can observe (no silent global mutation).
    public enum ApplyResult: Equatable, Sendable {
        case applied(bytes: Int)                       // first write (or re-affirming the same value newly)
        case unchanged(bytes: Int)                     // already at this value → no-op
        case rejectedConflict(kept: Int, ignored: Int) // adapterDefault differed from the in-force value
        case overrodeConflict(from: Int, to: Int)      // explicitOverride changed the in-force value
    }

    /// Production singleton — its sinks write the real process-global `MLX.Memory.cacheLimit` / `.memoryLimit`.
    public static let shared = MLXRuntimeConfig()

    private let lock = NSLock()
    private var appliedBytes: Int?          // cacheLimit (free-buffer recycling ceiling)
    private var appliedMemoryBytes: Int?    // memoryLimit (load-time malloc ceiling — bounds the LOAD peak)
    private let sink: @Sendable (Int) -> Void
    private let memorySink: @Sendable (Int) -> Void
    private let logger: @Sendable (String) -> Void

    /// - Parameters:
    ///   - sink: applies the cache-limit to the real runtime. Defaults to `MLX.Memory.cacheLimit =` (gated).
    ///   - memorySink: applies the memory-limit to the real runtime. Defaults to `MLX.Memory.memoryLimit =` (gated).
    ///   - logger: conflict/override diagnostics. Defaults to stderr.
    public init(
        sink: @escaping @Sendable (Int) -> Void = MLXRuntimeConfig.defaultSink,
        memorySink: @escaping @Sendable (Int) -> Void = MLXRuntimeConfig.defaultMemorySink,
        logger: @escaping @Sendable (String) -> Void = MLXRuntimeConfig.defaultLogger
    ) {
        self.sink = sink
        self.memorySink = memorySink
        self.logger = logger
    }

    /// Apply (or reject) a **cacheLimit** value (MLX's free-buffer recycling ceiling) under the given
    /// precedence. Idempotent for the same value.
    @discardableResult
    public func applyCacheLimit(bytes: Int, precedence: Precedence) -> ApplyResult {
        lock.lock()
        defer { lock.unlock() }
        return apply(bytes: bytes, precedence: precedence,
                     current: &appliedBytes, sink: sink, label: "cacheLimit")
    }

    /// Apply (or reject) a **memoryLimit** value under the given precedence. Idempotent for the same value.
    ///
    /// `MLX.Memory.memoryLimit` makes `malloc` WAIT on scheduled tasks once exceeded — so it must be set BEFORE
    /// the model load to bound the LOAD-TIME peak (the download/materialize spike), not just post-load recycling
    /// (which is `cacheLimit`'s job). Same first-default-wins / explicit-override policy, on an independent
    /// process-global.
    @discardableResult
    public func applyMemoryLimit(bytes: Int, precedence: Precedence) -> ApplyResult {
        lock.lock()
        defer { lock.unlock() }
        return apply(bytes: bytes, precedence: precedence,
                     current: &appliedMemoryBytes, sink: memorySink, label: "memoryLimit")
    }

    /// Shared apply / reject / override bookkeeping for ONE process-global limit. Caller MUST hold `lock`.
    /// `label` ("cacheLimit" / "memoryLimit") only flavors the diagnostic strings — the policy is identical.
    private func apply(
        bytes: Int, precedence: Precedence,
        current: inout Int?, sink: @Sendable (Int) -> Void, label: String
    ) -> ApplyResult {
        guard let inForce = current else {
            current = bytes
            sink(bytes)
            return .applied(bytes: bytes)
        }
        if inForce == bytes {
            return .unchanged(bytes: bytes)
        }
        switch precedence {
        case .explicitOverride:
            current = bytes
            sink(bytes)
            logger("[MLXRuntimeConfig] \(label) OVERRIDE \(inForce)→\(bytes) bytes (explicit; last write wins)")
            return .overrodeConflict(from: inForce, to: bytes)
        case .adapterDefault:
            logger("[MLXRuntimeConfig] \(label) CONFLICT: keeping in-force \(inForce) bytes, IGNORING "
                + "adapter-default \(bytes) bytes (process-global; first default wins — pass an explicit "
                + "override to change it)")
            return .rejectedConflict(kept: inForce, ignored: bytes)
        }
    }

    /// The currently in-force cache-limit (nil if never set). For diagnostics / tests.
    public var currentCacheLimitBytes: Int? {
        lock.lock()
        defer { lock.unlock() }
        return appliedBytes
    }

    /// The currently in-force memory-limit (nil if never set). For diagnostics / tests.
    public var currentMemoryLimitBytes: Int? {
        lock.lock()
        defer { lock.unlock() }
        return appliedMemoryBytes
    }

    // MARK: - Defaults

    /// The real side effect — writes the process-global MLX cache limit (no-op when MLX is unavailable).
    public static let defaultSink: @Sendable (Int) -> Void = { bytes in
        #if canImport(MLX)
        MLX.Memory.cacheLimit = bytes
        #endif
    }

    /// The real side effect — writes the process-global MLX memory limit (no-op when MLX is unavailable).
    public static let defaultMemorySink: @Sendable (Int) -> Void = { bytes in
        #if canImport(MLX)
        MLX.Memory.memoryLimit = bytes
        #endif
    }

    public static let defaultLogger: @Sendable (String) -> Void = { message in
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
