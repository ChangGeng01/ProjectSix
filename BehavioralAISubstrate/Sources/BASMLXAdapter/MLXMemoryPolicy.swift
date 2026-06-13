import Foundation

/// Cohesive grouping of the six flat memory/cache/KV/admission opt-in knobs that used to be loose parameters on
/// `MLXOrganAdapter.init`. A value type so a host configures memory in ONE place instead of threading six
/// parameters. **Byte-equal-off (ADR-014):** `MLXMemoryPolicy()` reproduces today's exact adapter defaults
/// field-for-field, so `MLXOrganAdapter(memoryPolicy: MLXMemoryPolicy())` == the bare `MLXOrganAdapter()`.
public struct MLXMemoryPolicy: Sendable, Equatable {

    /// MLX free-buffer pool ceiling (bytes) to apply on load, or nil to leave unbounded. The ADR-038
    /// §11.7-§11.9 wedge cap; default = the single-model 512 MB.
    public let cacheLimitBytes: Int?

    /// MLX load-time malloc ceiling (bytes) applied BEFORE the load, or nil to leave it unbounded. OPT-IN
    /// (ADR-041 §C): a too-low value throttles the load, so it stays nil until a host measures one.
    public let memoryLimitBytes: Int?

    /// OPT-IN KV-cache quantization bits (4/8). Default nil = no quantization (byte-equal); on-device A/B first.
    public let kvCacheBits: Int?

    /// OPT-IN rotating-KV token cap (enables `RotatingKVCache` when set). Default nil = unbounded `KVCacheSimple`.
    public let maxKVSize: Int?

    /// OPT-IN pre-load jetsam admission. When true, `loadModel` refuses a single-model load whose estimated
    /// peak footprint would cross the device ActiveHard cap. Default false = today's warn-only path (byte-equal).
    public let enforceMemoryAdmission: Bool

    /// The device's per-process jetsam cap for the admission check; nil = the measured iPhone Air default. Only
    /// consulted when `enforceMemoryAdmission`.
    public let activeHardCapBytes: Int?

    /// Defaults reproduce `MLXOrganAdapter`'s current init defaults VERBATIM (byte-equal-off).
    public init(
        cacheLimitBytes: Int? = BASMLXMemoryModel.defaultCacheLimitBytes,
        memoryLimitBytes: Int? = nil,
        kvCacheBits: Int? = nil,
        maxKVSize: Int? = nil,
        enforceMemoryAdmission: Bool = false,
        activeHardCapBytes: Int? = nil
    ) {
        self.cacheLimitBytes = cacheLimitBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.kvCacheBits = kvCacheBits
        self.maxKVSize = maxKVSize
        self.enforceMemoryAdmission = enforceMemoryAdmission
        self.activeHardCapBytes = activeHardCapBytes
    }
}
