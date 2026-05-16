// MARK: - BASMicroStep + BASMicroStepBundle
// chapter 六百八十三 / M2109 第一刀 — Phase N opening:
//                                    additive bridge to
//                                    BASBundle<BASMicroStep>
//                                    for the BASStepBundle
//                                    microSteps slot。
//
// ## Honest Phase N scope acknowledgment
//
// The wild-rolling-meerkat plan envisioned migrating
// BASStepBundle to BASBundle<BASStep> via typealias bridge。
// At implementation time the BASStepBundle struct has 5
// non-list fields (schemaVersion + bundleID + localOnly
// + editable + confirmNodes) plus the microSteps list,
// which doesn't fit the BASBundle<Item> pattern (which
// only carries items + metadata + bundle identity)。
//
// Forcing the migration would either:
//   - Push the 5 non-list fields into BASBundle metadata
//     as String values (lossy + Codable-incompatible)
//   - Embed them into every BASStep item (massive
//     duplication + bundle-level semantics lost)
//
// Either path breaks the 17+ existing call sites on
// chapter 405 BASStepBundle (per the wild-rolling-
// meerkat plan documentation)。
//
// The HONEST migration shipped at chapter 683 / M2109 is
// ADDITIVE:
//
//   - NEW BASMicroStep typed struct wrapping the
//     individual step content (currently flat String in
//     BASStepBundle.microSteps)
//   - NEW BASMicroStepBundle = BASBundle<BASMicroStep>
//     typealias offering callers a typed sequence
//     surface
//   - BASStepBundle gains a `microStepBundle` projection
//     accessor returning BASMicroStepBundle for callers
//     that want the BASBundle-shaped surface
//
// Existing call sites continue to work unchanged。 New
// call sites can opt into the BASMicroStepBundle surface。

import Foundation

/// Typed wrapper for a single micro-step in a step bundle。
/// Replaces flat `String` micro-step representation with a
/// typed struct that can be extended (timestamp,actor,
/// rationale,etc.) without breaking the wire format。
///
/// Initial chapter 683 version carries just `content`。
/// Future fields are additive via the BASBundleProtocol
/// metadata channel。
public struct BASMicroStep:
    Equatable, Hashable, Sendable, Codable
{
    /// The micro-step content string (mirrors the
    /// pre-migration BASStepBundle.microSteps[i] type)。
    public let content: String

    public init(content: String) {
        self.content = content
    }

    /// Trimmed accessor — returns content with leading/
    /// trailing whitespace removed (matching the chapter
    /// 405 BASStepBundle.init normalization behavior on
    /// bundleID)。 Idempotent。
    public var trimmedContent: String {
        return content.trimmingCharacters(
            in: .whitespacesAndNewlines)
    }

    /// Returns true iff content is empty after trimming。
    public var isBlankAfterTrimming: Bool {
        return trimmedContent.isEmpty
    }
}

/// Typed bundle of `BASMicroStep` values via the chapter
/// 403 / M960 BASBundle<Item> generic primitive。 Use this
/// for new call sites that want the BASBundle-shaped
/// surface (count, isEmpty, metadataValue, appending,
/// withMetadata)。
///
/// Existing call sites consuming BASStepBundle.microSteps
/// continue to work unchanged。 Bridge accessor lives on
/// BASStepBundle via chapter 683 / M2109 extension。
public typealias BASMicroStepBundle =
    BASBundle<BASMicroStep>
