// MARK: - BASMetalSubstratePermitAdoptions
// chapter 四百八十四 / M1313 — 3 BASPermit adoptions

import Foundation
import BASRuntimeCore

public enum BASTensorAllocationDecision:
    String, Codable, Equatable, Hashable, Sendable
{
    case allowedShared, allowedPrivate, denied
}

public enum BASCacheStorageDecision:
    String, Codable, Equatable, Hashable, Sendable
{
    case allowed, deniedMemoryBudget, deniedSessionInvalidated
}

public enum BASNeuralOpDispatchDecision:
    String, Codable, Equatable, Hashable, Sendable
{
    case allowedANE, allowedGPU, deniedThermal
}

/// 2nd BASPermit adoption。
public typealias BASTensorAllocationPermit =
    BASPermit<BASTensorAllocationDecision>

/// 3rd BASPermit adoption。
public typealias BASCacheStoragePermit =
    BASPermit<BASCacheStorageDecision>

/// 4th BASPermit adoption。
public typealias BASNeuralOpDispatchPermit =
    BASPermit<BASNeuralOpDispatchDecision>
