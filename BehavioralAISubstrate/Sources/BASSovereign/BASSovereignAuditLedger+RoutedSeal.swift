// MARK: - BASSovereignAuditLedger+RoutedSeal
// chapter 七百十六 第二刀 / M2252
//
// Per architectural matrix「Rust:ledger/replay + integrity
// hash」 — adds an OPT-IN routed-seal path that hashes the
// canonical bytes via BASAutoRouteRanker.ledgerSeal (Rust
// sha2,5-8× faster than CryptoKit per chapter 七百十二
// 第三刀 tournament) instead of CryptoKit's
// `SHA256.hash(data:)`。
//
// The legacy `hash(_:)` private method in BASSovereignAuditLedger
// stays UNCHANGED — this knife is purely additive。 Knife 3
// will add the branching in `append()`,Knife 5 will leave
// the default OFF (ADR-014 OPT-IN preserved)。
//
// ## Byte-equality guarantee
//
// SHA256 is fully specified by NIST FIPS 180-4。 Swift
// CryptoKit's SHA256.hash + base64EncodedString and the
// Rust path (BASAutoRouteRanker.ledgerSeal → base64) both
// produce mathematically identical output。 Chapter 七百十六
// 第一刀 BASChapter716AuditLedgerByteEqualityTests pins this
// empirically across 50+ varied entry shapes + a 10-step
// chain。

import Foundation
import BASRuntimeCore

extension BASSovereignAuditLedger {

    /// chapter 七百十六 第二刀 — opt-in feature flag controlling
    /// whether `append()` uses the Rust-routed seal path。
    ///
    /// Default `false` preserves the chapter 七百十二 第四刀
    /// Default-flip history:
    ///   chapter 七百十六 (default `false`) — V1 CryptoKit
    ///     path remained default while routed path shipped
    ///     opt-in。 50-entry byte-equality test passed。
    ///   chapter 七百四十一 (perf measured 1.24× Rust win
    ///     on chain seal — Axis 1 perf strictly-better;
    ///     Axis 5 replay byte-equality already pinned;
    ///     Axis 3 state-machine guarantees TIE)。
    ///   **chapter 七百五十一 第一刀 (default flipped to
    ///     `true`) — per user directive 2026-05-20
    ///     「L14 / L11 / L10 这些 Rust port 接到真实 runtime
    ///     path」 + 5-axis rule (≥ 3 axes Rust strictly-
    ///     better AND no axis worse-by-1.5×)。 The routed
    ///     seal path is now the production default;hosts
    ///     who require the legacy CryptoKit path can opt
    ///     OUT by setting this to `false` at host startup
    ///     before constructing the ledger。**
    ///
    /// Byte-equality preserved — the Rust seal produces
    /// byte-identical chain hashes to CryptoKit per the
    /// chapter 七百十六 第一刀 50-entry test。 No chain of
    /// custody is broken by this flip。
    public nonisolated(unsafe) static var useRoutedSeal: Bool
        = true

    /// Routed seal — hashes the canonical bytes via
    /// BASAutoRouteRanker.ledgerSeal (Rust SHA256) and
    /// base64-encodes the result。 Byte-identical output to
    /// the legacy `hash(_:)` method on the actor。
    ///
    /// This is `nonisolated(unsafe)` because it does no
    /// mutation — pure function over an immutable Data input。
    public nonisolated static func hashViaAutoRouter(
        _ data: Data
    ) -> String {
        let bytes = Array(data)
        let result = BASAutoRouteRanker.ledgerSeal(bytes)
        return Data(result.value).base64EncodedString()
    }
}
