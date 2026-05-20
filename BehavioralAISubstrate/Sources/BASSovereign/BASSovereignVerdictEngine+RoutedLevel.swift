// MARK: - BASSovereignVerdictEngine+RoutedLevel
// chapter 七百五十三 第一刀 / M2433
//
// MATURATION ARC L14 Verdict engine production swap。 Routes
// the Stage 2 + Stage 3 verdict-level computation through the
// Rust `bas_verdict_derive` port introduced at chapter 七百四十二。
//
// ## Why this exists
//
// Chapter 七百四十二 第四刀 measured Rust verdict_derive at
// **13.84× faster** than the Swift Stage 2+3 logic — the
// biggest single win of the LAYER-MIGRATION ARC。 The port
// shipped byte-equal-verified (chapter 七百四十二 第三刀:
// every (hardBits,softSignals[7],domain,evidence) input
// produces the same BASSovereignVerdictLevel rank)。
//
// Per user directive 2026-05-20 「chapter 七百五十二 (L14
// Verdict engine flip — 13.84× win) ready as next step。
// 也一起 解决了」,this knife flips the routed path from
// opt-in to production default。
//
// ## Scope of this flip
//
// What MOVES to Rust:
//   - Stage 2:soft-signal lex-order → level
//   - Stage 3:evidence-insufficient upgrade for irreversible
//             operations → toolCut promotion
//   - Picking max(hard hit levels,soft level)
//
// What STAYS in Swift:
//   - Stage 1:`evaluateHardRules` → `[HardRuleHit]`
//             (needed for `reasonCodes` + `revokedPermissions`
//              metadata that Rust does NOT return)
//   - Audit ledger append (CryptoKit + actor coordination)
//   - VerdictContext construction (host-facing surface)
//
// The hit-list is computed from Swift HardObservations BUT the
// hard-bits portion of the level CAP is computed inside Rust
// via the bitfield → max table。 We cross-check by also taking
// max(swift_hits_min_levels, rust_level) so that if Rust ever
// disagreed,Swift's hits-driven floor would surface (no
// security regression risk)。
//
// ## 5-axis decision rationale (per LAYER-MIGRATION ARC rule)
//
//   Axis 1 perf:           13.84× Rust (chapter 七百四十二 measured)
//   Axis 2 memory:         TIED (no allocations on either path)
//   Axis 3 state-machine:  TIED (both exhaustive over 8 levels)
//   Axis 4 persistence:    N/A (pure compute)
//   Axis 5 replay byte-eq: ✅ chapter 七百四十二 byte-equality test
//
//   Decision: 1 strictly-better (13.84×) + 4 TIE = NOT quite ≥3
//             strictly-better,BUT 13.84× far exceeds the
//             measurement-threshold "tier" for biggest-wins。
//             Per user explicit "13.84× win,也一起 解决了"
//             directive → FLIP DEFAULT。
//
// ## Discipline pins
//
//   - 「依旧 不删除 只 comment」 — Swift Stage 2+3 logic stays
//     as commented-out adjacent reference (per chapter 七百十六
//     `+RoutedSeal.swift` pattern)
//   - 「亏的不要硬上」 — 13.84× is decisive,not marginal
//   - ADR-014 OPT-IN — hosts can opt-OUT by setting
//     useRoutedVerdictLevel=false at startup if they need
//     the byte-pinned Swift path for any reason

import Foundation
import BASRuntimeCore

extension BASSovereignVerdictEngine {

    // MARK: - Feature flag (default-on)

    /// chapter 七百五十三 第一刀 default-on flag。
    ///
    /// Default-flip history:
    ///   chapter 七百四十二 (default `false` if it had existed) —
    ///     routed path shipped via BASAutoRouteRanker.verdictDerive
    ///     Level,measured 13.84× win,byte-equality pinned。
    ///   **chapter 七百五十三 第一刀 (default `true`) — flipped per
    ///     user directive 「13.84× win,也一起 解决了」。 Hosts
    ///     who need the Swift Stage 2+3 path can opt OUT。**
    ///
    /// Byte-equality preserved — the Rust derive produces the
    /// IDENTICAL `BASSovereignVerdictLevel` rank to the Swift
    /// 3-stage logic per chapter 七百四十二 第三刀 fixture。
    public nonisolated(unsafe) static var useRoutedVerdictLevel:
        Bool = true

    // MARK: - Routed helper

    /// Routed Stage 2+3 verdict-level derivation。 Returns the
    /// final level rank that the Swift stages WOULD produce,
    /// computed via the Rust `bas_verdict_derive` C ABI。
    ///
    /// Returns `nil` only on FFI fault (null softs / unknown
    /// domain encoding) — callers MUST fall back to the Swift
    /// path on nil。
    public static func routedDeriveLevel(
        hardObservations: HardObservations,
        softSignals: SoftSignals,
        operation: OperationDomain,
        evidenceSufficient: Bool
    ) -> BASSovereignVerdictLevel? {
        // Step 1:Marshal HardObservations → 12-bit bitfield
        let bits = BASAutoRouteRanker.verdictHardBitfield(
            artifactSignatureInvalid:
                hardObservations.artifactSignatureInvalid,
            thoughtFoldChecksumBroken:
                hardObservations.thoughtFoldChecksumBroken,
            externalSideEffectWithoutSCT:
                hardObservations.externalSideEffectWithoutSCT,
            memoryOrHostWriteBypass:
                hardObservations.memoryOrHostWriteBypass,
            hostRemovalBypassed:
                hardObservations.hostRemovalBypassed,
            policyBundleTampered:
                hardObservations.policyBundleTampered,
            unauthorizedSelfMutation:
                hardObservations.unauthorizedSelfMutation,
            irreversibleHighGSIWithoutEvidence:
                hardObservations.irreversibleHighGSIWithoutEvidence,
            runtimeUnstableInHighRisk:
                hardObservations.runtimeUnstableInHighRisk,
            riskPermitHeadConflict:
                hardObservations.riskPermitHeadConflict,
            hostAttemptsBaseBoundaryOverride:
                hardObservations.hostAttemptsBaseBoundaryOverride,
            auditAppendFailed:
                hardObservations.auditAppendFailed)

        // Step 2:Marshal SoftSignals → [Double] of 7 in §12.2 order
        let softs: [Double] = [
            softSignals.integrity,
            softSignals.privilegeViolation,
            softSignals.selfMod,
            softSignals.memoryContamination,
            softSignals.irreversibleHarm,
            softSignals.runtimeInstability,
            softSignals.manipulationIntrusion,
        ]

        // Step 3:Marshal OperationDomain → VerdictOperationDomain
        let domain: BASAutoRouteRanker.VerdictOperationDomain
        switch operation {
        case .pureInference: domain = .pureInference
        case .toolRead:      domain = .toolRead
        case .toolWrite:     domain = .toolWrite
        case .hostMutate:    domain = .hostMutate
        case .memoryPromote: domain = .memoryPromote
        case .rulePromotion: domain = .rulePromotion
        }

        // Step 4:Call into Rust
        guard let rank = BASAutoRouteRanker.verdictDeriveLevel(
            hardBits: bits,
            softSignals: softs,
            domain: domain,
            evidenceSufficient: evidenceSufficient)
        else { return nil }

        // Step 5:Unmarshal rank → BASSovereignVerdictLevel
        return Self.verdictLevelFromRank(rank)
    }

    // MARK: - Rank ↔ Level mapping

    /// Rank → level helper。 Mirrors the §11.2 promotion table:
    ///   0 = pass          1 = throttle    2 = shadowLock
    ///   3 = toolCut       4 = memoryFreeze 5 = quarantine
    ///   6 = rollback      7 = deadStop
    public static func verdictLevelFromRank(
        _ rank: Int32
    ) -> BASSovereignVerdictLevel? {
        switch rank {
        case 0: return .pass
        case 1: return .throttle
        case 2: return .shadowLock
        case 3: return .toolCut
        case 4: return .memoryFreeze
        case 5: return .quarantine
        case 6: return .rollback
        case 7: return .deadStop
        default: return nil
        }
    }
}
