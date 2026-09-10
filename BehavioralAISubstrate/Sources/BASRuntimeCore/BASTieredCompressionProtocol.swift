// MARK: - BASTieredCompressionProtocol
// chapter 七百三十七 第二刀 / M2357
//
// Abstract protocol over the TIERED-COMPRESSION IDIOM that
// emerged organically across chapters 七百三十五 (KV cache),
// 七百三十六 (vector storage),and 七百三十七 (event log)。
//
// The pattern:
//
//   1. A typed Tier enum (CaseIterable + Codable) representing
//      each compression strategy
//   2. An Estimate struct that holds per-tier byte costs
//   3. A Selector that picks the right tier given inputs
//      (corpus size,budget,priority)
//   4. A Selection struct returned by the selector with the
//      typed tier + diagnostics
//
// This protocol formalizes the shape so future tiered surfaces
// (e.g。 audit ledger,memory atom store) can follow the same
// idiom without re-discovering it。
//
// ## Honest scope acknowledgment
//
// Swift's type system doesn't let us write a single generic
// "Tier" protocol that all 3 existing selectors conform to
// without forcing them to share a CommonRatio numeric basis。
// Since KV/Vector/EventLog have DIFFERENT priority enums
// (accuracy / recall / compatibility),we pin the SHAPE in
// this protocol family but NOT the specific decision logic。
// Each substack still owns its semantics。
//
// What this protocol DOES give us:
//   ✅ Compile-time enforcement that future tier types are
//      Codable + CaseIterable + have an asymptoticShrinkRatio
//   ✅ Documentation pin — future contributors who add a new
//      tiered surface see the idiom by example + protocol
//   ✅ Discoverable shape — searching for the protocol turns up
//      all the substrate's tiered surfaces
//
// What it DOESN'T:
//   ❌ Erase per-substack semantics (intentional — KV ≠ Vector
//      ≠ EventLog at the workload level)
//   ❌ Force runtime polymorphism (intentional — every selector
//      stays a concrete enum,Swift's exhaustiveness wins)

import Foundation

/// Protocol that ALL tier enums in the substrate's tiered-
/// compression idiom conform to。
public protocol BASTieredCompressionTier:
    RawRepresentable, Codable, Equatable, Hashable,
    Sendable, CaseIterable
    where RawValue == String
{
    /// Asymptotic memory shrink ratio vs the baseline tier
    /// (typically the first case)。 ≥ 1。0。 Used by selectors
    /// to compare tiers without re-doing the math。
    var asymptoticShrinkRatio: Double { get }
}

/// Protocol that ALL Selection structs in the tiered-
/// compression idiom conform to。 Surfaces the chosen tier +
/// byte cost + budget check + reason string。
public protocol BASTieredCompressionSelection:
    Equatable, Hashable, Sendable
{
    /// The tier type chosen by the selector (KV / Vector /
    /// EventLog enum)。 Associated type so each Selection has
    /// a typed `tier` field。
    associatedtype Tier:
        BASTieredCompressionTier

    var tier: Tier { get }
    var bytesUsed: Int { get }
    var fitsInBudget: Bool { get }
    var reason: String { get }
}

// MARK: - Conformance for the chapter 七百三十五 KV cache idiom

extension BASKVCachePrecisionTier:
    BASTieredCompressionTier
{}

extension BASKVCacheTierSelector.Selection:
    BASTieredCompressionSelection
{
    public typealias Tier = BASKVCachePrecisionTier
}

// MARK: - Conformance for the chapter 七百三十六 Vector idiom

extension BASVectorStorageTier:
    BASTieredCompressionTier
{}

extension BASVectorStorageSelector.Selection:
    BASTieredCompressionSelection
{
    public typealias Tier = BASVectorStorageTier
}

// MARK: - Conformance for the chapter 七百三十七 EventLog idiom

extension BASEventLogStorageTier:
    BASTieredCompressionTier
{}

extension BASEventLogStorageSelector.Selection:
    BASTieredCompressionSelection
{
    public typealias Tier = BASEventLogStorageTier
}

// MARK: - Doctrine namespace

/// Documentation namespace pinning the TIERED-COMPRESSION IDIOM
/// across the substrate。 Surfaces the current concrete substacks
/// + the abstract protocol shape for future contributors。
public enum BASTieredCompressionDoctrine {

    /// All concrete tier-type names registered in the substrate
    /// as of chapter 七百三十七。 Used by audit walkers to
    /// confirm the idiom doesn't sprout off-pattern siblings。
    public static let registeredTierTypes: [String] = [
        "BASKVCachePrecisionTier",
        "BASVectorStorageTier",
        "BASEventLogStorageTier",
    ]

    /// Per-substack chapter manifest。 Documentation pin for
    /// new contributors — surfaces the idiom's full lineage。
    public static let substacks:
        [(name: String, chapters: [String])] =
    [
        (name: "KV cache precision",
         chapters: [
             "chapter 七百二十六 (int8 primitives)",
             "chapter 七百二十八 (int8 KV)",
             "chapter 七百三十一 第三刀 (autoregressive drift)",
             "chapter 七百三十三 (Float16 KV)",
             "chapter 七百三十四 (unified sum-type)",
             "chapter 七百三十五 (tier selector)",
         ]),
        (name: "Vector storage",
         chapters: [
             "chapter 七百十八 (batched Float32)",
             "chapter 七百二十七 (int8 vector)",
             "chapter 七百二十九 (PQ index)",
             "chapter 七百三十一 第一刀 (PQ K-means++)",
             "chapter 七百三十六 (tier selector)",
         ]),
        (name: "Event log",
         chapters: [
             "chapter 七百二十四 (binary codec primitive)",
             "chapter 七百三十二 (SQL wiring)",
             "chapter 七百三十七 第一刀 (tier selector)",
         ]),
    ]

    /// Future-arc reminder list — surfaces where the idiom
    /// COULD apply next。 Honest scope:these aren't required,
    /// just available patterns for future work。
    public static let candidateFutureSubstacks:
        [(name: String, status: String)] =
    [
        (name: "Memory atom store compression",
         status: "could add zstd-compressed tier"),
        (name: "Audit ledger compression",
         status: "could add structured-vs-prose tier"),
        (name: "Sovereign signature storage",
         status: "could add Ed25519 vs HMAC tier"),
    ]
}
