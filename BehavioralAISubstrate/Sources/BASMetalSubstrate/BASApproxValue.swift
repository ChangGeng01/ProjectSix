// ADR-039 — the type-level quarantine that enforces the hybrid determinism boundary.
//
// Metal (GPU) compute is non-bit-reproducible (FMA reordering, GPU scheduling) → it BREAKS the
// substrate's byte-determinism (ch883 replay-stability). The hybrid doctrine (ADR-039) ALLOWS Metal on
// the APPROXIMATE side (embedding / LLM / planning / reasoning / animation / perception) but FORBIDS it
// on the byte-deterministic spine (storage / memory-durability / event-log / replay / governance verdict).
//
// `BASApproxValue<T>` enforces that boundary IN THE TYPE SYSTEM, not just in prose: a Metal result is
// wrapped so it CANNOT be passed where a plain `T` (a spine input) is expected. The only exits are:
//   - `snapToDeterministic(...)` — an AUDITED crossing through a CPU-deterministic projection, returning
//     a `BASBoundaryCrossingRecord` so replay can prove no raw Metal value leaked into the spine; or
//   - `approximateOnly()` — the explicit "I am on the approximate side" escape hatch, which is grep-able
//     and BANNED from every spine file by `BASMetalDeterminismBoundaryTests` (a build-time tripwire).

import Foundation

/// Where an approximate value was computed — its determinism taint.
public enum BASComputeProvenance: Sendable, Equatable, Codable {
    /// Computed on the GPU (non-bit-reproducible).
    case metal(kernel: String, device: String)
    /// Computed on the CPU fallback path (deterministic, but still surfaced as approximate so callers
    /// treat both branches uniformly).
    case cpuFallback(kernel: String)

    public var didRunOnGPU: Bool {
        if case .metal = self { return true }
        return false
    }
}

/// An audited record of one Metal→deterministic boundary crossing (emitted by `snapToDeterministic`), so a
/// replay can verify that every crossing went through a deterministic snap rather than a raw Metal leak.
public struct BASBoundaryCrossingRecord: Sendable, Equatable, Codable {
    public let kernel: String
    public let provenance: BASComputeProvenance
    public let snapDescription: String

    public init(kernel: String, provenance: BASComputeProvenance, snapDescription: String) {
        self.kernel = kernel
        self.provenance = provenance
        self.snapDescription = snapDescription
    }
}

/// A Metal-tainted (non-bit-reproducible) value, quarantined from the byte-deterministic spine. There is
/// NO raw getter; the only ways out are the two methods below (ADR-039).
public struct BASApproxValue<Wrapped: Sendable>: Sendable {

    private let raw: Wrapped
    public let provenance: BASComputeProvenance

    public init(_ raw: Wrapped, provenance: BASComputeProvenance) {
        self.raw = raw
        self.provenance = provenance
    }

    /// Cross into the deterministic spine THROUGH a CPU-deterministic projection. Returns the snapped
    /// value + an audit record. `snap` MUST be a deterministic function of its input (the caller's
    /// contract) — this is the ONLY sanctioned way a Metal-derived value may influence
    /// governance / durable-write / replay.
    public func snapToDeterministic(
        kernel: String,
        snapDescription: String,
        via snap: (Wrapped) -> Wrapped
    ) -> (value: Wrapped, crossing: BASBoundaryCrossingRecord) {
        (snap(raw),
         BASBoundaryCrossingRecord(
            kernel: kernel, provenance: provenance, snapDescription: snapDescription))
    }

    /// The approximate-side escape hatch: returns the raw Metal value WITHOUT snapping. Legitimate ONLY on
    /// the approximate side (retrieval ranking / reasoning / perception). It is GREP-BANNED from every
    /// spine file by `BASMetalDeterminismBoundaryTests` — referencing it in a spine file fails the build.
    public func approximateOnly() -> Wrapped { raw }

    /// Map the wrapped value while PRESERVING the taint (the result stays quarantined). Lets the
    /// approximate side transform a Metal result without un-quarantining it.
    public func map<U: Sendable>(_ transform: (Wrapped) -> U) -> BASApproxValue<U> {
        BASApproxValue<U>(transform(raw), provenance: provenance)
    }
}
