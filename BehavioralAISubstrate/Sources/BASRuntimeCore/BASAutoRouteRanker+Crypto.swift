// MARK: - BASAutoRouteRanker+Crypto
// God-object extraction (audit ch1040, WS1): the Crypto domain, split out of the
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

    // MARK: - Ledger routing (chapter 七百十二 第四刀)
    //
    // Per architectural matrix「Rust owns ledger/replay +
    // integrity hash」 + tournament 七百十二 第三刀:Rust batch
    // wins at every chain depth (5-8× over CryptoKit chain,
    // 1.3× over Rust per-entry FFI)。 No crossover threshold
    // needed — always route to Rust。 Swift CryptoKit kept as
    // a fallback for non-Apple platforms where the XCFramework
    // isn't available。

    /// Outcome of a chain-verify call。 `valid` carries the
    /// final tip hash when all entries verified;
    /// `firstMismatch` is the 0-based index of the first failed
    /// entry。
    public enum BASLedgerVerifyOutcome: Sendable, Equatable {
        case valid(tipHash: [UInt8])
        case firstMismatch(index: Int)
    }

    /// One-shot ledger seal: y = SHA256(canonical)。 Matches
    /// Swift CryptoKit byte-for-byte。 Returns the 32-byte
    /// digest + the routing choice。
    public static func ledgerSeal(
        _ canonical: [UInt8]
    ) -> BASAutoRouteResult<[UInt8]> {
        var out = [UInt8](repeating: 0, count: 32)
        #if os(iOS) || os(macOS)
        let rc = canonical.withUnsafeBufferPointer { cp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_ledger_seal(
                    cp.baseAddress, canonical.count,
                    op.baseAddress)
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: out, choice: .rustLedgerSeal)
        }
        #endif
        // Fallback: Swift CryptoKit。 Bit-equal output since
        // SHA256 is fully specified by NIST FIPS 180-4。
        let d = SHA256.hash(data: Data(canonical))
        return BASAutoRouteResult(
            value: [UInt8](d),
            choice: .swiftCryptoKitLedgerSeal)
    }

    /// Batch ledger seal: for each of N records,write the
    /// 32-byte SHA256(canonical_i) into the corresponding slot
    /// of the returned [[UInt8]]。 Used by the substrate's
    /// audit-ledger append path to seal multiple entries in
    /// one FFI hop (chapter 七百十二 第三刀:1.3× over per-entry
    /// Rust at depth 256+)。
    public static func ledgerSealBatch(
        initialHash: [UInt8],
        canonicals: [[UInt8]]
    ) -> BASAutoRouteResult<[[UInt8]]> {
        precondition(initialHash.count == 32,
            "initialHash must be 32 bytes")
        guard !canonicals.isEmpty else {
            return BASAutoRouteResult(
                value: [], choice: .rustLedgerSealBatch)
        }
        #if os(iOS) || os(macOS)
        // Encode canonicals as length-prefixed flat buffer。
        var buf = Data()
        for c in canonicals {
            var lenBE = UInt32(c.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: c)
        }
        var outFlat = [UInt8](
            repeating: 0, count: canonicals.count * 32)
        let rc = initialHash.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                outFlat
                    .withUnsafeMutableBufferPointer { op in
                    bas_ranker_ledger_seal_batch(
                        ip.baseAddress,
                        bp.bindMemory(to: UInt8.self)
                            .baseAddress,
                        buf.count,
                        canonicals.count,
                        op.baseAddress)
                }
            }
        }
        if rc == 0 {
            // Slice flat buffer into [[UInt8]]。
            var hashes: [[UInt8]] = []
            hashes.reserveCapacity(canonicals.count)
            for i in 0..<canonicals.count {
                hashes.append(Array(
                    outFlat[i * 32..<(i + 1) * 32]))
            }
            return BASAutoRouteResult(
                value: hashes,
                choice: .rustLedgerSealBatch)
        }
        #endif
        // Fallback: per-entry CryptoKit
        var hashes: [[UInt8]] = []
        hashes.reserveCapacity(canonicals.count)
        for c in canonicals {
            let d = SHA256.hash(data: Data(c))
            hashes.append([UInt8](d))
        }
        return BASAutoRouteResult(
            value: hashes,
            choice: .swiftCryptoKitLedgerSeal)
    }

    /// Verify an N-entry chain。 Each record's canonical bytes
    /// are hashed and compared against the corresponding entry
    /// of `expectedSelfHashes`。 Returns the chain tip on
    /// success or the first failing index on tamper detection。
    public static func ledgerVerifyChain(
        initialHash: [UInt8],
        canonicals: [[UInt8]],
        expectedSelfHashes: [[UInt8]]
    ) -> BASAutoRouteResult<BASLedgerVerifyOutcome> {
        precondition(initialHash.count == 32,
            "initialHash must be 32 bytes")
        precondition(
            canonicals.count == expectedSelfHashes.count,
            "canonicals + expected must match length")
        guard !canonicals.isEmpty else {
            return BASAutoRouteResult(
                value: .valid(tipHash: initialHash),
                choice: .rustLedgerVerifyChain)
        }
        #if os(iOS) || os(macOS)
        var buf = Data()
        for c in canonicals {
            var lenBE = UInt32(c.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: c)
        }
        var expectedFlat = [UInt8]()
        expectedFlat.reserveCapacity(
            expectedSelfHashes.count * 32)
        for h in expectedSelfHashes {
            precondition(h.count == 32,
                "each expected hash must be 32 bytes")
            expectedFlat.append(contentsOf: h)
        }
        var outTip = [UInt8](repeating: 0, count: 32)
        let rc = initialHash.withUnsafeBufferPointer { ip in
            buf.withUnsafeBytes { bp in
                expectedFlat
                    .withUnsafeBufferPointer { ep in
                    outTip
                        .withUnsafeMutableBufferPointer { op in
                        bas_ranker_ledger_verify_chain(
                            ip.baseAddress,
                            bp.bindMemory(to: UInt8.self)
                                .baseAddress,
                            buf.count,
                            ep.baseAddress,
                            canonicals.count,
                            op.baseAddress)
                    }
                }
            }
        }
        if rc == 0 {
            return BASAutoRouteResult(
                value: .valid(tipHash: outTip),
                choice: .rustLedgerVerifyChain)
        }
        if rc > 0 {
            return BASAutoRouteResult(
                value: .firstMismatch(index: Int(rc) - 1),
                choice: .rustLedgerVerifyChain)
        }
        // rc < 0 — fall through to Swift fallback。
        #endif
        // Fallback: per-entry CryptoKit verify。
        for i in 0..<canonicals.count {
            let d = [UInt8](
                SHA256.hash(data: Data(canonicals[i])))
            if d != expectedSelfHashes[i] {
                return BASAutoRouteResult(
                    value: .firstMismatch(index: i),
                    choice: .swiftCryptoKitLedgerSeal)
            }
        }
        return BASAutoRouteResult(
            value: .valid(
                tipHash: expectedSelfHashes.last!),
            choice: .swiftCryptoKitLedgerSeal)
    }

    // MARK: - Hex encoder (chapter 七百十九 第一刀)
    //
    // Per matrix「Rust:integrity hash」 — and per chapter
    // 七百十九 measurement, Rust lookup-table hex encoder is
    // ~25× faster than Swift's `String(format: "%02x", byte)`
    // per-byte loop。 Centralized helper replaces 10+ scattered
    // Swift idiom call sites。

    /// Encode `bytes` as a lowercase hex string。 Byte-equivalent
    /// to `bytes.map { String(format: "%02x", $0) }.joined()` —
    /// pinned by BASChapter719HexEncoderTests。 Uses Rust
    /// lookup-table when the XCFramework is available;Swift
    /// fallback otherwise。
    public static func bytesToHexLower(
        _ bytes: [UInt8]
    ) -> String {
        guard !bytes.isEmpty else { return "" }
        #if os(iOS) || os(macOS)
        var out = [UInt8](
            repeating: 0, count: bytes.count * 2)
        let rc = bytes.withUnsafeBufferPointer { bp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_bytes_to_hex_lower(
                    bp.baseAddress, bytes.count,
                    op.baseAddress, op.count)
            }
        }
        if rc == 0 {
            // Output is pure ASCII so `String(decoding:as:)`
            // never fails;use `String(bytes:encoding:)` for
            // a stable failure mode just in case。
            return String(
                bytes: out, encoding: .ascii) ?? ""
        }
        #endif
        // Swift fallback — same idiom as the legacy call sites
        return bytes.map {
            String(format: "%02x", $0) }.joined()
    }

    /// Convenience overload for `Data`。
    public static func dataToHexLower(_ data: Data) -> String {
        return bytesToHexLower(Array(data))
    }

    /// chapter 七百二十一 第一刀 — Rust hex decoder。
    /// Decode lowercase or uppercase hex ASCII into bytes。
    /// Returns nil on odd length OR any non-hex character。
    /// ~40-60× faster than Swift's
    /// `hex.chunks().map { UInt8($0, radix: 16) }` idiom。
    public static func hexToBytes(_ hex: String) -> [UInt8]? {
        let hexBytes = Array(hex.utf8)
        guard !hexBytes.isEmpty else { return [] }
        #if os(iOS) || os(macOS)
        let need = hexBytes.count / 2
        var out = [UInt8](repeating: 0, count: need)
        let rc = hexBytes.withUnsafeBufferPointer { hp in
            out.withUnsafeMutableBufferPointer { op in
                bas_ranker_hex_to_bytes(
                    hp.baseAddress, hexBytes.count,
                    op.baseAddress, op.count)
            }
        }
        if rc >= 0 { return out }
        // rc < 0 → either malformed input OR FFI failure;
        // fall through to Swift validator so the API is
        // consistent (returns nil on malformed input)。
        #endif
        // Swift fallback — same shape as legacy idiom。
        guard hexBytes.count % 2 == 0 else { return nil }
        var fallback: [UInt8] = []
        fallback.reserveCapacity(hexBytes.count / 2)
        var i = 0
        while i < hexBytes.count {
            guard let hi = hexNibble(hexBytes[i]),
                  let lo = hexNibble(hexBytes[i + 1])
            else { return nil }
            fallback.append((hi << 4) | lo)
            i += 2
        }
        return fallback
    }

    /// Convenience overload returning `Data`。
    public static func hexToData(_ hex: String) -> Data? {
        guard let bytes = hexToBytes(hex) else { return nil }
        return Data(bytes)
    }

    private static func hexNibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 0x30...0x39: return c - 0x30  // '0'-'9'
        case 0x61...0x66: return c - 0x61 + 10  // 'a'-'f'
        case 0x41...0x46: return c - 0x41 + 10  // 'A'-'F'
        default: return nil
        }
    }
}
