import Foundation
#if canImport(MLX)
import MLX
#endif

/// Single, observable owner of MLX's **process-global** runtime config (today: `MLX.Memory.cacheLimit`).
///
/// WHY: `MLX.Memory.cacheLimit` is a process-global static. With each `MLXOrganAdapter` setting it on
/// `loadModel`, multiple coexisting adapters/models become a silent "last write wins" hazard — a later adapter
/// could quietly move the global cap out from under an earlier one (ADR-038 §11.8 notes this). This type
/// converges every write behind ONE seam that records the applied value, REJECTS a conflicting *adapter
/// default* (first-default-wins + a stderr diagnostic, never silent), and ALLOWS an *explicit* override
/// (e.g. the runner's `BAS_MLX_CACHE_LIMIT_MB`, which must win at runtime) — also logged.
///
/// Byte-equality: this changes only WHEN/WHETHER the buffer-pool ceiling is set, never any math → the single
/// production adapter behaves identically to before (its default applies on first load; nothing conflicts).
///
/// Testability: the actual `MLX.Memory.cacheLimit = …` side effect is injected as `sink`. On the macOS test
/// host `canImport(MLX)` is true but touching `MLX.Memory` forces a metallib load that aborts — so unit tests
/// construct an instance with a recording sink and assert the conflict bookkeeping with NO MLX dependency.
public final class MLXRuntimeConfig: @unchecked Sendable {

    /// Who is asking to set the cache limit — drives the conflict policy.
    public enum Precedence: Sendable {
        /// An adapter applying ITS default on load. A conflicting value is REJECTED (first default wins).
        case adapterDefault
        /// A deliberate caller (host env override, explicit API). A conflicting value WINS (last write).
        case explicitOverride
    }

    /// What `applyCacheLimit` did — returned so callers/tests can observe (no silent global mutation).
    public enum ApplyResult: Equatable, Sendable {
        case applied(bytes: Int)                       // first write (or re-affirming the same value newly)
        case unchanged(bytes: Int)                     // already at this value → no-op
        case rejectedConflict(kept: Int, ignored: Int) // adapterDefault differed from the in-force value
        case overrodeConflict(from: Int, to: Int)      // explicitOverride changed the in-force value
    }

    /// Production singleton — its sink writes the real process-global `MLX.Memory.cacheLimit`.
    public static let shared = MLXRuntimeConfig()

    private let lock = NSLock()
    private var appliedBytes: Int?
    private let sink: @Sendable (Int) -> Void
    private let logger: @Sendable (String) -> Void

    /// - Parameters:
    ///   - sink: applies the value to the real runtime. Defaults to `MLX.Memory.cacheLimit =` (gated).
    ///   - logger: conflict/override diagnostics. Defaults to stderr.
    public init(
        sink: @escaping @Sendable (Int) -> Void = MLXRuntimeConfig.defaultSink,
        logger: @escaping @Sendable (String) -> Void = MLXRuntimeConfig.defaultLogger
    ) {
        self.sink = sink
        self.logger = logger
    }

    /// Apply (or reject) a cache-limit value under the given precedence. Idempotent for the same value.
    @discardableResult
    public func applyCacheLimit(bytes: Int, precedence: Precedence) -> ApplyResult {
        lock.lock()
        defer { lock.unlock() }

        guard let current = appliedBytes else {
            appliedBytes = bytes
            sink(bytes)
            return .applied(bytes: bytes)
        }
        if current == bytes {
            return .unchanged(bytes: bytes)
        }
        switch precedence {
        case .explicitOverride:
            appliedBytes = bytes
            sink(bytes)
            logger("[MLXRuntimeConfig] cacheLimit OVERRIDE \(current)→\(bytes) bytes (explicit; last write wins)")
            return .overrodeConflict(from: current, to: bytes)
        case .adapterDefault:
            logger("[MLXRuntimeConfig] cacheLimit CONFLICT: keeping in-force \(current) bytes, IGNORING "
                + "adapter-default \(bytes) bytes (process-global; first default wins — pass an explicit "
                + "override to change it)")
            return .rejectedConflict(kept: current, ignored: bytes)
        }
    }

    /// The currently in-force cache-limit (nil if never set). For diagnostics / tests.
    public var currentCacheLimitBytes: Int? {
        lock.lock()
        defer { lock.unlock() }
        return appliedBytes
    }

    // MARK: - Defaults

    /// The real side effect — writes the process-global MLX cache limit (no-op when MLX is unavailable).
    public static let defaultSink: @Sendable (Int) -> Void = { bytes in
        #if canImport(MLX)
        MLX.Memory.cacheLimit = bytes
        #endif
    }

    public static let defaultLogger: @Sendable (String) -> Void = { message in
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
