// MARK: - SampleHostWindGatePresentationSupport
//
// chapter 二百三十 / M811 — extracted from SampleHostView.swift.
//
// Pure label-rendering helpers used by the 13-layer turn detail
// view to humanize BAS substrate vocabulary for the UI. Each helper
// is a pure function: input string/enum → output presentation string.
//
// Pre-this-batch: ~18 LOC of inline `enum SampleHostWindGate-
// PresentationSupport` at the top of SampleHostView.swift.
// Post-this-batch: dedicated foundation file. Other carve-out
// panels can reuse without re-importing presentation logic from
// SampleHostView.
//
// Doctrine pins:
//   - chapter 二百二十九 / M810: 13-layer turn detail view
//     references this enum from a dedicated file → that file
//     no longer transitively depends on SampleHostView.swift.
//   - 不变量 #1-#3 + Red line 7: ✓ pure presentation, no decision.
//   - chapter 二百十一 single-source-of-truth: BAS-vocabulary
//     humanization invariant owned by one file.

import Foundation
import BASHostKit

enum SampleHostWindGatePresentationSupport {
    static func modeLabel(_ mode: BASActionPermitMode) -> String {
        humanizedToken(mode.rawValue)
    }

    static func modeLabels(_ modes: [BASActionPermitMode]) -> String {
        modes.map(modeLabel).joined(separator: " • ")
    }

    static func domainList(_ domains: [String], limit: Int = 3) -> String {
        Array(domains.prefix(limit)).map(humanizedToken).joined(separator: " • ")
    }

    static func humanizedToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
