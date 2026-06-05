// MARK: - BASAutoRouteRanker+ProvenanceFilter
// God-object extraction (audit ch1040, WS1): the ProvenanceFilter domain, split out of the
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

    // MARK: - Forget cascade routing (chapter 七百十三 第四刀)
    //
    // Per matrix「Rust:forget cascade」 — set-difference
    // partition with O(N+M) HashSet membership。 Routes always
    // through Rust;Swift fallback preserved for non-Apple
    // platforms。

    /// Partition `recordIds` against `targetIds`,returning
    /// (kept,removed) index lists in input order。
    public static func forgetCascadeFilter(
        recordIds: [String],
        targetIds: [String]
    ) -> BASAutoRouteResult<(
        kept: [Int], removed: [Int]
    )> {
        #if os(iOS) || os(macOS)
        // Encode IDs as length-prefixed UTF-8 flat buffers。
        let recordBuf = encodeLengthPrefixedStrings(recordIds)
        let targetBuf = encodeLengthPrefixedStrings(targetIds)
        var kept = [Int](
            repeating: 0, count: recordIds.count)
        var removed = [Int](
            repeating: 0, count: recordIds.count)
        var keptCount: Int = 0
        var removedCount: Int = 0
        let rc = recordBuf.withUnsafeBytes { rbuf in
            targetBuf.withUnsafeBytes { tbuf in
                kept.withUnsafeMutableBufferPointer { kp in
                    removed.withUnsafeMutableBufferPointer
                        { rp in
                        bas_ranker_forget_cascade_filter(
                            recordIds.isEmpty
                                ? nil
                                : rbuf.bindMemory(
                                    to: UInt8.self)
                                    .baseAddress,
                            recordBuf.count,
                            recordIds.count,
                            targetIds.isEmpty
                                ? nil
                                : tbuf.bindMemory(
                                    to: UInt8.self)
                                    .baseAddress,
                            targetBuf.count,
                            targetIds.count,
                            kp.baseAddress,
                            rp.baseAddress,
                            &keptCount,
                            &removedCount)
                    }
                }
            }
        }
        if rc == 0 {
            let keptOut = Array(kept.prefix(keptCount))
            let removedOut = Array(
                removed.prefix(removedCount))
            return BASAutoRouteResult(
                value: (kept: keptOut, removed: removedOut),
                choice: .rustForgetCascadeFilter)
        }
        #endif
        // Swift fallback: same algorithm,no FFI hop。
        let targetSet = Set(targetIds)
        var keptSwift: [Int] = []
        var removedSwift: [Int] = []
        keptSwift.reserveCapacity(recordIds.count)
        for (i, id) in recordIds.enumerated() {
            if targetSet.contains(id) {
                removedSwift.append(i)
            } else {
                keptSwift.append(i)
            }
        }
        return BASAutoRouteResult(
            value: (kept: keptSwift, removed: removedSwift),
            choice: .swiftForgetCascadeFallback)
    }

    // MARK: - Provenance gate routing (chapter 七百十三 第四刀)
    //
    // Per matrix「Rust:provenance + integrity hash」 —
    // typed-attestation-tier filter。 Routes always through Rust;
    // Swift fallback preserves the same decision tree。

    /// Evaluate one provenance envelope。 Returns the typed
    /// decision + routing choice。
    public static func provenanceFilter(
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        tier: BASProvenanceTier,
        hasAttestationSignatureRef: Bool,
        hasAttestationIssuedAt: Bool
    ) -> BASAutoRouteResult<BASProvenanceGateDecision> {
        #if os(iOS) || os(macOS)
        let tc = Array(trainingCorpusHashHex.utf8)
        let tw = Array(trainedWeightsHashHex.utf8)
        let rc = tc.withUnsafeBufferPointer { tcp in
            tw.withUnsafeBufferPointer { twp in
                bas_ranker_provenance_rejection_code(
                    tcp.baseAddress, tc.count,
                    twp.baseAddress, tw.count,
                    tier.rawValue,
                    hasAttestationSignatureRef ? 1 : 0,
                    hasAttestationIssuedAt ? 1 : 0)
            }
        }
        if rc >= 0 {
            return BASAutoRouteResult(
                value: BASProvenanceGateDecision(
                    rustExitCode: rc),
                choice: .rustProvenanceFilter)
        }
        #endif
        // Swift fallback — same decision tree as Rust。
        return BASAutoRouteResult(
            value: swiftProvenanceDecision(
                trainingCorpusHashHex:
                    trainingCorpusHashHex,
                trainedWeightsHashHex:
                    trainedWeightsHashHex,
                tier: tier,
                hasAttestationSignatureRef:
                    hasAttestationSignatureRef,
                hasAttestationIssuedAt:
                    hasAttestationIssuedAt),
            choice: .swiftProvenanceFallback)
    }

    private static func swiftProvenanceDecision(
        trainingCorpusHashHex: String,
        trainedWeightsHashHex: String,
        tier: BASProvenanceTier,
        hasAttestationSignatureRef: Bool,
        hasAttestationIssuedAt: Bool
    ) -> BASProvenanceGateDecision {
        if trainingCorpusHashHex.count != 64 {
            return .malformedHashLengthTrainingCorpus
        }
        if trainedWeightsHashHex.count != 64 {
            return .malformedHashLengthTrainedWeights
        }
        if !isAllHex(trainingCorpusHashHex) {
            return .malformedHashContentTrainingCorpus
        }
        if !isAllHex(trainedWeightsHashHex) {
            return .malformedHashContentTrainedWeights
        }
        if tier.rawValue
            < BASProvenanceTier.domainExpertReviewed.rawValue
        {
            if hasAttestationSignatureRef {
                return .nonProductionTierCarriesAttestation
            }
            return .belowProductionTier
        }
        if !hasAttestationSignatureRef
            || !hasAttestationIssuedAt
        {
            return .missingAttestationForProductionTier
        }
        return .permitted
    }

    private static func isAllHex(_ s: String) -> Bool {
        for ch in s where !ch.isHexDigit { return false }
        return true
    }

    /// Encode `[String]` as a length-prefixed UTF-8 flat
    /// buffer。 Wire format:concatenation of `[u32_be len]
    /// [utf8 bytes]` records。 Used by the C ABI bridges for
    /// forget-cascade + ledger paths。
    private static func encodeLengthPrefixedStrings(
        _ strs: [String]
    ) -> Data {
        var buf = Data()
        for s in strs {
            let bytes = Array(s.utf8)
            var lenBE = UInt32(bytes.count).bigEndian
            withUnsafeBytes(of: &lenBE) {
                buf.append(contentsOf: $0)
            }
            buf.append(contentsOf: bytes)
        }
        return buf
    }
}
