// MARK: - BASAutoRouteRanker+Sovereign
// God-object extraction (audit ch1040, WS1): the Sovereign domain, split out of the
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

    // MARK: - L14 Sovereign seal/verify (chapter 七百四十一 第二刀 / M2377)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L14 Sovereign
    // audit ledger seal/verify port。 Encapsulates the Swift
    // BASSovereignAuditLedger.canonicalBytes(for:priorHash:) +
    // hash() into a SINGLE Rust call。 No CryptoKit traversal,
    // no Data concatenation in Swift。
    //
    // Builds on chapter 七百十六 routed-seal infrastructure
    // (which routed JUST the SHA256 primitive)。 This layer
    // routes the ENTIRE seal path:canonical-byte assembly +
    // hash + return next-hash + canonical bytes for persistence。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift canonical-bytes-then-SHA256 path stays the live
    // default。 Hosts opt in by calling these helpers directly。
    // Chapter 七百四十一 第四刀 wires
    // BASSovereignAuditLedger.append() behind useRoutedSeal
    // flag (extends chapter 七百十六 ergonomics)。

    /// Sealed-entry output from bas_sovereign_seal_entry。
    public struct SovereignSealedEntry: Sendable {
        public let nextHash32: [UInt8]   // 32 bytes
        public let canonicalBytes: [UInt8]
    }

    /// Seal one L14 sovereign audit entry via the Rust bridge。
    /// Returns the next chain hash (32 bytes) + the canonical
    /// bytes that must be persisted alongside for replay verify。
    /// Returns nil on FFI fault (null pointer / capacity-mismatch
    /// after retry)。
    public static func sovereignSealEntry(
        priorHash32: [UInt8],
        auditID: String,
        sessionID: String,
        verdictRef: String,
        timestampMs: Int64,
        payload: [UInt8]
    ) -> SovereignSealedEntry? {
        #if os(iOS) || os(macOS)
        guard priorHash32.count == 32 else { return nil }
        let auditBytes = Array(auditID.utf8)
        let sessionBytes = Array(sessionID.utf8)
        let verdictBytes = Array(verdictRef.utf8)
        var nextHash = [UInt8](
            repeating: 0, count: 32)

        // Phase 1:capacity discovery
        let needed = priorHash32.withUnsafeBufferPointer {
            pp -> Int32 in
            auditBytes.withUnsafeBufferPointer { ap in
                sessionBytes.withUnsafeBufferPointer { sp in
                    verdictBytes.withUnsafeBufferPointer { vp in
                        payload.withUnsafeBufferPointer { plp in
                            nextHash.withUnsafeMutableBufferPointer {
                                hp in
                                return bas_sovereign_seal_entry(
                                    pp.baseAddress,
                                    ap.baseAddress, Int32(auditBytes.count),
                                    sp.baseAddress, Int32(sessionBytes.count),
                                    vp.baseAddress, Int32(verdictBytes.count),
                                    timestampMs,
                                    plp.baseAddress, Int32(payload.count),
                                    hp.baseAddress, nil, 0)
                            }
                        }
                    }
                }
            }
        }
        if needed < 0 { return nil }
        if needed == 0 {
            return SovereignSealedEntry(
                nextHash32: nextHash, canonicalBytes: [])
        }
        // Phase 2:fill exact-sized canonical buffer
        var canonical = [UInt8](
            repeating: 0, count: Int(needed))
        let wrote = priorHash32.withUnsafeBufferPointer {
            pp -> Int32 in
            auditBytes.withUnsafeBufferPointer { ap in
                sessionBytes.withUnsafeBufferPointer { sp in
                    verdictBytes.withUnsafeBufferPointer { vp in
                        payload.withUnsafeBufferPointer { plp in
                            nextHash.withUnsafeMutableBufferPointer {
                                hp in
                                canonical.withUnsafeMutableBufferPointer {
                                    cp in
                                    return bas_sovereign_seal_entry(
                                        pp.baseAddress,
                                        ap.baseAddress, Int32(auditBytes.count),
                                        sp.baseAddress, Int32(sessionBytes.count),
                                        vp.baseAddress, Int32(verdictBytes.count),
                                        timestampMs,
                                        plp.baseAddress, Int32(payload.count),
                                        hp.baseAddress,
                                        cp.baseAddress, Int32(cp.count))
                                }
                            }
                        }
                    }
                }
            }
        }
        guard wrote == needed else { return nil }
        return SovereignSealedEntry(
            nextHash32: nextHash, canonicalBytes: canonical)
        #else
        return nil
        #endif
    }

    /// Verify a sealed L14 chain via the Rust bridge。
    /// `entries` is a sequence of pre-computed canonical buffers
    /// (typically loaded from persistent storage)。
    /// Returns true if chain verifies,false if broken,nil on
    /// FFI fault。
    public static func sovereignVerifyChain(
        initialHash32: [UInt8],
        entries: [[UInt8]],
        expectedFinalHash32: [UInt8]
    ) -> Bool? {
        #if os(iOS) || os(macOS)
        guard initialHash32.count == 32,
              expectedFinalHash32.count == 32
        else { return nil }
        // Build the length-prefixed entries buffer:
        //   u32_be(count) || [u32_be(len) || bytes]*
        var totalLen = 4
        for e in entries { totalLen += 4 + e.count }
        var buffer = [UInt8](
            repeating: 0, count: totalLen)
        let count = UInt32(entries.count).bigEndian
        withUnsafeBytes(of: count) { ptr in
            buffer.replaceSubrange(0..<4, with: ptr)
        }
        var off = 4
        for e in entries {
            let len = UInt32(e.count).bigEndian
            withUnsafeBytes(of: len) { ptr in
                buffer.replaceSubrange(
                    off..<off + 4, with: ptr)
            }
            off += 4
            buffer.replaceSubrange(
                off..<off + e.count, with: e)
            off += e.count
        }
        let rc = initialHash32.withUnsafeBufferPointer {
            ip -> Int32 in
            buffer.withUnsafeBufferPointer { bp in
                expectedFinalHash32.withUnsafeBufferPointer {
                    ep in
                    return bas_sovereign_verify_chain(
                        ip.baseAddress,
                        bp.baseAddress, Int32(bp.count),
                        ep.baseAddress)
                }
            }
        }
        switch rc {
        case 1: return true
        case 0: return false
        default: return nil
        }
        #else
        return nil
        #endif
    }
}
