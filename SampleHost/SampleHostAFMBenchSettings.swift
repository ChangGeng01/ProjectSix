// MARK: - SampleHostAFMBenchSettings
//
// chapter 二百二十三 / M804 — extracted from SampleHostModel.swift.
//
// 5 AFM-bench setter methods + 1 single-prompt update method moved
// to dedicated extension file. Share `SampleHostHybridBenchBounds`
// (chapter 二百二十二) where the AFM bench has the same bound
// doctrine as the hybrid bench (duration / rotation period /
// mutation count). AFM-specific setters (skipBlocked, single-prompt
// update) have no bounds.
//
// Pre-this-batch: ~25 LOC of inline AFM setters in the god class.
// Post-this-batch: dedicated AFM-bench-settings extension. Bounds
// reused from chapter 二百二十二 typed bundle (no duplication).
//
// Doctrine pins:
//   - AFM bench predates `.benign` / `.rawLLM` smokeMode (chapter
//     二百五 / 二百八) so AFM-bench config is simpler than hybrid.
//   - skipBlocked default is false; substrate's permit decision
//     drives whether to call AFM (red line: substrate FIRST).
//   - 不变量 #1-#3 + Red line 7: ✓ pure setters, no decision.

import Foundation

extension SampleHostModel {
    // NOTE: `updateAFMTestPrompt` stays in SampleHostModel.swift
    // because `afmTestPrompt` is `@Published private(set)` and
    // cross-file extensions can't write to private(set) properties.
    // The 5 AFM bench config setters below operate on plain
    // `@Published var` storage so they're cross-file-extension-safe.

    func updateAFMBenchDurationHours(_ newValue: Double) {
        afmBenchDurationHours =
            SampleHostHybridBenchBounds.durationHours(newValue)
    }

    func updateAFMBenchStrideCSV(_ newValue: String) {
        afmBenchStrideRotationCSV = newValue
    }

    func updateAFMBenchRotationPeriod(_ newValue: Int) {
        afmBenchRotationPeriodIter =
            SampleHostHybridBenchBounds.rotationPeriodIter(newValue)
    }

    func updateAFMBenchMutationCount(_ newValue: Int) {
        afmBenchMutationSeedCount =
            SampleHostHybridBenchBounds.mutationSeedCount(newValue)
    }

    func updateAFMBenchSkipBlocked(_ newValue: Bool) {
        afmBenchSkipBlocked = newValue
    }
}
