// MARK: - BASMetalSubstrateFrameEnvelopeAdoptions
// chapter 四百八十四 / M1312 — 3 BASFrameEnvelope adoptions

import Foundation
import BASRuntimeCore

/// 2nd BASFrameEnvelope adoption。
public typealias BASKernelCorrectnessTraceFrame =
    BASFrameEnvelope<BASKernelInvocationResultBody>

/// 3rd BASFrameEnvelope adoption。
public typealias BASSchedulerDecisionTraceFrame =
    BASFrameEnvelope<BASSchedulerAssignmentResultBody>

/// 4th BASFrameEnvelope adoption。
public typealias BASCacheObservationTraceFrame =
    BASFrameEnvelope<BASKernelRegistryDispatchResultBody>
