// MARK: - BASAutoRouteRanker+Importance
// God-object extraction (audit ch1040, WS1): the Importance domain, split out of the
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

    // MARK: - Importance scorer (chapter 七百二十三 第二刀 / M2287)
    //
    // Routes through the bas-retrieval-ranker Rust crate's
    // `bas_ranker_importance_score_all` FFI。 Wire format matches
    // the Rust-side documentation in the header (BIG-ENDIAN
    // length prefixes,LE f64 values)。
    //
    // BASRuntimeCore-local input/output types so the bridge stays
    // independent of BASMemory's `BASMemoryUsageRecord` —
    // BASMemory side adds a thin adapter when wiring through
    // BASMemoryImportanceScorer (Knife 3)。

    public enum BASImportanceTier: UInt8, Sendable, Equatable {
        case cold = 0
        case warm = 1
        case hot  = 2
    }

    public enum BASImportanceHelpedFlag: UInt8, Sendable, Equatable
    {
        case notHelped = 0
        case helped    = 1
        case unknown   = 2
    }

    public struct BASImportanceRecord: Sendable, Equatable {
        public let atomID: String
        public let retrievedAtMs: Int64
        public let helpedFlag: BASImportanceHelpedFlag
        public init(
            atomID: String,
            retrievedAtMs: Int64,
            helpedFlag: BASImportanceHelpedFlag
        ) {
            self.atomID = atomID
            self.retrievedAtMs = retrievedAtMs
            self.helpedFlag = helpedFlag
        }
    }

    public struct BASImportanceTunables: Sendable, Equatable {
        public let promoteThreshold: Double
        public let demoteThreshold: Double
        public let recencyHalfLifeSeconds: Double
        public let frequencySaturation: Double
        public let tierDecayHot: Double
        public let tierDecayWarm: Double
        public let tierDecayCold: Double
        public init(
            promoteThreshold: Double = 0.65,
            demoteThreshold: Double = 0.20,
            recencyHalfLifeSeconds: Double = 86400.0,
            frequencySaturation: Double = 50.0,
            tierDecayHot: Double = 1.0,
            tierDecayWarm: Double = 0.7,
            tierDecayCold: Double = 0.4
        ) {
            self.promoteThreshold = promoteThreshold
            self.demoteThreshold = demoteThreshold
            self.recencyHalfLifeSeconds = recencyHalfLifeSeconds
            self.frequencySaturation = frequencySaturation
            self.tierDecayHot = tierDecayHot
            self.tierDecayWarm = tierDecayWarm
            self.tierDecayCold = tierDecayCold
        }
    }

    public struct BASImportanceScore: Sendable, Equatable {
        public let atomID: String
        public let currentTier: BASImportanceTier
        public let recencyComponent: Double
        public let frequencyComponent: Double
        public let helpedComponent: Double
        public let tierDecayComponent: Double
        public let totalScore: Double
        public let recommendedTier: BASImportanceTier
        public let recordCount: Int
        public let computedAtMs: Int64
    }

    /// Rust-routed `score_all`。 Returns nil when the XCFramework
    /// is unavailable (watchOS) or the FFI rejects malformed
    /// inputs (extremely unlikely from typed Swift sources)。
    public static func importanceScoreAll(
        records: [BASImportanceRecord],
        tiers: [(atomID: String, tier: BASImportanceTier)],
        tunables: BASImportanceTunables =
            BASImportanceTunables(),
        nowMs: Int64
    ) -> [BASImportanceScore]? {
        #if os(iOS) || os(macOS)
        let recordsBuf = encodeRecordsBuffer(records)
        let tiersBuf   = encodeTiersBuffer(tiers)
        let tunablesBuf = encodeTunablesBuffer(tunables)

        return recordsBuf.withUnsafeBufferPointer { rp in
            return tiersBuf.withUnsafeBufferPointer { tp in
                return tunablesBuf.withUnsafeBufferPointer { up in
                    // Two-phase:discover then fill。
                    let needed = bas_ranker_importance_score_all(
                        rp.baseAddress, recordsBuf.count,
                        tp.baseAddress, tiersBuf.count,
                        up.baseAddress, tunablesBuf.count,
                        nowMs,
                        nil, 0)
                    if needed < 0 { return nil }
                    if needed == 0 { return [] }
                    var outBuf = [UInt8](
                        repeating: 0, count: Int(needed))
                    let wrote = outBuf
                        .withUnsafeMutableBufferPointer { op in
                            return bas_ranker_importance_score_all(
                                rp.baseAddress, recordsBuf.count,
                                tp.baseAddress, tiersBuf.count,
                                up.baseAddress, tunablesBuf.count,
                                nowMs,
                                op.baseAddress, op.count)
                        }
                    guard wrote == needed else { return nil }
                    return decodeScoresBuffer(outBuf)
                }
            }
        }
        #else
        return nil
        #endif
    }
}
