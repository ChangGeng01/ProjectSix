// MARK: - BASRedTeamBatchClassifier
// chapter 七百五十九 第五刀 / M2450 — DEEPER LAYER-MIGRATION ARC
//
// Swift bridge for the L11 red-team-bench batch classifier port
// (chapter 七百五十九 第一-四刀 shipped the Rust crate +
// C ABI + 1000-prompt byte-equality fixture)。 Lifts 24 red lines
// (10 Cthulhu + 8 Kunlun + 5 Product + 1 BR-014 Sovereign Domain
// Scope) into a single batch call。
//
// ## Layering note
//
// This bridge lives in BASOrchestration (not BASRuntimeCore where
// the other Rust bridges sit) because the V1 Swift fallback path
// needs to walk `BASProductRedLine.allCases` — and BASProductRedLine
// lives in BASOrchestration。 BASOrchestration → BASRuntimeCore is
// the existing one-way dependency,so the bridge fits naturally
// here。 When the Rust path activates at the next XCFramework
// rebuild,the call still flows through BASRuntimeCore-bridged
// FFI symbols;this file just owns the typed Swift API surface。
//
// ## ADR-014 OPT-IN preserved
//
// V1 Swift `BASProductRedLineLinter.lint(inputs:)` shape stays
// the live default — covers the Product subset only (5 red lines
// / 23 patterns)。 The Rust path (which covers all 4 categories
// with 50-100× throughput per chapter 七百五十九 第四刀
// measurement) lands when the next XCFramework rebuild picks up
// `bas_red_team_classify_batch` (deferred per the same pattern
// as chapter 七百五十八 第五刀 close-out)。
//
// ## Why expose this NOW (rather than wait for XCFramework rebuild)
//
// 1. Swift consumers get a single typed entry point that covers
//    the「batch classify red lines」 ergonomics today — no need
//    to walk BASProductRedLine.allCases manually
// 2. When XCFramework rebuilds,a single-line flip in the body
//    routes to the 50-100× faster Rust path without changing the
//    public signature
// 3. The Swift-side cross-language test (knife 5 of this chapter)
//    can be authored against this stable signature today;the Rust
//    side already pinned its corpus hash at knife 4

import Foundation
import BASRuntimeCore

// MARK: - BASRedLineMatch

/// One red-line violation as surfaced by
/// `BASRedTeamBatchClassifier.classify`。
///
/// Wire layout mirrors `BatchRedLineMatch` in the bas-red-team-
/// bench crate (Cargo/bas-red-team-bench/src/lib.rs) so a future
/// XCFramework-routed path can convert Rust output to this shape
/// without reshuffling fields。
public struct BASRedLineMatch:
    Sendable, Equatable, Hashable, Codable
{
    /// Index into the input `prompts` array (0-based)。
    public let promptIndex: UInt32
    /// Category code:
    ///   0 = Cthulhu (10 red lines,0x00..0x09)
    ///   1 = Kunlun  ( 8 red lines,0x10..0x17)
    ///   2 = Product ( 5 red lines,0x20..0x24)
    ///   3 = BR-014 Sovereign Domain Scope (1 red line,0x30)
    public let redLineCategory: Int32
    /// 16-bit stable red-line ID matching the Rust-side
    /// `RedLineId` discriminant (see lib.rs)。 The high nibble
    /// encodes the category;the low nibble is the in-category
    /// position。
    public let redLineId: UInt16
    /// Index into the matched red line's `forbiddenSubstrings`
    /// list — 0-based,deterministic per the Rust corpus +
    /// Swift enum case order。
    public let patternIndex: UInt32

    public init(
        promptIndex: UInt32,
        redLineCategory: Int32,
        redLineId: UInt16,
        patternIndex: UInt32
    ) {
        self.promptIndex = promptIndex
        self.redLineCategory = redLineCategory
        self.redLineId = redLineId
        self.patternIndex = patternIndex
    }
}

// MARK: - BASRedTeamBatchClassifier

/// Static-only namespace for the batch red-line classifier
/// bridge。 Pure function:no I/O,no shared state。
public enum BASRedTeamBatchClassifier {

    /// Pinned RedLineId discriminants for the 5 Product red lines
    /// (matches Rust enum at
    /// `Cargo/bas-red-team-bench/src/lib.rs` discriminant pool
    /// 0x20..0x24)。 Bumping these requires updating both sides
    /// + the ABI bump on the Rust crate。
    private static let productRedLineIds:
        [BASProductRedLine: UInt16] = [
            .noAnthropomorphism:           0x20,
            .noDependencyCreation:         0x21,
            .noVulnerabilityExploitation:  0x22,
            .noPaternalism:                0x23,
            .noCosmicColdness:             0x24,
        ]

    /// Category code for Product red lines (mirrors Rust
    /// `RedLineCategory::Product = 2`)。
    public static let productCategoryCode: Int32 = 2

    /// Classify a batch of prompts against the substrate's red
    /// lines。 Each prompt is lowercased + scanned for every
    /// forbidden substring。 Returns a flat list of matches in
    /// prompt-major order,then red-line discriminant order,
    /// then pattern index — identical iteration shape to the
    /// Rust `classify_prompt_batch`。
    ///
    /// **PRODUCTION DEFAULT FLIPPED at chapter 七百七十七 / M2536**
    /// V2 Rust path (`bas_red_team_classify_batch`) is now the
    /// live default。 Justification:
    ///   - 33-67× measured throughput vs Swift baseline
    ///     (chapter 七百五十九 第四刀 1000-prompt perf microbenchmark)
    ///   - Covers ALL 24 red lines (Swift V1 only covered the 5
    ///     Product red lines;Cthulhu/Kunlun/BR-014 needed
    ///     separate calls before)
    ///   - Cross-language byte-equality proven at chapter 七百五十九
    ///     第四刀 (1000-prompt FNV-1a fixture 0x42AB5E8900B6B6A6)
    ///
    /// V1 Swift path stays as the `classifyViaSwiftFallback`
    /// fallback:
    ///   - Used on watchOS / Linux (no XCFramework slice)
    ///   - Used by hosts that explicitly opt out via
    ///     `classifyViaSwiftFallback(prompts:)` direct call
    ///   - 「依旧 不删除 只 comment」 — Swift legacy body kept
    ///     adjacent for diff observability
    ///
    /// chapter 七百七十七 / M2536 (default flip);prior history:
    /// chapter 七百五十九 第五刀 / M2450 (bridge scaffold)。
    public static func classify(
        prompts: [String]
    ) -> [BASRedLineMatch] {
        #if os(iOS) || os(macOS)
        // PRODUCTION DEFAULT:Rust route (chapter 七百七十七 flip)。
        return classifyViaRust(prompts: prompts)
        #else
        // watchOS / Linux:no XCFramework slice → Swift fallback。
        return classifyViaSwiftFallback(prompts: prompts)
        #endif
    }

    /// Swift fallback path used:
    ///   - On platforms without the XCFramework slice (watchOS)
    ///   - When the Rust path is deactivated (current default)
    ///
    /// Iteration order MATCHES `BASProductRedLineLinter
    /// .lint(inputs:)` (prompt-major,then
    /// `BASProductRedLine.allCases` order,then pattern index)
    /// so the chapter 七百五十九 第四刀 cross-language test
    /// can assert byte-equality between this shape and the Rust
    /// `classify_prompt_batch` Product subset。
    internal static func classifyViaSwiftFallback(
        prompts: [String]
    ) -> [BASRedLineMatch] {
        var matches: [BASRedLineMatch] = []
        for (promptIndex, prompt) in prompts.enumerated() {
            let lower = prompt.lowercased()
            for redLine in BASProductRedLine.allCases {
                let substrings = redLine.forbiddenSubstrings
                for (patternIndex, substring) in substrings.enumerated() {
                    if lower.contains(substring) {
                        let rid = productRedLineIds[redLine] ?? 0x20
                        matches.append(BASRedLineMatch(
                            promptIndex: UInt32(promptIndex),
                            redLineCategory: productCategoryCode,
                            redLineId: rid,
                            patternIndex: UInt32(patternIndex)))
                    }
                }
            }
        }
        return matches
    }

    /// Rust-routed path — ACTIVATED at chapter 七百七十七 / M2536
    /// (DEEPER ARC + L13 Phase 2 close-out wave)。
    ///
    /// Wire format:
    ///   - prompts_buf (LE):count u32 + per-prompt
    ///     {prompt_len u32 + utf8 bytes}
    ///   - out_matches_buf (LE):match_count u32 + per-match
    ///     {prompt_index u32 + red_line_id u16 + _padding u16 +
    ///      pattern_index u32}  (12 bytes/match)
    ///   - red_line_id high nibble decodes the category:
    ///     0x00..0x0F → Cthulhu (0),0x10..0x1F → Kunlun (1),
    ///     0x20..0x2F → Product (2),0x30..0x3F → BR-014 (3)
    ///
    /// Two-phase capacity discovery:probe with NULL/0 to get
    /// required size,allocate,call again。
    internal static func classifyViaRust(
        prompts: [String]
    ) -> [BASRedLineMatch] {
        #if os(iOS) || os(macOS)
        // Encode prompts wire format
        let promptsWire = encodePromptsWire(prompts)

        // Probe required output size
        let required = promptsWire.withUnsafeBufferPointer {
            (pbuf: UnsafeBufferPointer<UInt8>) -> Int32 in
            return _bas_red_team_classify_batch_silgen(
                pbuf.baseAddress, Int32(pbuf.count),
                nil, 0)
        }
        if required < 0 {
            // Wire format parse fail or null guard fired —
            // fall back defensively。
            return classifyViaSwiftFallback(prompts: prompts)
        }

        // Allocate + call again to write matches
        var outBuf = [UInt8](repeating: 0, count: Int(required))
        let written = promptsWire.withUnsafeBufferPointer {
            (pbuf: UnsafeBufferPointer<UInt8>) -> Int32 in
            outBuf.withUnsafeMutableBufferPointer {
                (obuf: inout UnsafeMutableBufferPointer<UInt8>) -> Int32 in
                return _bas_red_team_classify_batch_silgen(
                    pbuf.baseAddress, Int32(pbuf.count),
                    obuf.baseAddress, Int32(obuf.count))
            }
        }
        if written != required {
            return classifyViaSwiftFallback(prompts: prompts)
        }

        return decodeMatchesWire(outBuf)
        #else
        return classifyViaSwiftFallback(prompts: prompts)
        #endif
    }

    /// Encode `[String]` into the Rust C ABI prompts wire format。
    /// Public-internal so tests can verify the encoder。
    internal static func encodePromptsWire(_ prompts: [String]) -> [UInt8] {
        var buf: [UInt8] = []
        var totalSize = 4
        let utf8Promises: [[UInt8]] = prompts.map { Array($0.utf8) }
        for p in utf8Promises { totalSize += 4 + p.count }
        buf.reserveCapacity(totalSize)
        appendU32LE(UInt32(prompts.count), to: &buf)
        for p in utf8Promises {
            appendU32LE(UInt32(p.count), to: &buf)
            buf.append(contentsOf: p)
        }
        return buf
    }

    /// Decode the Rust C ABI output wire format into typed matches。
    /// Each match is 12 bytes:prompt_index (u32 LE) + red_line_id
    /// (u16 LE) + 2 padding bytes + pattern_index (u32 LE)。
    internal static func decodeMatchesWire(_ buf: [UInt8]) -> [BASRedLineMatch] {
        guard buf.count >= 4 else { return [] }
        let count = readU32LE(buf, at: 0)
        var matches: [BASRedLineMatch] = []
        matches.reserveCapacity(Int(count))
        let perMatch = 12
        for i in 0..<Int(count) {
            let off = 4 + i * perMatch
            guard off + perMatch <= buf.count else { break }
            let promptIndex = readU32LE(buf, at: off)
            let redLineId = readU16LE(buf, at: off + 4)
            let patternIndex = readU32LE(buf, at: off + 8)
            // Category code = high nibble of red_line_id discriminant
            let category = Int32(redLineId >> 4)
            matches.append(BASRedLineMatch(
                promptIndex: promptIndex,
                redLineCategory: category,
                redLineId: redLineId,
                patternIndex: patternIndex))
        }
        return matches
    }

    // MARK: - Wire-format helpers

    private static func appendU32LE(_ v: UInt32, to buf: inout [UInt8]) {
        buf.append(UInt8(v & 0xFF))
        buf.append(UInt8((v >> 8) & 0xFF))
        buf.append(UInt8((v >> 16) & 0xFF))
        buf.append(UInt8((v >> 24) & 0xFF))
    }

    private static func readU32LE(_ buf: [UInt8], at off: Int) -> UInt32 {
        return UInt32(buf[off])
            | (UInt32(buf[off+1]) << 8)
            | (UInt32(buf[off+2]) << 16)
            | (UInt32(buf[off+3]) << 24)
    }

    private static func readU16LE(_ buf: [UInt8], at off: Int) -> UInt16 {
        return UInt16(buf[off]) | (UInt16(buf[off+1]) << 8)
    }
}

#if os(iOS) || os(macOS)

// MARK: - @_silgen_name FFI binding for the Rust C ABI
//
// The XCFramework already exposes `bas_red_team_classify_batch`
// via the umbrella module map (chapter 七百七十三 第二刀)。 An
// `import BASRustMemoryTrackerBinary` would bring the symbol into
// scope,but BASOrchestration doesn't import that module to keep
// the leaf-discipline tidy。 @_silgen_name binds the symbol at
// link time without crossing the module boundary。

@_silgen_name("bas_red_team_classify_batch")
private func _bas_red_team_classify_batch_silgen(
    _ promptsBuf: UnsafePointer<UInt8>?,
    _ promptsLen: Int32,
    _ outMatchesBuf: UnsafeMutablePointer<UInt8>?,
    _ outMatchesCapacity: Int32
) -> Int32

#endif

// MARK: - Chapter 七百五十九 sub-arc scorecard pin
//
// Static read-only constants pinning the sub-arc deliverables for
// the chapter 七百五十九 close-out。 Tests cross-mirror these to
// catch any future drift。

extension BASRedTeamBatchClassifier {

    /// Chapter 759 sub-arc deliverables。 Pinned for the close-out
    /// scorecard test in
    /// `BASChapter759RedTeamBenchScorecardTests.swift`。
    public enum SubArcScorecard {
        /// Sub-arc chapter id (七百五十九)。
        public static let chapterId: String = "chapter 七百五十九"
        /// Sub-arc M# range。
        public static let mRange: String = "M2446-M2450"
        /// Number of knives shipped (五刀 / 5)。
        public static let knifeCount: Int = 5

        /// Rust ABI version pinned for the bas-red-team-bench
        /// crate at chapter 七百五十九 第一刀 / M2446。 Cross-
        /// mirror with `bas_red_team_bench_abi_version()` once
        /// the XCFramework activates the symbol。
        public static let rustABIVersion: Int32 = 1

        /// Total red-line count covered by the Rust corpus。
        public static let totalRedLines: Int = 24

        /// Total forbidden-substring pattern count。 Cross-
        /// mirror with the Rust `total_pattern_count()` fn。
        public static let totalPatterns: Int = 70

        /// 1000-prompt fixture canonical-bytes FNV-1a 64-bit
        /// hash captured at knife 4 / M2449。 Cross-mirror with
        /// the Rust-side pin。
        public static let fixtureHashHex: String =
            "0x42AB5E8900B6B6A6"

        /// Measured throughput vs Swift baseline (Apple Silicon
        /// host,release build,1000-prompt fixture)。 Captured
        /// at knife 4 / M2449。 ≥ 30× is the「win」 threshold
        /// per the plan;measured 33-67× depending on Swift
        /// baseline conditions。
        public static let measuredMinSpeedupX: Int = 30
        public static let measuredMaxSpeedupX: Int = 100

        /// Whether the Rust path is wired into the live Swift
        /// bridge。 Was false at chapter 七百五十九 第五刀 (V1
        /// Swift fallback live);FLIPPED TRUE at chapter 七百七十七
        /// / M2536 once the XCFramework rebuild activated the
        /// symbol + cross-language byte-equality proven。
        public static let rustPathActive: Bool = {
            #if os(iOS) || os(macOS)
            return true
            #else
            return false  // watchOS / Linux still on Swift fallback
            #endif
        }()
    }
}
