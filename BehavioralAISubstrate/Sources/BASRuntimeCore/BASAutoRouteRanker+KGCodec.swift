// MARK: - BASAutoRouteRanker+KGCodec
// God-object extraction (audit ch1040, WS1): the KGCodec domain, split out of the
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

    // MARK: - L3 Knowledge Graph codec (chapter 七百四十四 第二刀 / M2392)
    //
    // LAYER-MIGRATION ARC Swift bridge for the L3 Knowledge
    // Graph V2 binary codec (Cargo/bas-event-log-codec/src/
    // knowledge_graph_codec.rs)。 Mirrors Swift BAS
    // KnowledgeNode + BASKnowledgeEdge encode/decode。
    //
    // ## ADR-014 OPT-IN preserved
    //
    // V1 Swift Codable JSON path (BASSQLiteKnowledgeGraph
    // Storage.swift) stays the live production path。 Chapter
    // 七百四十四 第三刀 adds the SQL schema migration column;
    // 第四刀 measures perf;第五刀 close-out。

    /// Returns the L3 KG codec ABI version。
    public static func kgCodecABIVersion() -> Int32 {
        #if os(iOS) || os(macOS)
        return bas_kg_codec_abi_version()
        #else
        return 0
        #endif
    }

    /// Encode a knowledge node via the Rust V2 binary codec。
    /// Returns the canonical bytes or nil on FFI fault。
    public static func kgCodecEncodeNode(
        nodeID: String,
        kindRaw: String,
        label: String,
        createdAtMs: Int64,
        payloadJson: String?
    ) -> [UInt8]? {
        #if os(iOS) || os(macOS)
        let nidB = Array(nodeID.utf8)
        let krB = Array(kindRaw.utf8)
        let lblB = Array(label.utf8)
        let plB: [UInt8]? = payloadJson.map { Array($0.utf8) }
        return runKgEncode { outBuf, outCap -> Int32 in
            nidB.withUnsafeBufferPointer { nidPtr in
                krB.withUnsafeBufferPointer { krPtr in
                    lblB.withUnsafeBufferPointer { lblPtr in
                        let nidC = nidPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        let krC = krPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        let lblC = lblPtr.baseAddress.map {
                            UnsafeRawPointer($0).assumingMemoryBound(
                                to: CChar.self) }
                        if let plB = plB {
                            return plB.withUnsafeBufferPointer { plPtr -> Int32 in
                                let plC = plPtr.baseAddress.map {
                                    UnsafeRawPointer($0).assumingMemoryBound(
                                        to: CChar.self) }
                                return bas_kg_codec_encode_node(
                                    nidC, Int32(nidB.count),
                                    krC, Int32(krB.count),
                                    lblC, Int32(lblB.count),
                                    createdAtMs,
                                    plC, Int32(plB.count),
                                    outBuf, outCap)
                            }
                        } else {
                            return bas_kg_codec_encode_node(
                                nidC, Int32(nidB.count),
                                krC, Int32(krB.count),
                                lblC, Int32(lblB.count),
                                createdAtMs,
                                nil, -1,
                                outBuf, outCap)
                        }
                    }
                }
            }
        }
        #else
        return nil
        #endif
    }

    /// Encode a knowledge edge via the Rust V2 binary codec。
    public static func kgCodecEncodeEdge(
        edgeID: String,
        fromNodeID: String,
        toNodeID: String,
        kindRaw: String,
        weight: Double,
        createdAtMs: Int64
    ) -> [UInt8]? {
        #if os(iOS) || os(macOS)
        let eidB = Array(edgeID.utf8)
        let frB = Array(fromNodeID.utf8)
        let toB = Array(toNodeID.utf8)
        let krB = Array(kindRaw.utf8)
        return runKgEncode { outBuf, outCap -> Int32 in
            eidB.withUnsafeBufferPointer { eidPtr in
                frB.withUnsafeBufferPointer { frPtr in
                    toB.withUnsafeBufferPointer { toPtr in
                        krB.withUnsafeBufferPointer { krPtr in
                            let eidC = eidPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let frC = frPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let toC = toPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            let krC = krPtr.baseAddress.map {
                                UnsafeRawPointer($0).assumingMemoryBound(
                                    to: CChar.self) }
                            return bas_kg_codec_encode_edge(
                                eidC, Int32(eidB.count),
                                frC, Int32(frB.count),
                                toC, Int32(toB.count),
                                krC, Int32(krB.count),
                                weight, createdAtMs,
                                outBuf, outCap)
                        }
                    }
                }
            }
        }
        #else
        return nil
        #endif
    }

    #if os(iOS) || os(macOS)
    /// Shared two-phase capacity-discovery driver for kg
    /// encode operations。 Caller supplies a closure that
    /// invokes the FFI with the (out_buf, out_capacity)
    /// it receives;driver handles capacity discovery +
    /// retry with the exact-sized buffer。
    private static func runKgEncode(
        _ encodeCall: (UnsafeMutablePointer<CChar>?, Int32)
            -> Int32
    ) -> [UInt8]? {
        // Phase 1:capacity discovery
        let needed = encodeCall(nil, 0)
        if needed < 0 { return nil }
        if needed == 0 { return [] }
        // Phase 2:fill exact buffer
        var buf = [CChar](
            repeating: 0, count: Int(needed))
        let wrote = buf.withUnsafeMutableBufferPointer { bp in
            return encodeCall(bp.baseAddress, Int32(bp.count))
        }
        guard wrote == needed else { return nil }
        return buf.withUnsafeBufferPointer { bp -> [UInt8] in
            return bp.baseAddress!.withMemoryRebound(
                to: UInt8.self, capacity: buf.count
            ) { up in
                return Array(UnsafeBufferPointer(
                    start: up, count: buf.count))
            }
        }
    }
    #endif
}
