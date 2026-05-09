// MARK: - BASBundleIDProtocol — chapter 四百五 / M981 — 系统熵
//
// Phase 2 entropy chapter 四百五 entry:typed superset protocol
// for bundle types that carry stable bundleID + schemaVersion
// but lack a `recordedAt` timestamp。M960 BASBundleProtocol
// requires `recordedAt: Date` — that excludes 18 of the 20
// concrete *Bundle types in the substrate (only BASMemoryBundle
// has a natural timestamp via `retrievedAt`)。
//
// `BASBundleIDProtocol` ships the smaller-surface superset:
//
//   - bundleID: String (stable identity)
//   - schemaVersion: String (chapter 一百三 schema-versioning)
//
// Bundles without timestamps (BASStepBundle / BASLearningExport
// Bundle / BASCounterfactualBundle / BASCritiqueBundle / etc.)
// adopt this protocol。Bundles with timestamps
// (BASMemoryBundle) remain on `BASBundleProtocol`。
//
// chapter 四百五 v1 ships the protocol + 2 initial concrete
// adoptions (BASStepBundle + BASLearningExportBundle in M982)。
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四 doctrine pins
//   - chapter 二百一一 single-source-of-truth — TWO
//     bundle protocols (with/without timestamp) instead of
//     forcing all bundles into one shape
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Smaller-surface bundle protocol requiring only bundleID +
/// schemaVersion。Bundles without timestamp fields opt into
/// this protocol;bundles with timestamps opt into the larger
/// `BASBundleProtocol`(which inherits from this one for
/// shared metadata access)。
public protocol BASBundleIDProtocol: Sendable {

    /// Stable bundle identifier。
    var bundleID: String { get }

    /// Schema version per chapter 一百三 schema-versioning。
    var schemaVersion: String { get }
}
