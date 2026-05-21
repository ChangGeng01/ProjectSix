// MARK: - BASRoutedPresenceFusion
// chapter 七百八十 / M2551-M2555 — STRONG-FLIP execution
//
// Production-default Rust-routed entry point for L6 presence
// signal fusion。 Replaces the inline weighted-sum math that
// existed in BASPresenceObservationBundle aggregation sites。
//
// ## Justification for default flip
//
// Chapter 七百七十九 5-axis measurement reported **7.51× speedup**
// (BASCrossLanguagePerfHarness) for the Rust route vs the inline
// Swift baseline。 Verdict:**STRONG-FLIP** (clears 2.0× threshold
// by 3.75×)。 The Swift V1 inline math allocated [Double] arrays
// for weights + observations per call;Rust uses stack-only
// fixed-size buckets。 Allocation cost dominated the baseline。
//
// ## ADR-014 OPT-IN preserved
//
// Hosts that want the V1 Swift inline path call
// `BASRoutedPresenceFusion.fuseViaSwiftInline(...)` explicitly。
// Default `fuse(...)` routes through Rust on iOS / macOS;
// falls back to Swift inline on watchOS / Linux (no XCFramework
// slice)。 「依旧 不删除 只 comment」 satisfied — the inline
// Swift path is the LIVE fallback,not removed。

import Foundation
import BASRuntimeCore

/// One channel observation handed to the fusion routine。
public struct BASChannelObservationInput:
    Sendable, Equatable, Hashable
{
    /// Channel discriminant (0=task / 1=risk / 2=manipulation /
    /// 3=environment / 4=bodyRhythm)
    public let channelByte: UInt8
    public let salience: Double
    public let confidence: Double

    public init(
        channelByte: UInt8,
        salience: Double,
        confidence: Double
    ) {
        self.channelByte = channelByte
        self.salience = salience
        self.confidence = confidence
    }
}

/// Production-default fusion entry。 Routes through Rust on
/// iOS / macOS (STRONG-FLIP at chapter 七百八十);Swift inline
/// fallback on other platforms。
public enum BASRoutedPresenceFusion {

    /// Doctrine-pinned per-channel weights。 Mirror Rust
    /// `PresenceChannel.weight()`。
    private static let channelWeights: [Double] = [
        1.0,   // task
        1.5,   // risk
        2.0,   // manipulation
        0.5,   // environment
        0.75,  // bodyRhythm
    ]

    /// Fuse a set of channel observations into a unified [0, 1]
    /// confidence。 Production default。
    ///
    /// On iOS / macOS:routes through `BASPresenceEyeBridge.fuse`
    /// (Rust C ABI,measured 7.51× faster at chapter 七百七十九)。
    ///
    /// On watchOS / Linux:Swift inline weighted-sum (no
    /// XCFramework slice available)。
    public static func fuse(
        observations: [BASChannelObservationInput]
    ) -> Double {
        #if os(iOS) || os(macOS)
        return fuseViaRust(observations: observations)
        #else
        return fuseViaSwiftInline(observations: observations)
        #endif
    }

    /// Rust route。 Bucketizes observations by channel,calls the
    /// 10-scalar bridge with per-channel (salience, confidence)
    /// pairs。 Observations on the SAME channel are AVERAGED
    /// before passing to Rust (matches Rust crate's per-channel
    /// mean-before-weight semantics)。
    internal static func fuseViaRust(
        observations: [BASChannelObservationInput]
    ) -> Double {
        // Bucket per channel
        var sums: [Double] = [0, 0, 0, 0, 0]
        var counts: [Int] = [0, 0, 0, 0, 0]
        for obs in observations {
            let idx = Int(obs.channelByte)
            guard idx < 5 else { continue }
            sums[idx] += obs.salience * obs.confidence
            counts[idx] += 1
        }
        // Per-channel means (0 if no observations on that channel)
        func meanOrZero(_ i: Int) -> Double {
            return counts[i] > 0 ? sums[i] / Double(counts[i]) : 0
        }
        // For the Rust bridge, encode each channel's mean salience
        // with confidence=1 (since we already pre-multiplied)。
        // Channels with no observations pass (0, 0) → Rust skips them。
        return BASPresenceEyeBridge.fuse(
            taskSalience:           counts[0] > 0 ? meanOrZero(0) : 0,
            taskConfidence:         counts[0] > 0 ? 1.0 : 0,
            riskSalience:           counts[1] > 0 ? meanOrZero(1) : 0,
            riskConfidence:         counts[1] > 0 ? 1.0 : 0,
            manipulationSalience:   counts[2] > 0 ? meanOrZero(2) : 0,
            manipulationConfidence: counts[2] > 0 ? 1.0 : 0,
            environmentSalience:    counts[3] > 0 ? meanOrZero(3) : 0,
            environmentConfidence:  counts[3] > 0 ? 1.0 : 0,
            bodyRhythmSalience:     counts[4] > 0 ? meanOrZero(4) : 0,
            bodyRhythmConfidence:   counts[4] > 0 ? 1.0 : 0)
    }

    /// V1 Swift inline fallback。 Used on watchOS / Linux + by
    /// hosts that explicitly opt out。
    public static func fuseViaSwiftInline(
        observations: [BASChannelObservationInput]
    ) -> Double {
        var sums: [Double] = [0, 0, 0, 0, 0]
        var counts: [Int] = [0, 0, 0, 0, 0]
        for obs in observations {
            let idx = Int(obs.channelByte)
            guard idx < 5 else { continue }
            sums[idx] += obs.salience * obs.confidence
            counts[idx] += 1
        }
        var weighted = 0.0
        var weightTotal = 0.0
        for i in 0..<5 where counts[i] > 0 {
            let mean = sums[i] / Double(counts[i])
            weighted += mean * channelWeights[i]
            weightTotal += channelWeights[i]
        }
        if weightTotal == 0 { return 0 }
        let unified = weighted / weightTotal
        return max(0, min(1, unified))
    }
}
