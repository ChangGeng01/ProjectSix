// ADR-039 Phase 3 — the real MPSGraph-vs-raw-Metal-vs-CPU dispatch router.
//
// The observe-only classifiers (BASANEKernelEligibilityClassifier + BASThermalAwareKernelSelectionPolicy)
// already compute a pure routing PREFERENCE. This router turns that into a real dispatch decision that is
// (a) DETERMINISTIC + auditable/replay-stable (the CHOICE is a pure function of op × thermal × priority,
// recorded as a BASMetalKernelDispatchDecision), while (b) the COMPUTE behind the choice is approximate
// (BASApproxValue) and runs on-device.
//
// Determinism boundary (ADR-039): the routing CHOICE is byte-deterministic (safe to record/replay); only
// the kernel OUTPUT is non-bit-reproducible (and stays quarantined as BASApproxValue). Thermal Rule-1
// (.critical → CPU) is a real wedge-relevant branch — under thermal pressure the router declines the GPU.

import Foundation

/// An auditable, replay-stable routing decision (the deterministic CHOICE; the compute is separate).
public struct BASMetalKernelDispatchDecision: Sendable, Equatable, Codable {
    public let op: String
    public let routing: BASKernelRoutingPreference
    public let thermalState: String
    public let anePriority: String

    public init(op: String, routing: BASKernelRoutingPreference, thermalState: String, anePriority: String) {
        self.op = op
        self.routing = routing
        self.thermalState = thermalState
        self.anePriority = anePriority
    }

    /// `true` when the router declined the GPU/ANE for the CPU path (thermal-critical or fallback-required).
    public var declinedAccelerator: Bool { routing == .cpuStub }
}

public enum BASMetalKernelDispatchRouter {

    /// The deterministic routing CHOICE for an op. Pure + replay-stable. Wraps the thermal-aware policy
    /// (which itself consults the ANE-eligibility classifier) and records the inputs + output so a replay
    /// can verify the choice even though the kernel's COMPUTE is non-bit-reproducible.
    public static func decide(
        op: BASNeuralOp,
        thermalState: BASCapabilityThermalSnapshot,
        anePriority: BASAcceleratorPriority
    ) -> BASMetalKernelDispatchDecision {
        let routing = BASThermalAwareKernelSelectionPolicy.preferredRouting(
            for: op, thermalState: thermalState, anePriority: anePriority)
        return BASMetalKernelDispatchDecision(
            op: op.rawValue,
            routing: routing,
            thermalState: String(describing: thermalState),
            anePriority: String(describing: anePriority))
    }
}
