// MARK: - BASAutoRouteRanker+Verdict
// God-object extraction (audit ch1040, WS1): the Verdict domain, split out of the
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

    // MARK: - L14 Verdict Decisions (chapter 七百四十二 第二刀 / M2382)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L14 Sovereign
    // Verdict Engine pure-decision-tree port
    // (Cargo/bas-substrate-core/src/verdict_decisions.rs)。
    //
    // 12 hard rules encoded as a u16 bitfield + 7 soft
    // signal doubles + operation domain raw + evidence
    // sufficient flag → verdict level rank (0..7) in ONE
    // Rust call。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 BASSovereignVerdictEngine actor stays the live
    // production path。 Hosts opt in by calling these helpers
    // directly。 Chapter 七百四十二 第四刀 5-axis comparison
    // decides default flip (plan declared loss expected on
    // Axis 1 — tiny branchy workload)。

    /// 12 hard-rule observation flags packed into a u16
    /// bitfield。 Mirrors BASSovereignVerdictEngine
    /// .HardObservations。 Use the static
    /// `verdictHardBitfield(...)` helper to assemble。
    public struct VerdictHardBits {
        public let value: UInt16
        public init(value: UInt16) { self.value = value }
    }

    /// Assemble the hard-rule u16 bitfield from typed flags。
    /// LSB = BR-001 (artifactSignatureInvalid),bit 11 =
    /// BR-012 (auditAppendFailed)。
    public static func verdictHardBitfield(
        artifactSignatureInvalid: Bool = false,
        thoughtFoldChecksumBroken: Bool = false,
        externalSideEffectWithoutSCT: Bool = false,
        memoryOrHostWriteBypass: Bool = false,
        hostRemovalBypassed: Bool = false,
        policyBundleTampered: Bool = false,
        unauthorizedSelfMutation: Bool = false,
        irreversibleHighGSIWithoutEvidence: Bool = false,
        runtimeUnstableInHighRisk: Bool = false,
        riskPermitHeadConflict: Bool = false,
        hostAttemptsBaseBoundaryOverride: Bool = false,
        auditAppendFailed: Bool = false
    ) -> VerdictHardBits {
        var b: UInt16 = 0
        if artifactSignatureInvalid          { b |= 0x0001 }
        if thoughtFoldChecksumBroken         { b |= 0x0002 }
        if externalSideEffectWithoutSCT      { b |= 0x0004 }
        if memoryOrHostWriteBypass           { b |= 0x0008 }
        if hostRemovalBypassed               { b |= 0x0010 }
        if policyBundleTampered              { b |= 0x0020 }
        if unauthorizedSelfMutation          { b |= 0x0040 }
        if irreversibleHighGSIWithoutEvidence { b |= 0x0080 }
        if runtimeUnstableInHighRisk         { b |= 0x0100 }
        if riskPermitHeadConflict            { b |= 0x0200 }
        if hostAttemptsBaseBoundaryOverride  { b |= 0x0400 }
        if auditAppendFailed                 { b |= 0x0800 }
        return VerdictHardBits(value: b)
    }

    /// Operation domain raw values matching the Rust
    /// OperationDomain enum encoding。
    public enum VerdictOperationDomain: Int32 {
        case pureInference = 0
        case toolRead = 1
        case toolWrite = 2
        case hostMutate = 3
        case memoryPromote = 4
        case rulePromotion = 5
    }

    /// Derive the L14 verdict level via the Rust port。
    ///
    /// Returns verdict level rank (0..7) where:
    ///   0 = pass         1 = throttle    2 = shadowLock
    ///   3 = toolCut      4 = memoryFreeze 5 = quarantine
    ///   6 = rollback     7 = deadStop
    /// Returns nil on FFI fault (null softs / unknown domain)。
    public static func verdictDeriveLevel(
        hardBits: VerdictHardBits,
        softSignals: [Double],
        domain: VerdictOperationDomain,
        evidenceSufficient: Bool
    ) -> Int32? {
        #if os(iOS) || os(macOS)
        guard softSignals.count == 7 else { return nil }
        let result = softSignals.withUnsafeBufferPointer {
            sp -> Int32 in
            return bas_verdict_derive(
                hardBits.value,
                sp.baseAddress,
                domain.rawValue,
                evidenceSufficient ? 1 : 0)
        }
        if result < 0 { return nil }
        return result
        #else
        return nil
        #endif
    }

    /// Returns the bas-substrate-core verdict_decisions ABI
    /// version that the XCFramework was built against。
    public static func verdictDecisionsABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_verdict_decisions_abi_version()
        #else
        return 0
        #endif
    }

    // MARK: - L14 Token lifecycle (chapter 七百四十三 第一刀 / M2386)

    /// L14 token lifecycle status。 Mirrors Rust
    /// TokenLifecycleStatus enum encoding。 Keychain-bound
    /// signing/verification stays Swift permanently per
    /// user directive (Apple-glue layer)。
    public enum SovereignTokenLifecycleStatus: Int32 {
        case live = 0
        case expired = 1
        case revoked = 2
        case futureDated = 3
    }

    /// Decide a token's lifecycle status via the Rust bridge。
    /// `revokedAtMs == nil` encodes "not revoked"。
    public static func sovereignTokenLifecycleStatus(
        issuedAtMs: Int64,
        expiresAtMs: Int64,
        revokedAtMs: Int64?,
        nowMs: Int64
    ) -> SovereignTokenLifecycleStatus? {
        #if os(iOS) || os(macOS)
        let revoked = revokedAtMs ?? -1
        let rc = bas_sovereign_token_lifecycle_status(
            issuedAtMs, expiresAtMs, revoked, nowMs)
        return SovereignTokenLifecycleStatus(rawValue: rc)
        #else
        return nil
        #endif
    }
}
