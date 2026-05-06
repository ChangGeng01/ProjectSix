// MARK: - SampleHostCheckpointLifecycle
//
// chapter 二百三十五 / M817 — extracted from SampleHostModel.swift.
//
// 3 checkpoint lifecycle methods (chapter 一百九十三 / M726 + chapter
// 一百九十九 / M748) extracted to dedicated extension file:
//
//   - loadResumableCheckpoint()   — chapter 一百九十三 / M726 resume
//                                   detector (24h staleness filter)
//   - clearResumableCheckpoint()  — UI button: dismiss without start
//   - resumeBenchFromCheckpoint() — chapter 一百九十九 / M748 restore
//                                   settings + start fresh bench
//
// Pre-this-batch: ~55 LOC of inline methods on SampleHostModel.
// Cross-file extension was structurally blocked by `@Published
// private(set) var hybridBenchResumableCheckpoint` writes.
// chapter 二百三十三 (M815) access promotion unblocked.
//
// Post-this-batch: dedicated extension file. SampleHostBenchCheckpoint-
// Store.shared persists the checkpoint actor; this file owns the
// model-side lifecycle invariant.
//
// Doctrine pins:
//   - chapter 一百九十三 / M726: banner is INFORMATIONAL, never
//     auto-restarts. Stale (>24h) checkpoints auto-clear.
//   - chapter 一百九十九 / M748: resume restores SETTINGS only,
//     not running counter state (would corrupt new bench's
//     anomaly windows + Welford running means).
//   - 不变量 #1-#3 + Red line 7: ✓ checkpoint is observability +
//     UX scaffolding, no decision-making.
//   - chapter 二百十一 single-source-of-truth: checkpoint lifecycle
//     invariant owned by one file.

import Foundation

extension SampleHostModel {
    /// M726 chapter 一百九十三 — resume detector. Read latest
    /// checkpoint from disk; if it exists AND `lastUpdatedIso`
    /// is within the last 24 hours, surface it for UI prompt.
    /// Stale checkpoints (> 24h old) are auto-cleared.
    /// Doctrine: resume PROMPTS user, never auto-restarts. The
    /// checkpoint contains stride / smokeMode / iter — UI banner
    /// shows "previous bench reached iter N before crash" so the
    /// operator decides whether to start fresh or carry forward.
    func loadResumableCheckpoint() async {
        let cp = await SampleHostBenchCheckpointStore.shared.read()
        guard let cp = cp else {
            hybridBenchResumableCheckpoint = nil
            return
        }
        // Parse lastUpdatedIso — if older than 24h, auto-clear
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let fallback = ISO8601DateFormatter()
        let last = formatter.date(from: cp.lastUpdatedIso)
            ?? fallback.date(from: cp.lastUpdatedIso)
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        if let last = last, last < cutoff {
            await SampleHostBenchCheckpointStore.shared.clear()
            hybridBenchResumableCheckpoint = nil
            return
        }
        hybridBenchResumableCheckpoint = cp
    }

    /// M726 — UI button: dismiss resume banner without starting.
    /// Clears checkpoint from disk so a future launch sees clean state.
    func clearResumableCheckpoint() async {
        await SampleHostBenchCheckpointStore.shared.clear()
        hybridBenchResumableCheckpoint = nil
    }

    /// M748 chapter 一百九十九 — restore config from checkpoint
    /// then start a fresh bench. "Resume" semantic: same smokeMode /
    /// duration / mutation count / stride as the crashed bench.
    /// Counter state DOES NOT restore (too risky — would corrupt
    /// the new bench's anomaly windows + Welford running means).
    /// New bench writes new JSONL shards; old shards remain on
    /// disk for replay. Banner clears.
    ///
    /// Doctrine: "resume settings, fresh state". Operator carrying
    /// forward thoughtfully-tuned settings without re-typing them.
    func resumeBenchFromCheckpoint() async {
        guard let cp = hybridBenchResumableCheckpoint else { return }
        // Restore typed settings
        if let mode = HybridBenchConfig.SmokeMode(
            rawValue: cp.smokeMode)
        {
            hybridBenchSmokeMode = mode
        }
        updateHybridBenchDurationHours(cp.durationHours)
        updateHybridBenchMutationCount(cp.mutationSeedCount)
        updateHybridBenchStrideCSV(cp.strideCSV)
        // Clear banner (settings now restored)
        await clearResumableCheckpoint()
        // Start fresh bench with restored settings
        startHybridBench()
    }
}
