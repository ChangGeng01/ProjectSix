// MARK: - BASRustCoreBridge
// chapter 七百一 / M2167 第一刀 — Rust bridge Swift
//                                  wrapper SCAFFOLD (orig)
// chapter 七百六 / M2188 第二刀 — XCFramework wired in,
//                                  ABI surface declarations
//                                  added。 Real actor
//                                  wrapper (BASRustMemory
//                                  UsageTrackerActor)
//                                  lands at M2189 第三刀
//                                  in a separate file。
//
// ## What this namespace pins
//
// Cross-doctrine refs + version constants for the chapter
// 七百六 Rust pilot。 Tests pin against these constants
// to catch ABI / scaffold drift。 The actual ABI calls
// happen in BASRustMemoryUsageTrackerActor.swift
// (M2189)。
//
// ## Module gating
//
// `import BASRustMemoryTrackerBinary` is gated to
// `#if canImport(BASRustMemoryTrackerBinary)` so the
// target compiles on watchOS (which has no XCFramework
// slice) — that branch reports the Rust path as
// unavailable rather than failing the build。

import Foundation
// M2189 第三刀 — module map added to XCFramework's
// Headers/ slice exposes `BASRustMemoryTrackerBinary`
// as a Swift-importable C module。 Platform gate
// matches Package.swift `.when(platforms: [.iOS,
// .macOS])` — on watchOS / Linux the slice is not
// shipped so the import + symbols are unavailable。
#if os(iOS) || os(macOS)
import BASRustMemoryTrackerBinary
#endif

/// Namespace for the chapter 706 Rust pilot constants
/// + ABI version probe。
public enum BASRustCoreBridge {

    /// Scaffold-version sentinel — bumped from 0 to 1 at
    /// M2188 when the XCFramework actually wired in。
    public static let scaffoldVersion: Int = 1

    /// Cross-doctrine ref to the chapter 701 scaffold
    /// + chapter 706 pilot landing。
    public static let pilotChapter: String =
        "chapter 七百六 / M2187-M2190"

    /// Swift-side ABI version pin matching the Rust-side
    /// `bas_rust_tracker_version` constant。 Bumping the
    /// Rust ABI_VERSION constant requires bumping this
    /// AND updating BASRustMemoryUsageTrackerActorTests
    /// .testRustABIVersion simultaneously。
    public static let rustABIVersion: Int32 = 1

    /// Whether the Rust XCFramework is reachable at
    /// build time on this platform。 watchOS / Linux
    /// build hosts get false (no XCFramework slice)。
    public static var isRustBridgeAvailable: Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }

    /// Live read of the Rust ABI version。 Returns nil
    /// when Rust bridge is unavailable on this platform
    /// (canImport false)。 Tests cross-mirror this
    /// against `rustABIVersion` to catch any future
    /// Rust-side bump that doesn't update the Swift pin。
    public static func liveRustABIVersion() -> Int32? {
        #if os(iOS) || os(macOS)
        return bas_rust_tracker_version()
        #else
        return nil
        #endif
    }

    /// Cargo crate semantic version pin。 Bumping the
    /// Cargo/Cargo.toml workspace.package.version
    /// requires updating this AND the corresponding
    /// test pin。
    public static let cargoCrateVersion: String = "0.1.0"

    /// Rust toolchain channel pin matching
    /// rust-toolchain.toml。 Bumping requires
    /// re-verifying the Vendor/bas-rust-binaries
    /// XCFramework reproducibility via two clean
    /// rebuilds (chapter 七百一 RED FLAG #1)。
    public static let rustToolchainChannel: String =
        "stable"

    /// XCFramework binary blob expected on-disk path
    /// (relative to repo root)。 Tests pin against this
    /// constant to catch a Vendor/ rename。
    public static let xcframeworkVendorPath: String =
        "Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework"

    /// XCFramework slices currently shipped。 At M2191
    /// chapter 七百七 第一刀:expanded from host-only
    /// (macos-arm64) to all 3 Apple deployment targets
    /// per chapter 七百六 / M2190 planned-future-cut。
    public static let shippedSlices: [String] = [
        "ios-arm64",
        "ios-arm64-simulator",
        "macos-arm64"
    ]

    /// XCFramework macos-arm64 slice byte-equality SHA256。
    ///
    /// History:
    ///   - M2191 chapter 七百七 第一刀: rustup toolchain switch
    ///   - chapter 七百七十三 第二刀: 12 → 20 crate bundle
    ///   - chapter 七百七十四 第一刀: 20 → 21 crate bundle
    ///     (+ bas-shadow-trial L13 Phase 2 first cut)
    ///   - "latest-languages" cut: Rust 1.95→1.96 + IPHONEOS=18.0/MACOSX=14.0
    ///     deployment-target pin (fixes the iOS sqlite3.o 26.5-vs-18.0 link
    ///     warning). Byte-equality re-verified across two clean rebuilds.
    ///   - 全面进化 T2.1a: bas-canonical-bytes ABI v2 (+1.2.0 injective
    ///     assembler `bas_canonical_bytes_assemble_v1_2` + force-link anchor)。
    ///     ALSO the first COLD-rebuild pin: the audit proved the prior pins
    ///     captured a cache-warmed clang-compiled sqlite3.o (toolchain-
    ///     sensitive);the build script now pins DEVELOPER_DIR and these
    ///     hashes are verified by TWO clean rebuilds (BAS_CLEAN_REBUILD=1)
    ///     hashing byte-identically。
    ///   - 全面进化 T2.1: bas-retrieval-ranker ABI v2
    ///     (+`bas_ranker_decayed_fuse_batch` + force-link anchor;cold ×2
    ///     byte-identical again)。
    ///   - audit M-l MED-4 (2026-07-09): +`bas_l8_vector_index_cosine_topk_
    ///     atom_ids_for_domain` (ATOMIC (atom_id, score) top-k, closes the
    ///     rowid-reuse TOCTOU + deterministic tie-break)。 Cold ×2 byte-
    ///     identical (rustup cargo 1.96.0)。
    public static let macosArm64SliceSHA256: String =
        "71b2ac559010958c49c2aa5747125769b83157ffe0241debac449ea02632b7ab"

    /// XCFramework ios-arm64 slice byte-equality SHA256。
    /// Bumped: chapter 七百八十三 / M2566 (+atom-lifecycle); "latest-languages"
    /// cut (Rust 1.96 + iOS-18 deployment-target pin); 全面进化 T2.1a
    /// (canonical-bytes ABI v2 + cold-rebuild reproducibility pin);
    /// audit M-l MED-4 (+atomic vector topk atom_ids)。
    public static let iosArm64SliceSHA256: String =
        "119f511b832bce98465831267cf9c0ebda8a1ad7c978224345305a15d25c54f6"

    /// XCFramework ios-arm64-simulator slice byte-equality
    /// SHA256。 Bumped: chapter 七百八十三 / M2566; "latest-languages" cut;
    /// 全面进化 T2.1a (canonical-bytes ABI v2 + cold-rebuild pin);
    /// audit M-l MED-4 (+atomic vector topk atom_ids)。
    public static let iosArm64SimulatorSliceSHA256: String =
        "1f5f1f725e2f49605fc1175f8533dd24f6b2a1c102268550c470a8de2eb14fa8"

    /// Total per-slice SHA256 count = shippedSlices
    /// .count。 Cross-mirror invariant pinned in tests
    /// so a future commit that adds a new slice must
    /// also add the corresponding SHA pin。
    public static let sliceSHA256Count: Int = 3

    /// Whether the Rust pilot is fully iOS-deployable
    /// (both iOS device + simulator slices present)。
    /// Toggles automatically with the shippedSlices
    /// composition — anti-drift test pins True here so
    /// a future revert to host-only fails CI。
    public static var isIOSDeployable: Bool {
        return shippedSlices.contains("ios-arm64")
            && shippedSlices.contains(
                "ios-arm64-simulator")
    }
}
