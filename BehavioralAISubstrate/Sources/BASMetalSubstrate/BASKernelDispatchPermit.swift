// MARK: - BASKernelDispatchPermit
// chapter 四百八十二 / M1304 — first REAL BASPermit<Decision>
// typealias migration in the substrate。 Closes 5-of-5
// generic primitive coverage (BASBundle ×3 + BASResult
// + BASCard + BASFrameEnvelope + BASPermit)。

import Foundation
import BASRuntimeCore

/// Typed decision discriminator for kernel-dispatch permits。
public enum BASKernelDispatchDecision:
    String, Codable, Equatable, Hashable, Sendable,
    CaseIterable
{
    case allowedGPU = "allowed-gpu"
    case allowedANE = "allowed-ane"
    case allowedCPU = "allowed-cpu"
    case deniedThermalCritical = "denied-thermal-critical"
    case deniedNoKernelRegistered = "denied-no-kernel"
}

/// FIRST real `BASPermit<Decision>` typealias migration。
/// Carries a kernel-dispatch decision + reason codes +
/// reviewer identity (typically "scheduler.hardware-aware")。
public typealias BASKernelDispatchPermit =
    BASPermit<BASKernelDispatchDecision>

extension BASPermit
    where Decision == BASKernelDispatchDecision
{
    /// Convenience accessor for the boolean "is allowed"
    /// derived from the typed decision case。
    public var isAllowed: Bool {
        switch decision {
        case .allowedGPU, .allowedANE, .allowedCPU:
            return true
        case .deniedThermalCritical,
             .deniedNoKernelRegistered:
            return false
        }
    }
}
