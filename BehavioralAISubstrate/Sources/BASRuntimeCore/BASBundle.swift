// MARK: - BASBundle — chapter 四百三 / M960 — 系统熵 reduction
//
// Phase 2 entropy 第八刀:typed parametric `BASBundle<Item>`
// generic primitive for item-list bundles。Per the entropy
// audit:
//
//   > Duplication entropy: 20 *Bundle types。Many wrap
//   > collections。Could parametrize as `BASBundle<Item>` for
//   > the item-list cases。Bundles with non-array fields stay
//   > as concrete structs but conform to BASBundleProtocol。
//
// Pure additive primitive。Existing concrete bundle types
// (BASMemoryBundle,BASCognitiveOSBundle,etc.) keep their
// shapes — this is the typed slot future bundle additions
// can use instead of inventing yet-another-concrete-bundle。
//
// ## What this ships
//
//   - `BASBundle<Item: Sendable & Equatable & Codable>` generic
//     value type with bundleID + schemaVersion + items + metadata
//     + recordedAt
//   - `BASBundleProtocol` for the metadata fields shared across
//     all bundles (existing concrete bundles can opt into
//     conformance via separate extension files)
//   - Typed query helpers: `count`,`isEmpty`,`metadataValue(forKey:)`
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — bundle is observation plumbing
//   - chapter 一百八十五 anti-magic-number — schemaVersion typed
//     string
//   - chapter 三百九二 replay-determinism — generic + Equatable
//     + Codable preserve byte-stable encoding
//   - ADR-014 OPT-IN — additive primitive

import Foundation

// MARK: - Protocol

/// Shared metadata contract for bundle-shaped types。Existing
/// concrete bundles can opt into conformance to expose a
/// uniform metadata accessor surface。
public protocol BASBundleProtocol:
    Sendable, Equatable, Codable
{
    /// Stable bundle identifier (caller-supplied UUID or
    /// derived from session/turn keys)。
    var bundleID: String { get }

    /// Schema version per chapter 一百三 schema-versioning。
    var schemaVersion: String { get }

    /// Wall-clock at bundle assembly。
    var recordedAt: Date { get }
}

// MARK: - Generic

/// Typed parametric bundle wrapping a list of `Item` values
/// with shared metadata。Use this for new item-list bundles;
/// existing concrete bundles (BASMemoryBundle,etc.) keep
/// their shapes for back-compat。
public struct BASBundle<Item: Sendable & Equatable & Codable>:
    BASBundleProtocol
{
    public static var defaultSchemaVersion: String {
        "1.0.0"
    }

    public let bundleID: String
    public let schemaVersion: String
    public let items: [Item]
    public let metadata: [String: String]
    public let recordedAt: Date

    public init(
        bundleID: String = UUID().uuidString,
        schemaVersion: String =
            BASBundle<Item>.defaultSchemaVersion,
        items: [Item],
        metadata: [String: String] = [:],
        recordedAt: Date = Date()
    ) {
        self.bundleID = bundleID
        self.schemaVersion = schemaVersion
        self.items = items
        self.metadata = metadata
        self.recordedAt = recordedAt
    }

    // MARK: - Convenience accessors

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    public func metadataValue(forKey key: String) -> String? {
        metadata[key]
    }

    /// Produce a new bundle with one item appended。Pure
    /// (returns a fresh value;does not mutate `self`)。
    public func appending(item: Item) -> BASBundle<Item> {
        BASBundle(
            bundleID: bundleID,
            schemaVersion: schemaVersion,
            items: items + [item],
            metadata: metadata,
            recordedAt: recordedAt)
    }

    /// Produce a new bundle with `metadata[key]` set to
    /// `value`。Pure。
    public func withMetadata(
        _ value: String, forKey key: String
    ) -> BASBundle<Item> {
        var newMeta = metadata
        newMeta[key] = value
        return BASBundle(
            bundleID: bundleID,
            schemaVersion: schemaVersion,
            items: items,
            metadata: newMeta,
            recordedAt: recordedAt)
    }
}
