// MARK: - SampleHostBASHostInvocation
//
// chapter 二百三十二 / M814 — extracted from SampleHostModel.swift.
//
// Pure helpers for invoking BASHostRuntime entry points with
// uniform error handling + integration-recovery fallback. Currently
// used by SampleHostModel.bootstrap() / start(_:) / reopen() / init.
//
// Pre-this-batch: ~66 LOC of `private static func perform` +
// `private static func fallbackResult` on SampleHostModel.
//
// Post-this-batch: namespace enum `SampleHostBASHostInvocation`
// owns the invocation invariant. The `perform` helper takes a
// runtime + errorSink closure + request closure. The `fallbackResult`
// returns a typed safe-default BASHostSessionResult when the runtime
// can't produce one (rare but possible on misconfiguration).
//
// Doctrine pins:
//   - `errorSink` callback abstracts where the error string lands —
//     SampleHostModel sets `lastError = $0`; future callers might
//     log to OSLog / metrics / etc.
//   - `fallbackResult` constructs a doctrine-clean
//     "Integration Recovery" session that cannot escalate or
//     execute (boundaryMode = .localOnlyAdvisory + boundary
//     constraints lock sensitive memory).
//   - 不变量 #1-#3 + Red line 7: ✓ pure invocation helpers.
//   - chapter 二百十一 single-source-of-truth: invocation +
//     recovery fallback invariant owned by one file.

import Foundation
import BASHostKit

enum SampleHostBASHostInvocation {
    /// Invoke a BASHostRuntime request closure with uniform
    /// error handling + integration-recovery fallback. errorSink
    /// is called with `nil` on success and the error description
    /// string on failure.
    static func perform(
        using runtime: BASHostRuntime,
        errorSink: (String?) -> Void,
        request: () throws -> BASHostSessionResult
    ) -> BASHostSessionResult {
        do {
            errorSink(nil)
            return try request()
        } catch {
            errorSink(String(describing: error))
            return fallbackResult(using: runtime)
        }
    }

    /// Doctrine-clean "Integration Recovery" session result for
    /// when the runtime can't produce one. boundaryMode pins
    /// .localOnlyAdvisory + boundaryConstraints lock sensitive
    /// memory so the fallback can't escalate.
    static func fallbackResult(using runtime: BASHostRuntime) -> BASHostSessionResult {
        (try? runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .primary,
                surface: .application,
                prompt: "Recover the host shell after an integration error.",
                title: "Integration Recovery",
                riskLevel: .low
            )
        )) ?? BASHostSessionResult(
            requestKind: .interactive,
            workflowProfile: .primary,
            currentBrain: BASHostCurrentBrain(
                workflowProfile: .primary,
                workflowTitle: "Primary",
                roleID: "samplehost.recovery",
                identityPosture: .reflective,
                identityInitiative: .guided,
                confidenceCeiling: 0.5,
                relationshipBoundary: "Fallback shell",
                boundaryHeadline: "SampleHost is holding a safe fallback state.",
                boundaryMode: .localOnlyAdvisory,
                boundaryConstraints: [.lockSensitiveMemory],
                calibrationStatus: .stable,
                calibrationAlerts: [],
                riskFlags: [],
                dominantGoals: ["Recover from host integration failure."],
                activeConstraints: ["integration-fallback"],
                retrievalTags: ["fallback"],
                verificationSummary: "samplehost/fallback",
                activeTemplateCount: 0,
                failureGuardCount: 0,
                evolutionPendingReviewCount: 0,
                evolutionRollbackReady: true
            ),
            projection: BASHostProjectionSummary(
                recordCount: 0,
                candidateCount: 0,
                recentEventCount: 0,
                activeTemplateIDs: [],
                failureGuardIDs: []
            ),
            activeSessionTitle: "Integration Recovery",
            notices: ["SampleHost recovered from an integration configuration error."],
            followUpActions: [],
            consoleSnapshot: BASHostConsoleSnapshot(
                overallSummary: "SampleHost recovered from an integration configuration error.",
                reports: []
            )
        )
    }
}
