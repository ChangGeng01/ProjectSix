import Foundation

/// 案5 (2026-07-06 decode-OS audit) — the per-turn decode context: ONE snapshot of the facts
/// every decode decider needs, assembled ONCE at the turn boundary so independent gates stop
/// sampling the world separately (the audit found five thermal readers with five opinions).
/// The fused chain's PER-ROUND thermal re-read stays — that is the certified in-flight escape
/// hatch, not a decider. Pure value; the adapter fills it, the planner consumes it.
public struct BASDecodeContext: Sendable, Equatable, Codable {
    public let purpose: BASDecodeLanePolicy.Purpose
    public let temperature: Double
    public let maxOutputTokens: Int?
    /// Sampled once per turn (serious/critical ⇒ the planner's certified plain gate).
    public let thermalThrottled: Bool
    /// Process memory headroom (bytes until the jetsam cap); nil off-iOS / probe unavailable.
    public let memoryHeadroomBytes: Int?

    public init(purpose: BASDecodeLanePolicy.Purpose, temperature: Double,
                maxOutputTokens: Int?, thermalThrottled: Bool,
                memoryHeadroomBytes: Int? = nil) {
        self.purpose = purpose
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.thermalThrottled = thermalThrottled
        self.memoryHeadroomBytes = memoryHeadroomBytes
    }

    /// One line per turn: who could throttle this turn and why — the co-measure lesson made
    /// mechanical (the audit's composition bugs were all "two gates that never saw each other").
    public var summary: String {
        let mem = memoryHeadroomBytes.map { "\($0 / (1024 * 1024))MB" } ?? "n/a"
        return "purpose=\(purpose.rawValue) temp=\(temperature) cap=\(maxOutputTokens.map(String.init) ?? "∞") "
            + "thermal=\(thermalThrottled ? "THROTTLED" : "ok") headroom=\(mem)"
    }
}

extension BASDecodeLanePolicy {
    /// Context overload — DELEGATES verbatim to the certified decider (byte-equal by
    /// construction; the context is a carrier, not new policy).
    public static func decodeStrategy(
        context: BASDecodeContext,
        capabilities: BASDecodeCapabilities,
        profiler: BASAcceptanceProfiler,
        numDraftTokens: Int,
        topTokenEntropy: Double? = nil
    ) -> BASDecodeStrategy {
        decodeStrategy(
            purpose: context.purpose, temperature: context.temperature,
            capabilities: capabilities, profiler: profiler, numDraftTokens: numDraftTokens,
            topTokenEntropy: topTokenEntropy, thermalThrottled: context.thermalThrottled)
    }
}
