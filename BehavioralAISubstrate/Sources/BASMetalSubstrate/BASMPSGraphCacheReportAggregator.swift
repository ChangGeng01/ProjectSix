// MARK: - BASMPSGraphCacheReportAggregator
// chapter 五百四 / M1393 — typed converter wiring chapter
// 502 M1386 probe bundle → chapter 499 M1374 cache report
// result。
//
// MULTI-STAGE WIRE-IN ACROSS 4 CHAPTERS:
//   M1369 (ch 498) BASMPSGraphKernelBuildLatencyResultBody
//          ↓
//   M1371 (ch 498) BASKernelEvaluateLatencyProbe →
//                  emits the body per call
//          ↓
//   M1386 (ch 502) BASKernelEvaluateLatencyProbeBundle →
//                  aggregates N bodies + provides typed
//                  hit/miss/nanos rollups
//          ↓
//   M1393 (ch 504) BASMPSGraphCacheReportAggregator →
//                  converts the bundle's typed rollups
//                  into M1374 BASMPSGraphCacheReportResult
//          ↓
//   M1374 (ch 499) BASMPSGraphCacheReportResult →
//                  Codable audit surface ready for end-
//                  of-turn emission
//
// HONEST SCOPE:pure-function converter,no actor state。
// V1 byte-equality preserved (purely additive)。
// ADR-014 OPT-IN — hosts opt-in to the pipeline by
// constructing the probe + bundle + aggregator chain。

import Foundation
import BASRuntimeCore

/// Typed pure-function converter from M1386 probe bundle
/// to M1374 cache report result。 Closes the wire-in
/// pipeline that began at chapter 498。
public enum BASMPSGraphCacheReportAggregator {

    /// Convert a typed probe bundle into a typed cache
    /// report result。 The result's success flag defaults
    /// to true,but callers MAY pass false + diagnostics
    /// when the bundle reflects a partial failure (e.g.
    /// some kernel evaluations threw)。
    public static func report(
        from probeBundle:
            BASKernelEvaluateLatencyProbeBundle,
        success: Bool = true,
        diagnostics: [String] = []
    ) -> BASMPSGraphCacheReportResult {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: probeBundle.cacheHitCount,
            missCount: probeBundle.cacheMissCount,
            totalBuildNanos: probeBundle.totalBuildNanos,
            totalDispatchNanos: probeBundle
                .totalDispatchNanos,
            totalCacheHitSavedNanos: probeBundle
                .totalCacheHitSavedNanos)
        return BASMPSGraphCacheReportResult(
            success: success,
            body: body,
            diagnostics: diagnostics)
    }

    /// Convert an empty probe bundle into the zero
    /// report — used by hosts that emit a "no kernel
    /// dispatch this turn" audit row to confirm the
    /// pipeline was alive even when idle。
    public static let zeroReport:
        BASMPSGraphCacheReportResult =
    {
        let body = BASMPSGraphCacheReportResultBody(
            hitCount: 0,
            missCount: 0,
            totalBuildNanos: 0,
            totalDispatchNanos: 0,
            totalCacheHitSavedNanos: 0)
        return BASMPSGraphCacheReportResult(
            success: true,
            body: body,
            diagnostics: [])
    }()
}
