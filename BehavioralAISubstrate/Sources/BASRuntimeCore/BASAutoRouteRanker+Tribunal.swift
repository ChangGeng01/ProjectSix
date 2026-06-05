// MARK: - BASAutoRouteRanker+Tribunal
// God-object extraction (audit ch1040, WS1): the Tribunal domain, split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal.

import Foundation
import CryptoKit
#if canImport(BASRustMemoryTrackerBinary)
import BASRustMemoryTrackerBinary
#endif
#if canImport(Darwin)
import Darwin
#endif

extension BASAutoRouteRanker {

    // MARK: - L10 Tribunal Court (chapter 七百四十 第二刀 / M2372)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L10 Tri-Self
    // Court pure-function derivation port
    // (Cargo/bas-tribunal-court/src/lib.rs)。 Mirrors the 4
    // derive factories from
    // Sources/BASOrchestration/BASTribunalFullBody.swift。
    //
    // Bulk-serialize FFI pattern (chapter 七百二十三 第二刀):
    // each derive takes a SINGLE JSON input blob and writes
    // a SINGLE JSON output blob。 Two-phase capacity
    // discovery (mirror of bpeEncode/bpeDecode ergonomics)。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift derivations (BASTribunalFullBody.swift)
    // stay the live path。 Hosts opt in by calling these
    // helpers directly。 Chapter 七百四十 第四刀 5-axis
    // comparison decides default flip。

    /// Derive id-impulse profile via Rust bridge。 Input is
    /// the JSON-encoded `{profile_id, tri_scores, candidates}`
    /// blob;output is JSON-encoded `IdImpulseProfile`。
    /// Returns nil on FFI fault (null pointer / bad JSON)。
    public static func tribunalDeriveIdProfile(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_id_profile)
        #else
        return nil
        #endif
    }

    /// Derive ego-reality assessment via Rust bridge。 Input
    /// is `{assessment_id, tri_scores, candidates, veto_marks}`
    /// JSON;output is JSON-encoded `EgoRealityAssessment`。
    public static func tribunalDeriveEgoAssessment(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_ego_assessment)
        #else
        return nil
        #endif
    }

    /// Derive superego judgment via Rust bridge。 Input is
    /// `{judgment_id, veto_marks}` JSON;output is JSON-
    /// encoded `SuperegoJudgment`。
    public static func tribunalDeriveSuperegoJudgment(
        inputJSON: String
    ) -> String? {
        #if os(iOS) || os(macOS)
        return tribunalBulkDerive(
            inputJSON: inputJSON,
            fn: bas_tribunal_court_derive_superego_judgment)
        #else
        return nil
        #endif
    }

    /// Returns the bas-tribunal-court ABI version that the
    /// XCFramework was built against。 Pure pass-through to
    /// the Rust `bas_tribunal_court_abi_version()` symbol。
    public static func tribunalCourtABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_tribunal_court_abi_version()
        #else
        return 0
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Shared two-phase capacity-discovery FFI driver for the
    /// 3 tribunal-court derivations。 Phase 1:invoke with
    /// out_capacity=0 to discover required size。 Phase 2:
    /// allocate + invoke with the exact size。
    private static func tribunalBulkDerive(
        inputJSON: String,
        fn: (UnsafePointer<CChar>?, Int32,
             UnsafeMutablePointer<CChar>?, Int32) -> Int32
    ) -> String? {
        let inputBytes = Array(inputJSON.utf8)
        // Phase 1:discover required output capacity
        let needed = inputBytes.withUnsafeBufferPointer {
            ip -> Int32 in
            return ip.baseAddress!.withMemoryRebound(
                to: CChar.self, capacity: inputBytes.count
            ) { ccp in
                return fn(ccp, Int32(inputBytes.count),
                          nil, 0)
            }
        }
        if needed < 0 { return nil }
        if needed == 0 { return "" }
        // Phase 2:fill the exact-sized output buffer
        var out = [CChar](
            repeating: 0, count: Int(needed))
        let wrote = inputBytes.withUnsafeBufferPointer {
            ip -> Int32 in
            return ip.baseAddress!.withMemoryRebound(
                to: CChar.self, capacity: inputBytes.count
            ) { ccp in
                return out.withUnsafeMutableBufferPointer {
                    op in
                    return fn(
                        ccp, Int32(inputBytes.count),
                        op.baseAddress, Int32(op.count))
                }
            }
        }
        guard wrote == needed else { return nil }
        // out is CChar (Int8) but holds UTF-8 bytes
        return out.withUnsafeBufferPointer { bp -> String? in
            return bp.baseAddress!.withMemoryRebound(
                to: UInt8.self, capacity: out.count
            ) { up in
                return String(
                    bytes: UnsafeBufferPointer(
                        start: up, count: out.count),
                    encoding: .utf8)
            }
        }
    }
    #endif
}
