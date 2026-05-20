// MARK: - BASIntegritySentinelBridge
// chapter 七百六十 第四刀 / M2454 — DEEPER LAYER-MIGRATION ARC
//
// Swift bridge for the L11 typed integrity-sentinel Rust port
// (chapter 七百六十 第一-三刀 shipped the Rust crate + C ABI +
// 100-fixture byte-equality grid)。 Exposes a typed Swift surface
// that wraps `BASSovereignIntegritySentinel.scan(_:)` AND the
// future Rust route when the XCFramework rebuild picks up
// `bas_integrity_sentinel_scan`。
//
// ## Layering note
//
// Lives in BASSovereign (same module as
// `BASSovereignIntegritySentinel`) so the V1 Swift fallback can
// call the existing actor directly without crossing module
// boundaries。 The future Rust route lands here too — when
// activated,it routes via the BASRustMemoryTrackerBinary slice
// (which is imported through the substrate's existing FFI
// surface)。
//
// ## ADR-014 OPT-IN preserved
//
// V1 live path:`BASSovereignIntegritySentinel.scan(_:)` — same
// actor that's been in production since chapter M408。 Behavior
// unchanged。 The new typed-Rust path is gated by
// `#if BAS_INTEGRITY_SENTINEL_RUST_PATH_ACTIVE`,activated by the
// next XCFramework rebuild。
//
// Per chapter 七百六十 第五刀 measurement decision:if Rust ≥3
// axes better with no >1.5× regression,this gate flips to
// production-default;else stays opt-in。

import Foundation
import BASRuntimeCore

extension BASSovereignIntegritySentinel {

    /// Typed wrapper for the scan flow that EXPOSES the same
    /// structured ScanReport as the live actor — but routes via
    /// the Rust C ABI when activated。 Currently delegates to
    /// the actor's `scan(_:)`。
    ///
    /// V1 live path:Swift actor (BASSovereignIntegritySentinel
    /// itself,already the live default for L14 integrity
    /// observations)。
    ///
    /// V2 Rust path (待 XCFramework rebuild):routes via
    /// `bas_integrity_sentinel_scan` — same Swift surface,faster
    /// scan loop + deterministic BTreeMap-ordered output。
    /// Activates when the maintainer-side
    /// `scripts/build-rust-xcframework.sh` re-runs and bundles
    /// the new symbols。
    ///
    /// chapter 七百六十 第四刀 / M2454。
    public func scanRouted(_ request: ScanRequest) async -> ScanReport {
        #if BAS_INTEGRITY_SENTINEL_RUST_PATH_ACTIVE
        // ENABLED at next XCFramework rebuild。 The build script
        // pins this define once the bas-integrity-sentinel symbols
        // are bundled。 Body kept warm so a single build-script
        // flag change activates the route without a code refactor。
        #if os(iOS) || os(macOS)
        return await scanViaRust(request)
        #else
        return await scan(request)  // watchOS fallback
        #endif
        #else
        // V1 live path:existing Swift actor — no behavior change。
        return await scan(request)
        #endif
    }

    /// Rust-routed scan path — DEACTIVATED until the XCFramework
    /// rebuild picks up `bas_integrity_sentinel_scan`。 Kept warm
    /// so the single-flag flip activates the route without a
    /// refactor。
    ///
    /// Activation patch will:
    ///   1. Snapshot trusted via `trusted` actor read
    ///   2. Encode claims + fingerprints via the LE wire format
    ///      (count u32 + per-record {id_len u16 + id + hash_len u16 + hash}
    ///      with kind u8 on claims only)
    ///   3. Call `bas_integrity_sentinel_scan` twice (probe + write)
    ///   4. Decode the LE report wire format (failed_id_count u32 +
    ///      kinds_bitmap u8 + self_mut u8 + hard_bits u16 +
    ///      per failed_id {u16 len + utf-8})
    ///   5. Re-construct ScanReport from decoded fields
    internal func scanViaRust(_ request: ScanRequest) async -> ScanReport {
        // Placeholder — activated at next XCFramework rebuild。
        // Until then,delegate to the Swift actor so the routed
        // surface stays callable + covered by tests。
        return await scan(request)
    }
}

// MARK: - Chapter 七百六十 sub-arc scorecard pin

/// Static read-only scorecard for the chapter 七百六十 sub-arc。
/// Tests cross-mirror these to catch any future drift。
public enum BASChapter760IntegritySentinelScorecard {
    public static let chapterId: String = "chapter 七百六十"
    public static let mRange: String = "M2451-M2455"
    public static let knifeCount: Int = 5

    /// Rust ABI version pinned for bas-integrity-sentinel at
    /// chapter 七百六十 第一刀 / M2451。
    public static let rustABIVersion: Int32 = 1

    /// Number of ArtifactKind variants (mirror Swift enum)。
    public static let artifactKindCount: Int = 4

    /// 100-fixture grid canonical-bytes FNV-1a 64-bit hash
    /// captured at knife 4 / M2454。 Cross-mirror with Rust pin。
    public static let fixtureGridHashHex: String =
        "0x4869961651CCEB59"

    /// Number of fixtures in the byte-equality grid。
    public static let fixtureGridSize: Int = 100

    /// Whether the Rust path is wired into the live Swift bridge。
    /// false at knife 5 (V1 Swift actor live);true once the
    /// XCFramework rebuild activates。
    public static let rustPathActive: Bool = {
        #if BAS_INTEGRITY_SENTINEL_RUST_PATH_ACTIVE
        return true
        #else
        return false
        #endif
    }()
}
