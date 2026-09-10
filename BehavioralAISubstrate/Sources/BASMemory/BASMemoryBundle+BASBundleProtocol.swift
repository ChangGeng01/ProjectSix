// MARK: - BASMemoryBundle+BASBundleProtocol
// chapter 四百四 / M964 — 系统熵 reduction
//
// Phase 2 entropy chapter 四百四 第二刀:make `BASMemoryBundle`
// conform to the M960 typed `BASBundleProtocol`,demonstrating
// the protocol adoption pattern。Future commits add similar
// conformances for the other 19 concrete *Bundle types。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit:
//
//   > Duplication entropy: 20 *Bundle types。Many wrap
//   > collections。Could parametrize as `BASBundle<Item>` for
//   > the item-list cases。Bundles with non-array fields stay
//   > as concrete structs but conform to BASBundleProtocol。
//
// `BASMemoryBundle` is one of the 20。It has bundle-shaped
// metadata (retrievalTags / retrievedAt) but doesn't expose
// a stable `bundleID`。This extension synthesizes a
// deterministic bundleID from existing fields per chapter
// 三百九二 replay-determinism。
//
// ## What this ships
//
//   - `BASMemoryBundle: BASBundleProtocol` conformance via
//     synthesized bundleID + recordedAt accessor
//   - bundleID is byte-stable (same atoms count + same
//     retrievedAt → same bundleID) — chapter 三百九二 pin
//
// ## Doctrine pins held
//
//   - All M960 + chapter 四百三 doctrine pins
//   - chapter 一百八十五 anti-magic-number — bundleID format
//     pinned as typed constant `bundleIDFormatPrefix`
//   - chapter 三百九二 — same input → same bundleID
//   - ADR-014 OPT-IN — purely additive

import Foundation
import BASRuntimeCore

extension BASMemoryBundle: BASBundleProtocol {

    /// chapter 一百八十五 anti-magic-number — bundleID prefix
    /// pinned as typed constant for grep stability。
    public static var bundleIDFormatPrefix: String {
        "memory-bundle"
    }

    /// Synthesized stable bundleID derived from existing
    /// fields。Same atom count + same retrievedAt → same
    /// bundleID (chapter 三百九二 replay-determinism)。
    public var bundleID: String {
        "\(BASMemoryBundle.bundleIDFormatPrefix):" +
        "atoms-\(atoms.count):" +
        "ts-\(retrievedAt.timeIntervalSinceReferenceDate)"
    }

    /// Map `retrievedAt` (existing field) to the
    /// `BASBundleProtocol.recordedAt` slot。
    public var recordedAt: Date {
        retrievedAt
    }
}
