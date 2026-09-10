// MARK: - BASAutoRouteRanker+WireFormat
// God-object extraction (audit ch1040): the SHARED big-endian wire-format byte helpers + buffer
// codecs, used across multiple FFI-routing domains (Importance, Aggregations, …). Split out of the
// BASAutoRouteRanker junk-drawer. Pure relocation, same namespace + symbols, byte-equal. The 10
// helpers are widened `private`->`internal` ONLY because `private` does not cross files even within
// the same namespace — visibility widening, no behavior change.

import Foundation

extension BASAutoRouteRanker {

    // MARK: - Wire format helpers (chapter 七百二十三 第二刀)

    internal static func encodeRecordsBuffer(
        _ records: [BASImportanceRecord]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(4 + records.count * 40)
        appendU32BE(&buf, UInt32(records.count))
        for r in records {
            let idBytes = Array(r.atomID.utf8)
            appendU32BE(&buf, UInt32(idBytes.count))
            buf.append(contentsOf: idBytes)
            appendI64BE(&buf, r.retrievedAtMs)
            buf.append(r.helpedFlag.rawValue)
        }
        return buf
    }

    internal static func encodeTiersBuffer(
        _ tiers: [(atomID: String, tier: BASImportanceTier)]
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(4 + tiers.count * 24)
        appendU32BE(&buf, UInt32(tiers.count))
        for t in tiers {
            let idBytes = Array(t.atomID.utf8)
            appendU32BE(&buf, UInt32(idBytes.count))
            buf.append(contentsOf: idBytes)
            buf.append(t.tier.rawValue)
        }
        return buf
    }

    internal static func encodeTunablesBuffer(
        _ t: BASImportanceTunables
    ) -> [UInt8] {
        var buf: [UInt8] = []
        buf.reserveCapacity(7 * 8)
        appendF64LE(&buf, t.promoteThreshold)
        appendF64LE(&buf, t.demoteThreshold)
        appendF64LE(&buf, t.recencyHalfLifeSeconds)
        appendF64LE(&buf, t.frequencySaturation)
        appendF64LE(&buf, t.tierDecayHot)
        appendF64LE(&buf, t.tierDecayWarm)
        appendF64LE(&buf, t.tierDecayCold)
        return buf
    }

    internal static func decodeScoresBuffer(
        _ buf: [UInt8]
    ) -> [BASImportanceScore]? {
        guard buf.count >= 4 else { return nil }
        var pos = 0
        let count = Int(readU32BE(buf, pos))
        pos += 4
        var out: [BASImportanceScore] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            guard pos + 4 <= buf.count else { return nil }
            let idLen = Int(readU32BE(buf, pos))
            pos += 4
            guard pos + idLen <= buf.count else { return nil }
            let atomID = String(
                decoding: buf[pos..<pos + idLen],
                as: UTF8.self)
            pos += idLen
            guard pos + 1 <= buf.count,
                  let currentTier = BASImportanceTier(
                    rawValue: buf[pos])
            else { return nil }
            pos += 1
            guard pos + 5 * 8 <= buf.count else { return nil }
            let recency = readF64LE(buf, pos);    pos += 8
            let freq    = readF64LE(buf, pos);    pos += 8
            let helped  = readF64LE(buf, pos);    pos += 8
            let tierD   = readF64LE(buf, pos);    pos += 8
            let total   = readF64LE(buf, pos);    pos += 8
            guard pos + 1 <= buf.count,
                  let recommended = BASImportanceTier(
                    rawValue: buf[pos])
            else { return nil }
            pos += 1
            guard pos + 4 + 8 <= buf.count else { return nil }
            let recordCount = Int(readU32BE(buf, pos))
            pos += 4
            let computedAt = readI64BE(buf, pos)
            pos += 8
            out.append(BASImportanceScore(
                atomID: atomID,
                currentTier: currentTier,
                recencyComponent: recency,
                frequencyComponent: freq,
                helpedComponent: helped,
                tierDecayComponent: tierD,
                totalScore: total,
                recommendedTier: recommended,
                recordCount: recordCount,
                computedAtMs: computedAt))
        }
        return out
    }

    internal static func appendU32BE(
        _ buf: inout [UInt8], _ v: UInt32
    ) {
        buf.append(UInt8((v >> 24) & 0xff))
        buf.append(UInt8((v >> 16) & 0xff))
        buf.append(UInt8((v >>  8) & 0xff))
        buf.append(UInt8( v        & 0xff))
    }

    internal static func appendI64BE(
        _ buf: inout [UInt8], _ v: Int64
    ) {
        let u = UInt64(bitPattern: v)
        for shift in stride(from: 56, through: 0, by: -8) {
            buf.append(UInt8((u >> shift) & 0xff))
        }
    }

    internal static func appendF64LE(
        _ buf: inout [UInt8], _ v: Double
    ) {
        let bits = v.bitPattern  // host (LE on aarch64)
        for shift in stride(from: 0, through: 56, by: 8) {
            buf.append(UInt8((bits >> shift) & 0xff))
        }
    }

    internal static func readU32BE(
        _ buf: [UInt8], _ pos: Int
    ) -> UInt32 {
        return  (UInt32(buf[pos    ]) << 24)
              | (UInt32(buf[pos + 1]) << 16)
              | (UInt32(buf[pos + 2]) <<  8)
              |  UInt32(buf[pos + 3])
    }

    internal static func readI64BE(
        _ buf: [UInt8], _ pos: Int
    ) -> Int64 {
        var u: UInt64 = 0
        for i in 0..<8 {
            u = (u << 8) | UInt64(buf[pos + i])
        }
        return Int64(bitPattern: u)
    }

    internal static func readF64LE(
        _ buf: [UInt8], _ pos: Int
    ) -> Double {
        var bits: UInt64 = 0
        for i in 0..<8 {
            bits |= UInt64(buf[pos + i]) << (i * 8)
        }
        return Double(bitPattern: bits)
    }
}
