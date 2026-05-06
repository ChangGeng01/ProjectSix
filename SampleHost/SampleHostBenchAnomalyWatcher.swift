// MARK: - SampleHostBenchAnomalyWatcher
//
// chapter 二百四十一 / M823 — extracted from SampleHostBenchSafetyKit.swift
// (chapter 一百九十二 / M716-M725 10h-readiness pack split into
// 9 single-responsibility files for navigability + isolated test surface).
//
// This file owns the M718 component invariant.

import Foundation

// MARK: - M718 anomaly watcher

/// Sliding-window anomaly detector. Flags when bench loop is in a
/// suspicious state: substrate stuck (all-same permitMode for N
/// iters) / LLM stuck (all-empty body for N iters) / NaN spike /
/// 0-error-for-very-long.
///
/// Doctrine: watcher is HINT-ONLY (red line 7). It populates
/// `anomalyFlags` on the row; bench loop never auto-stops.
/// Operator reads flags in dashboard / replay tool.
actor SampleHostBenchAnomalyWatcher {
    /// Configurable window size (default 100 iters). Smaller = more
    /// reactive, more false positives; larger = slower detect, fewer FPs.
    let windowSize: Int

    private var permitModeWindow: [String] = []
    private var bodyEmptyWindow: [Bool] = []
    private var nanCountWindow: [Int] = []
    private var totalIters: Int = 0
    private var stuckSubstratesEmitted: Int = 0
    private var stuckLLMsEmitted: Int = 0
    // M739 chapter 一百九十六 — fire-on-entry doctrine fix.
    // Pre-this-batch, once a stuck-window started, the flag fired
    // EVERY iter forever (e.g. 5,988-iter sim run with sticky
    // permitMode = 913 consecutive fires) — spammed JSONL +
    // misled cumulative dashboard counter. Now: fire ONCE on
    // entry into stuck state; require exit (window unique > 1)
    // before next entry can fire.
    private var inSubstrateStuckState: Bool = false
    private var inLLMStuckState: Bool = false

    init(windowSize: Int = 100) {
        self.windowSize = max(10, windowSize)
    }

    /// Per-iter observation. Returns flags to record in row.
    /// Empty array if everything looks healthy.
    func observe(
        permitMode: String,
        bodyIsEmpty: Bool,
        regressionOutputs: [Double?]
    ) -> [String] {
        var flags: [String] = []
        totalIters += 1

        // Slide windows
        permitModeWindow.append(permitMode)
        if permitModeWindow.count > windowSize {
            permitModeWindow.removeFirst()
        }
        bodyEmptyWindow.append(bodyIsEmpty)
        if bodyEmptyWindow.count > windowSize {
            bodyEmptyWindow.removeFirst()
        }

        // NaN/Inf detection per iter (immediate, no window)
        let nans = regressionOutputs
            .compactMap { $0 }
            .filter { !$0.isFinite }
            .count
        nanCountWindow.append(nans)
        if nanCountWindow.count > windowSize {
            nanCountWindow.removeFirst()
        }
        if nans > 0 {
            flags.append("nan-spike:\(nans)")
        }

        // Substrate stuck — full window same permitMode (and not
        // a "natural" repeat like all-block on adversarial run).
        // M739 chapter 一百九十六 — fire-on-entry only.
        if permitModeWindow.count == windowSize {
            let unique = Set(permitModeWindow).count
            if unique == 1 {
                let mode = permitModeWindow[0]
                // Don't flag substrate-error blocks (those are
                // already captured via permitMode itself)
                if mode != "substrate-error" {
                    if !inSubstrateStuckState {
                        flags.append("substrate-stuck:\(mode)")
                        stuckSubstratesEmitted += 1
                        inSubstrateStuckState = true
                    }
                }
            } else {
                // Window has variation again → exit stuck state
                // so a future re-entry can fire fresh.
                inSubstrateStuckState = false
            }
        }
        // LLM stuck — full window all-empty body
        // M739 — same fire-on-entry doctrine.
        if bodyEmptyWindow.count == windowSize {
            let allEmpty = bodyEmptyWindow.allSatisfy { $0 }
            if allEmpty {
                if !inLLMStuckState {
                    flags.append("llm-stuck:all-empty")
                    stuckLLMsEmitted += 1
                    inLLMStuckState = true
                }
            } else {
                inLLMStuckState = false
            }
        }
        // NaN cluster — > 25% of window had nans
        if nanCountWindow.count == windowSize {
            let nansHit = nanCountWindow.filter { $0 > 0 }.count
            if nansHit > windowSize / 4 {
                flags.append("nan-cluster:\(nansHit)/\(windowSize)")
            }
        }

        return flags
    }

    /// Stats for dashboard display.
    func snapshot() -> (
        iters: Int,
        stuckSubstrates: Int,
        stuckLLMs: Int
    ) {
        (totalIters, stuckSubstratesEmitted, stuckLLMsEmitted)
    }

    /// Reset all windows (call on bench Stop→Start).
    func reset() {
        permitModeWindow.removeAll(keepingCapacity: true)
        bodyEmptyWindow.removeAll(keepingCapacity: true)
        nanCountWindow.removeAll(keepingCapacity: true)
        totalIters = 0
        stuckSubstratesEmitted = 0
        stuckLLMsEmitted = 0
        inSubstrateStuckState = false
        inLLMStuckState = false
    }
}
