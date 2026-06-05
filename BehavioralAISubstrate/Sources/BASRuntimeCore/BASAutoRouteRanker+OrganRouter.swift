// MARK: - BASAutoRouteRanker+OrganRouter
// God-object extraction (audit ch1040, WS1): the OrganRouter domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - L2 Organ Router (chapter 七百四十七 第一刀 / M2406)
    //
    // LAYER-MIGRATION ARC Swift bridge for L2 Neural Organ
    // adapter routing policy (Cargo/bas-organ-router/src/
    // lib.rs)。 Per user directive 「Metal/C++ 管 模型 内核,
    // Rust 管 routing/adapter policy。」

    /// Kernel family the L2 router can dispatch。
    public enum OrganRouterFamily: Int32, Sendable {
        case attention = 0
        case matMul = 1
        case layerNorm = 2
        case rmsNorm = 3
        case softmax = 4
        case activation = 5
    }

    /// Power-budget hint for L2 routing。
    public enum OrganRouterBudget: Int32, Sendable {
        case constrained = 0
        case normal = 1
        case generous = 2
    }

    /// Backend the L2 router may select。
    public enum OrganRouterBackend: Int32, Sendable {
        case cpuReference = 0
        case metalKernel = 1
        case mpsGraph = 2
        case rustSimd = 3
    }

    /// Select a kernel backend via the Rust policy port。
    /// Returns nil on FFI fault。
    public static func organRouterSelect(
        family: OrganRouterFamily,
        shapeSize: Int32,
        budget: OrganRouterBudget
    ) -> OrganRouterBackend? {
        #if os(iOS) || os(macOS)
        let rc = bas_organ_router_select(
            family.rawValue, shapeSize, budget.rawValue)
        return OrganRouterBackend(rawValue: rc)
        #else
        return nil
        #endif
    }

    /// Returns the bas-organ-router ABI version。
    public static func organRouterABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_organ_router_abi_version()
        #else
        return 0
        #endif
    }
}
