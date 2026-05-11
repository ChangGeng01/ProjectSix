// MARK: - BASMetalSubstrateCardAdoptions
// chapter 四百八十三 / M1310 — batch 3 BASCard adoptions
//
// Brings BASCard adoption count from 1 → 4:
//   - M1301 BASNeuralOpCard            (1st)
//   - M1310 BASTensorBackingKindCard   (2nd)
//   - M1310 BASAcceleratorPriorityCard (3rd)
//   - M1310 BASThermalSnapshotCard     (4th)

import Foundation
import BASRuntimeCore

/// 2nd BASCard adoption — typed tensor-backing card。
public typealias BASTensorBackingKindCard = BASCard<
    BASTensorBackingKind,
    BASKernelInvocationResultBody>

/// 3rd BASCard adoption — typed accelerator-priority card。
public typealias BASAcceleratorPriorityCard = BASCard<
    BASAcceleratorPriority,
    BASKernelInvocationResultBody>

/// 4th BASCard adoption — typed thermal-snapshot card。
public typealias BASThermalSnapshotCard = BASCard<
    BASCapabilityThermalSnapshot,
    BASKernelInvocationResultBody>
