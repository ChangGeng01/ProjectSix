// MARK: - BASMetalSubstrateResultAdoptions
// chapter 四百八十三 / M1309 — batch 3 BASResult adoptions
//
// Brings BASResult adoption count from 1 → 4:
//   - M1300 BASKernelInvocationResult        (1st)
//   - M1309 BASKernelRegistryDispatchResult  (2nd — this)
//   - M1309 BASANECapabilityProbeResult      (3rd)
//   - M1309 BASSchedulerAssignmentResult     (4th)

import Foundation
import BASRuntimeCore

// MARK: - BASKernelRegistryDispatchResult

public struct BASKernelRegistryDispatchResultBody:
    Equatable, Hashable, Codable, Sendable
{
    public let dispatchedKeyCount: Int
    public let fallbackCount: Int
    public let durationMs: Int

    public init(
        dispatchedKeyCount: Int,
        fallbackCount: Int,
        durationMs: Int
    ) {
        self.dispatchedKeyCount = dispatchedKeyCount
        self.fallbackCount = fallbackCount
        self.durationMs = durationMs
    }
}

public typealias BASKernelRegistryDispatchResult =
    BASResult<BASKernelRegistryDispatchResultBody>

// MARK: - BASANECapabilityProbeResult

public struct BASANECapabilityProbeResultBody:
    Equatable, Hashable, Codable, Sendable
{
    public let priority: BASAcceleratorPriority
    public let thermalSnapshot: BASCapabilityThermalSnapshot
    public let supportedOpCount: Int

    public init(
        priority: BASAcceleratorPriority,
        thermalSnapshot: BASCapabilityThermalSnapshot,
        supportedOpCount: Int
    ) {
        self.priority = priority
        self.thermalSnapshot = thermalSnapshot
        self.supportedOpCount = supportedOpCount
    }
}

public typealias BASANECapabilityProbeResult =
    BASResult<BASANECapabilityProbeResultBody>

// MARK: - BASSchedulerAssignmentResult

public struct BASSchedulerAssignmentResultBody:
    Equatable, Hashable, Codable, Sendable
{
    public let chosenBacking: BASTensorBackingKind
    public let kernelKeyAssigned: Bool
    public let costScore: Double

    public init(
        chosenBacking: BASTensorBackingKind,
        kernelKeyAssigned: Bool,
        costScore: Double
    ) {
        self.chosenBacking = chosenBacking
        self.kernelKeyAssigned = kernelKeyAssigned
        self.costScore = costScore
    }
}

public typealias BASSchedulerAssignmentResult =
    BASResult<BASSchedulerAssignmentResultBody>
