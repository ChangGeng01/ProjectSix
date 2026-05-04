// SPDX-License-Identifier: Apache-2.0
// M514 (chapter 一百三十一) — Counter-Host Check L13 promotion
// gate consume per chapter 一百三十 Appendix P.3 + audit Point 8
// doctrine.
//
// ## Why this exists
//
// `BASCounterHostCheck` (M513, chapter 一百三十) defines the
// schema + derive-helper but the L13 promotion path doesn't
// yet enforce the doctrine invariant: when outcome ==
// `.systemInducedDrift`, promotion MUST be blocked unless an
// explicit L14 sovereign warrant overrides.
//
// This file is the production wire — gate-aware variant of the
// existing `approveForDistillation(ticketID:sovereignVerdictRef:)`
// promotion path that consults `BASCounterHostCheck.requires
// SovereignOverride` before advancing the ticket.
//
// Pattern parallel to:
//   - `submitWithForbiddenGate(_:forbidden:)` (chapter 八十九 M386)
//   - `startTrialWithForbiddenGate(...)` (chapter 八十九 M386)
// The Counter-Host gate is the same shape: gate-aware variant
// that consults a typed primitive before delegating to the
// primary mouth, and rejects with reason codes when the gate
// refuses.
//
// ## Doctrine pins
//
// - **不变量 #3 加固** — "私有经验不进权重" + "不通过宿主自证
//   循环塑造宿主"
// - **Single commit mouth preserved** — gate doesn't replace
//   `approveForDistillation`; it wraps it
// - **Sovereign override is explicit** — when host候选 is
//   `.systemInducedDrift`, the L14 verdict ref MUST be
//   non-empty; empty verdict ref → block + audit reason codes
//
// ## DAG discipline
//
// Imports `BASMemory` (for `BASCounterHostCheck`) +
// `BASObservability` (for `BASUpdateTicketLifecycleCoordinator`).
// Lives at `BASHostKit` per existing gate-extension convention.

import BASMemory
import BASObservability
import Foundation

// MARK: - BASCounterHostGateOutcome

/// 3-case outcome tag from the Counter-Host gate-aware promotion
/// path. Audit walkers grep `counter-host-gate:<outcome>` reason
/// codes to determine whether the promotion went through cleanly,
/// went through with sovereign override, or was blocked.
public enum BASCounterHostGateOutcome:
    String, Sendable, Equatable, Codable, Hashable, CaseIterable
{
    /// 直通通过 — Counter-Host Check was nil OR outcome was not
    /// `.systemInducedDrift`. Promotion advanced normally.
    case passed = "passed"
    /// 主权override 通过 — outcome was `.systemInducedDrift`
    /// AND a non-empty L14 verdict ref was provided. Promotion
    /// advanced with explicit sovereign override; audit trail
    /// records the override reason.
    case passedWithSovereignOverride = "passed-with-sovereign-override"
    /// 阻止 — outcome was `.systemInducedDrift` AND no
    /// non-empty L14 verdict ref was provided. Promotion blocked;
    /// ticket marked rejected with Counter-Host reason codes.
    case blocked = "blocked"
}

// MARK: - BASUpdateTicketLifecycleCoordinator extension

public extension BASUpdateTicketLifecycleCoordinator {

    /// **M514** — Counter-Host-aware variant of
    /// `approveForDistillation(ticketID:sovereignVerdictRef:)`.
    ///
    /// Gate logic (per chapter 一百三十 P.3 doctrine):
    ///
    ///   - When `counterHostCheck == nil` OR
    ///     `outcome == .genuineHostPattern / .insufficientEvidence
    ///     / .notApplicable`: pass through to `approveFor
    ///     Distillation`. Outcome → `.passed`.
    ///   - When `outcome == .systemInducedDrift`:
    ///       a. If `sovereignVerdictRef` is empty → block
    ///          (`markRejected` with Counter-Host reason codes).
    ///          Outcome → `.blocked`.
    ///       b. If `sovereignVerdictRef` is non-empty → pass
    ///          through with override-marked verdict ref. Outcome
    ///          → `.passedWithSovereignOverride`.
    ///
    /// **不变量 #3 加固** — "宿主自证循环候选 必须有显式 L14
    /// 主权 override 才能进入权重池". Empty verdict ref + system-
    /// induced-drift = blocked path; this is the doctrine-load-
    /// bearing branch.
    @discardableResult
    func approveForDistillationWithCounterHostCheck(
        ticketID: String,
        sovereignVerdictRef: String,
        counterHostCheck: BASCounterHostCheck?
    ) async throws -> BASCounterHostGateOutcome {
        guard let check = counterHostCheck else {
            // No Counter-Host Check; promotion advances normally
            // (caller chose not to apply the gate; absence is
            // doctrine-permissible for non-host candidates).
            try await approveForDistillation(
                ticketID: ticketID,
                sovereignVerdictRef: sovereignVerdictRef)
            return .passed
        }

        if !check.requiresSovereignOverride {
            // Genuine pattern / insufficient evidence / not
            // applicable → no override needed.
            try await approveForDistillation(
                ticketID: ticketID,
                sovereignVerdictRef: sovereignVerdictRef)
            return .passed
        }

        // System-induced drift: sovereign override MUST be present
        // and non-empty.
        let trimmedVerdictRef = sovereignVerdictRef
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedVerdictRef.isEmpty {
            // Block the promotion — host self-confirmation loop
            // candidate cannot advance without explicit L14
            // sovereign override.
            var reasonCodes = check.reasonCodes
            reasonCodes.append(
                "counter-host-gate:blocked-no-sovereign-override")
            try await idempotentMarkRejected(
                ticketID: ticketID,
                reasonCodes: reasonCodes)
            return .blocked
        }

        // System-induced drift WITH explicit sovereign override
        // → pass through with audit-tagged verdict ref. The
        // verdict ref is recorded in the lifecycle entry so the
        // audit trail explicitly shows the sovereign authorized
        // this self-confirmation-loop candidate's promotion.
        try await approveForDistillation(
            ticketID: ticketID,
            sovereignVerdictRef: sovereignVerdictRef)
        return .passedWithSovereignOverride
    }
}
