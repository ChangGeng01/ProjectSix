import Foundation

/// One handle a host wires instead of four scattered governance seams. Bundles the speculation memory governor
/// (U1), the decode-liveness monitor (U3), the load-time budget/admission seam, and an injected graceful-drain
/// (U4 — `BASHostGracefulDrain` lives in BASHostKit; passed as a closure so BASMLXAdapter gains NO dependency on
/// it, adding zero module edges). HOLDS the four responsibilities — never MERGES them. The forwarders below
/// delegate to the existing pure logic; the coordinator introduces no new runtime decision.
public struct BASGovernanceCoordinator: Sendable {

    /// U1 — runtime advisory state machine for draft residency under memory pressure (between turns).
    public let governor: BASSpeculationMemoryGovernor

    /// U3 — decode stall monitor (observation-only; never cancellation).
    public let liveness: BASDecodeLivenessMonitor

    /// U4 — the host's graceful drain, injected as a closure. `BASHostGracefulDrain` is in BASHostKit and this
    /// module has no edge to it, so the host wraps it: `{ _ = await myDrain.drain() }`.
    private let drain: @Sendable () async -> Void

    public init(
        governor: BASSpeculationMemoryGovernor =
            BASSpeculationMemoryGovernor(configuration: .fromFitBudget()),
        liveness: BASDecodeLivenessMonitor,
        drain: @escaping @Sendable () async -> Void
    ) {
        self.governor = governor
        self.liveness = liveness
        self.drain = drain
    }

    /// Forward to the centralized pre-load admission check (no reimplementation).
    public func wouldExceedActiveHardCap(
        targetProviderID: String,
        capBytes: Int = BASMLXMemoryModel.resolvedActiveHardCapBytes()
            ?? BASMLXMemoryBudget.measurediPhoneAirActiveHardCapBytes
    ) -> Bool {
        BASMLXMemoryBudget.wouldExceedActiveHardCap(
            targetProviderID: targetProviderID, capBytes: capBytes)
    }

    /// Forward to the centralized load-time budget resolve, taking the grouped memory policy.
    public func resolveBudget(
        targetProviderID: String,
        draftProviderID: String?,
        policy: MLXMemoryPolicy
    ) -> BASMLXMemoryBudget {
        BASMLXMemoryBudget.resolve(
            targetProviderID: targetProviderID,
            draftProviderID: draftProviderID,
            singleCacheLimitBytes: policy.cacheLimitBytes,
            singleMemoryLimitBytes: policy.memoryLimitBytes)
    }

    /// Run the host-injected graceful drain (BASHostKit's `BASHostGracefulDrain`, wrapped by the host).
    public func drainNow() async { await drain() }
}
