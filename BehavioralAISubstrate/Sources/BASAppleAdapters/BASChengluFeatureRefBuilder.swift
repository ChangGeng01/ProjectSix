// MARK: - BASChengluFeatureRefBuilder — chapter 三百二二 / M809
//
// Phase F (附录 X) 第三刀:typed builder for the canonical
// pipe-separated `featureRef` string consumed by the 5 Chenglu
// adapters。Companion to chapter 三百二一's `parseBASChengluSignature
// (...)` parser — together they form a typed round-trip for the
// `BASLayerInferenceInput.featureRef` payload。
//
// Why this exists:
//   - Hosts that route prompts through the 14-layer mesh need to
//     construct a `featureRef` string from typed signature inputs
//   - Without this builder, hosts hand-code `String` interpolation
//     which silently drifts from the parser format
//   - Chapter 一百八十五 anti-magic-number doctrine: typed
//     primitives must own their string format ends-to-ends
//
// Round-trip invariant (pinned by tests):
//   ```
//   let signature: BASChengluPromptSignature = …
//   let ref = BASChengluFeatureRefBuilder.build(from: signature)
//   let parsed = parseBASChengluSignature(from: ref)!
//   parsed == signature  // typed equivalence
//   ```
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 全保 — pure value-type helper
//   - 红线 7 watcher hint only
//   - chapter 二百一一 single-source-of-truth: the parser
//     `parseBASChengluSignature(from:)` and this builder are the
//     only two entry points for `featureRef` translation
//   - chapter 一百八十五 anti-magic-number: separator constant
//     `Self.fieldSeparator` named, not inline
//   - chapter 三百二一 (M808) `parseBASChengluSignature`:
//     this is its formal inverse
//
// ## Format spec (mirrors parser at chapter 三百二一 line 188-202)
//
//   Format: `tone|domain|stake|timeframe|confidant|askShape|seed`
//   - 7 fields separated by `|`
//   - 6 categorical strings (no separator chars allowed) +
//     1 base-10 integer mutationSeed
//
// Example:
//   ```
//   "anxious|medical|critical|today|trusted-ai|question|2"
//   ```

import Foundation
import BASRuntimeCore

// MARK: - Builder namespace

/// Typed namespace for canonical `featureRef` string construction。
public enum BASChengluFeatureRefBuilder {

    /// The canonical field separator character. Cross-references
    /// `parseBASChengluSignature(from:)` (chapter 三百二一)。
    public static let fieldSeparator: String = "|"

    /// Number of fields in canonical format。Pinned by tests for
    /// drift detection。
    public static let canonicalFieldCount: Int = 7

    /// Validation predicate:does `value` contain the field
    /// separator?If true,it cannot be safely round-tripped。
    /// Hosts pass categorical values that respect this constraint
    /// (chapter 三百二一 BASChengluFeatureEncoder defines the
    /// canonical category vocabulary,none of which contain `|`)。
    public static func containsSeparator(_ value: String) -> Bool {
        value.contains(fieldSeparator)
    }

    /// Build the canonical `featureRef` string from a typed
    /// signature。Throws if any string field contains the field
    /// separator (which would break the round-trip)。
    ///
    /// - Throws: `BASChengluFeatureRefBuilderError
    ///   .fieldContainsSeparator` if any categorical field
    ///   contains the field separator character.
    public static func build(
        from signature: BASChengluPromptSignature
    ) throws -> String {
        try validateNoSeparator(
            signature.tone, fieldName: "tone")
        try validateNoSeparator(
            signature.domain, fieldName: "domain")
        try validateNoSeparator(
            signature.stake, fieldName: "stake")
        try validateNoSeparator(
            signature.timeframe, fieldName: "timeframe")
        try validateNoSeparator(
            signature.confidant, fieldName: "confidant")
        try validateNoSeparator(
            signature.askShape, fieldName: "askShape")
        return [
            signature.tone,
            signature.domain,
            signature.stake,
            signature.timeframe,
            signature.confidant,
            signature.askShape,
            String(signature.mutationSeed)
        ].joined(separator: fieldSeparator)
    }

    /// Convenience non-throwing variant that returns nil if any
    /// field contains the separator。Useful for diagnostic /
    /// best-effort paths;production callers should use
    /// `build(from:)` to surface drift。
    public static func buildOrNil(
        from signature: BASChengluPromptSignature
    ) -> String? {
        try? build(from: signature)
    }

    /// Convenience: build directly from raw fields without
    /// constructing a `BASChengluPromptSignature` first。
    public static func build(
        tone: String,
        domain: String,
        stake: String,
        timeframe: String,
        confidant: String,
        askShape: String,
        mutationSeed: Int = 0
    ) throws -> String {
        try build(
            from: BASChengluPromptSignature(
                tone: tone,
                domain: domain,
                stake: stake,
                timeframe: timeframe,
                confidant: confidant,
                askShape: askShape,
                mutationSeed: mutationSeed))
    }

    // MARK: - Private helpers

    private static func validateNoSeparator(
        _ value: String, fieldName: String
    ) throws {
        if containsSeparator(value) {
            throw BASChengluFeatureRefBuilderError
                .fieldContainsSeparator(
                    fieldName: fieldName, value: value)
        }
    }
}

// MARK: - Builder error

public enum BASChengluFeatureRefBuilderError: Error, Equatable,
    Sendable
{
    /// A categorical field contains the field separator character
    /// (`|`),which would break round-trip with the parser。
    case fieldContainsSeparator(fieldName: String, value: String)
}
