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

    /// XCFramework macos-arm64 slice byte-equality
    /// SHA256。 Bumped at M2191 chapter 七百七 第一刀
    /// because the build script switched from Homebrew
    /// rustc (1.95.0) to rustup-managed stable rustc
    /// (the only path that has the iOS cross-compile
    /// targets installed)。 Reproducibility invariant
    /// preserved within the new toolchain (2 clean
    /// rebuilds yield byte-identical .a)。
    public static let macosArm64SliceSHA256: String =
        "9abcda722a4abb23b6607375004c82c62f12ff75b495e87ed69c6d1c9cd4f3aa"

    /// XCFramework ios-arm64 slice byte-equality SHA256。
    /// Captured at M2191 chapter 七百七 第一刀 during
    /// the 3-slice rebuild via the rustup-managed stable
    /// rustc toolchain。 Reproducibility verified across
    /// 2 clean rebuilds。
    public static let iosArm64SliceSHA256: String =
        "57a30761eb30bebec1666563736594d5f72e61ff09749f57509e711ddfa7aa0f"

    /// XCFramework ios-arm64-simulator slice byte-
    /// equality SHA256。 Captured at M2191 chapter 七百七
    /// 第一刀。 Reproducibility verified across 2 clean
    /// rebuilds。
    public static let iosArm64SimulatorSliceSHA256: String =
        "ed329d3fc2d60609dbda10f04226b3d2848d2e53b687bba071cd264f8f198702"

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
