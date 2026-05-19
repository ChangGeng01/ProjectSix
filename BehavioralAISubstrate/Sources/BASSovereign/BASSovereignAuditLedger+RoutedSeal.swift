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
    /// ADR-014 OPT-IN discipline:V1 byte-pinned CryptoKit
    /// path remains the production default until the
    /// chapter 七百十六 第四刀 perf test confirms the 5-8×
    /// speedup AND the user explicitly approves the flip。
    ///
    /// Hosts that want the routed path today can set this to
    /// `true` at host startup before constructing the ledger;
    /// the byte-equality test in Knife 1 guarantees no chain
    /// of custody is broken。
    public nonisolated(unsafe) static var useRoutedSeal: Bool
        = false

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
