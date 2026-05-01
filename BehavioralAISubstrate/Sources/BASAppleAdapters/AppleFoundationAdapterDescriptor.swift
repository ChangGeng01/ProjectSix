import Foundation

// 五十八.4 — typed descriptor for Apple Foundation Models
// `.fmadapter` loading.
//
// ## Why this exists
//
// `AppleFoundationOrganAdapter` (M5) ships base AFM inference
// via `LanguageModelSession`. Apple's Adapter Training Toolkit
// (Python) outputs a `.fmadapter` artifact; loading that adapter
// at inference time is a separate doctrine layer with its own
// audit needs:
//
// 1. **Provenance binding** — the adapter file's hash + signer
//    + training-data filter version must be auditable.
// 2. **Doctrine A enforcement** — adapter training data MUST
//    have flowed through `BASWorldPriorTrainingPipelineFilter`
//    (provenance ≥ `.domainExpertReviewed`). Hosts loading an
//    unattested `.fmadapter` are violating Doctrine A.
// 3. **Hot-swap discipline** — different adapters can be hot-
//    swapped per turn (per-host specialization), but the swap
//    itself must be a typed event, not a string-keyed property.
//
// `AppleFoundationAdapterDescriptor` ship the typed shape of
// "an adapter the host wants to load". It does NOT itself
// invoke any FoundationModels API — that wiring depends on
// Apple's adapter API stability and is left for a runtime
// integration layer downstream.
//
// ## Doctrine
//
// - **Pure value type, Codable.** Descriptors can be stored,
//   serialized, audit-logged.
// - **Typed provenance hash.** `trainingProvenanceHash` is the
//   stable digest of the JSONL training corpus that produced
//   this adapter. Used to bind adapter ↔ training pipeline.
// - **Stable identifier.** `adapterID` is host-chosen but
//   stable; audit replay groups by identifier.

public struct AppleFoundationAdapterDescriptor:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable host-chosen identifier for the adapter.
    /// Convention: `"<host>.<purpose>.<version>"` —
    /// e.g. `"acme.boundary-language.v1"`.
    public let adapterID: String

    /// On-disk path to the `.fmadapter` package (or absent if
    /// the adapter is bundled / streamed).
    public let url: URL?

    /// Version tag for the adapter — separate from the AFM
    /// base model version. Hosts bump this when retraining.
    public let version: String

    /// Stable digest of the training corpus that produced
    /// this adapter. Should be the SHA256 of the JSONL the
    /// `BASWorldPriorTrainingExporter` emitted. Audit code
    /// uses this to verify the adapter binds to a specific
    /// vetted training set.
    public let trainingProvenanceHash: String

    /// Human-readable description for audit / dashboards.
    public let purpose: String

    public init(
        adapterID: String,
        url: URL? = nil,
        version: String,
        trainingProvenanceHash: String,
        purpose: String
    ) {
        self.adapterID = adapterID
        self.url = url
        self.version = version
        self.trainingProvenanceHash =
            trainingProvenanceHash
        self.purpose = purpose
    }
}

/// Typed binding state for an adapter on a running adapter
/// instance. Lifecycle:
///
/// ```
/// notLoaded → loaded → (optional) replaced(by:) → unloaded
/// ```
///
/// Pure value type — actual `LanguageModelSession(adapter:)`
/// invocation lives in a runtime integration layer that
/// depends on Apple's adapter API stability.
public enum AppleFoundationAdapterBindingState:
    Sendable, Equatable, Hashable, Codable
{
    /// No adapter is bound; base AFM model is used.
    case notLoaded

    /// Adapter `id` is bound. The actor's draft path applies
    /// the adapter when invoking `LanguageModelSession`.
    case loaded(descriptorID: String)

    /// Previous adapter `previous` was replaced by `current`
    /// at some point. Exposed for audit replay; not used by
    /// the runtime path (which always reads `current`).
    case replaced(
        previous: String, current: String)

    /// Adapter was bound and then explicitly unloaded; base
    /// AFM model is used until a new adapter binds.
    case unloaded(previous: String)
}

public extension AppleFoundationAdapterBindingState {
    /// True iff the runtime should apply an adapter at the
    /// current moment. Audit code uses this to gate
    /// training-data provenance checks.
    var isAdapterActive: Bool {
        switch self {
        case .loaded, .replaced:
            return true
        case .notLoaded, .unloaded:
            return false
        }
    }

    /// Currently active adapter ID, if any.
    var activeAdapterID: String? {
        switch self {
        case .loaded(let id):
            return id
        case .replaced(_, let current):
            return current
        case .notLoaded, .unloaded:
            return nil
        }
    }
}

/// Typed registry of available adapters keyed by `adapterID`.
/// Pure value type; serializable, hot-swappable.
public struct AppleFoundationAdapterRegistry:
    Sendable, Equatable, Hashable, Codable
{
    public private(set) var descriptors: [
        String: AppleFoundationAdapterDescriptor
    ]

    public init(
        descriptors: [
            AppleFoundationAdapterDescriptor
        ] = []
    ) {
        var map: [
            String: AppleFoundationAdapterDescriptor
        ] = [:]
        for descriptor in descriptors {
            map[descriptor.adapterID] = descriptor
        }
        self.descriptors = map
    }

    /// Add or replace a descriptor. Returns a new registry
    /// (immutable pattern).
    public func registering(
        _ descriptor: AppleFoundationAdapterDescriptor
    ) -> AppleFoundationAdapterRegistry {
        var copy = self
        copy.descriptors[descriptor.adapterID] = descriptor
        return copy
    }

    /// Remove a descriptor by ID. Returns a new registry; no-
    /// op if the ID isn't registered.
    public func removing(
        adapterID: String
    ) -> AppleFoundationAdapterRegistry {
        var copy = self
        copy.descriptors[adapterID] = nil
        return copy
    }

    /// Lookup.
    public func descriptor(
        for adapterID: String
    ) -> AppleFoundationAdapterDescriptor? {
        descriptors[adapterID]
    }

    /// Count of registered adapters.
    public var count: Int { descriptors.count }
}
