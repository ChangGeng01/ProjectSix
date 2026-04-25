import Foundation
import BASRuntimeCore

/// M218 — heterogeneous device routing for L1 budget assembly.
///
/// ## Why this exists
///
/// `BASDeviceRoute` ships 6 cases (scoutCPU / scoutGPU / scoutNPU
/// / coreGPU / coreNPU / hybridLocal) but pre-M218 nothing chose
/// among them. Production code consistently passed `.hybridLocal`
/// as a placeholder. The honesty board's L1 row noted the gap:
///
/// > 剩余 = 真机 thermal twin + 异构路由 + 长会话热稳
///
/// `BASDeviceRouting.recommend(role:thermalGuard:precisionProfile:
/// available:)` is the pure decision function that closes the
/// "异构路由" half. Given a role, current thermal guard, target
/// precision profile, and the device's available compute
/// capabilities, it returns the appropriate `BASDeviceRoute`.
///
/// ## Decision principles (in priority order)
///
/// 1. **Thermal emergency forces CPU**. When the device is in
///    `.emergency` thermal guard, ALWAYS route to `scoutCPU`,
///    regardless of role or available hardware. The CPU is the
///    coolest path; protect the device first.
/// 2. **Available hardware constrains choice**. Routes that
///    require unavailable hardware are skipped. A device without
///    ANE never gets `.scoutNPU` / `.coreNPU` recommendations.
/// 3. **Precision profile sets the floor**. `.minimal` /
///    `.balanced` accept GPU; `.protected` / `.full` prefer NPU
///    when available (more deterministic, lower energy per token
///    on Apple Silicon ANE).
/// 4. **Role gates capability tier**. `.scout` is cheap and fast,
///    suitable for any compute path. `.core` is deeper; only
///    GPU/NPU qualify for core under non-emergency thermal.
/// 5. **Fallback to CPU**. If no qualifying combination exists,
///    fall through to `scoutCPU` (always available).
public enum BASDeviceRouting {

    /// Compute capability available on the host device. Hosts pass
    /// the set they detect at boot (e.g. via `MTLDevice.shared` /
    /// `MLComputeDevice.allComputeDevices`).
    public enum Capability: String, Sendable, Equatable,
        CaseIterable, Hashable
    {
        /// CPU is always assumed available; this case is included
        /// for explicit set membership but `recommend(...)`
        /// treats CPU as the fallback regardless.
        case cpu
        case gpu
        case ane
    }

    /// Role hint matching `BASOrganRole`. Mirrored as a separate
    /// enum here so this routing module stays a leaf — no
    /// dependency on BASOrgan.
    public enum Role: String, Sendable, Equatable {
        case scout
        case core
    }

    /// Pure decision function. Input → output, no state, no I/O.
    /// Hosts call this in their L1 budget assembly path:
    ///
    /// ```swift
    /// let route = BASDeviceRouting.recommend(
    ///     role: .core,
    ///     thermalGuard: lifecycle.currentGuardLevel(),
    ///     precisionProfile: .protected,
    ///     available: [.cpu, .gpu, .ane])
    /// var budget = plannedBudget
    /// budget.deviceRoute = route
    /// ```
    public static func recommend(
        role: Role,
        thermalGuard: BASThermalGuardLevel,
        precisionProfile: BASRuntimePrecisionProfile,
        available: Set<Capability>
    ) -> BASDeviceRoute {
        // Rule 1: thermal emergency → CPU floor.
        if thermalGuard == .emergency {
            return .scoutCPU
        }

        let hasGPU = available.contains(.gpu)
        let hasANE = available.contains(.ane)

        // Rule 5 deferred fallback path (used in multiple branches)
        let cpuFallback: BASDeviceRoute = .scoutCPU

        // Throttle thermal: still allow GPU but never NPU
        // (NPU is high-throughput; under throttle we want lower-
        // power GPU instead).
        let canUseANE: Bool = {
            guard hasANE else { return false }
            return thermalGuard != .throttle
        }()

        // Precision floor: protected/full prefer NPU when
        // available; minimal/balanced accept GPU.
        let prefersNPU =
            (precisionProfile == .protected
             || precisionProfile == .full)
            && canUseANE

        switch role {
        case .core:
            // Core under non-emergency thermal: prefer NPU > GPU,
            // never CPU (core on CPU is too slow to be useful).
            if prefersNPU { return .coreNPU }
            if canUseANE && precisionProfile != .minimal {
                return .coreNPU
            }
            if hasGPU { return .coreGPU }
            // No NPU or GPU available — degrade to scout-tier
            // routing (the loop's role-downgrade protection at
            // L11 will downgrade core → scout under hybrid local
            // path).
            return .hybridLocal

        case .scout:
            // Scout can run on any path. Pick lightest.
            if prefersNPU { return .scoutNPU }
            if canUseANE && precisionProfile == .balanced {
                return .scoutNPU
            }
            if hasGPU
                && (precisionProfile == .minimal
                    || precisionProfile == .balanced)
            {
                return .scoutGPU
            }
            if hasGPU { return .scoutGPU }
            return cpuFallback
        }
    }
}
