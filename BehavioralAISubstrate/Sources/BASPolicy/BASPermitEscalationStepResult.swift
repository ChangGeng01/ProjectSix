// MARK: - BASPermitEscalationStepResult — chapter 四百十 / M1010
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十 entry:typed pair value type
// representing the OUTPUT of one escalation step。 Future
// permit-fold function (deferred to chapter 四百十+) takes
// 5 of these (one per chapter of the M384/M385/M406/M449/
// M450 chain) and produces a ledger via a tuple-based
// builder。 Collapses M970's 11-positional-param surface
// (5 outputPermits × 5 reasonCode arrays + 1 initialPermit
// = 11 args) to a 5-named-result-tuple surface。
//
// ## Why this exists (system entropy framing)
//
// M966 `BASPermitEscalationStageRecord` records one stage's
// FULL transition (input + output + reasonCodes)。 But the
// stage's input permit is ALWAYS the previous stage's
// output (chained by definition)。 So the truly free fields
// per stage are just (output, reasonCodes) — the input is
// implied by the chain。
//
// M970 `.build(...)` exposes the chain as 11 positional
// args interleaving outputs + reasonCodes per stage。 That's
// position-entropy:callers must remember the right order
// of 5 outputs and 5 reason-code arrays + 1 initialPermit。
//
// `BASPermitEscalationStepResult` ships the typed pair
// (outputPermit + reasonCodes)。 Future
// `.buildFromResults(initialPermit:abyssal:assertionCeiling:
// kunlun:cthulhuAssertionCeiling:cthulhuEscalation:)` takes
// 5 typed results — caller cannot scramble argument order
// because each is named。
//
// ## What this ships (M1010)
//
//   - `BASPermitEscalationStepResult` Codable value type
//     with `outputPermit + reasonCodes` slots
//   - `.identity(of:)` factory (output = input,no codes)
//   - `BASPermitEscalationLedger.buildFromResults(...)`
//     extension method using 5 named-result params
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四/…/四百九 doctrine pins
//   - chapter 一百八十五 anti-magic-number — typed pair,
//     not (BASActionPermit, [String]) tuple
//   - chapter 二百一一 — single-source-of-truth for the
//     escalation step result shape;ledger consumes
//   - chapter 三百九二 — same input → same ledger
//   - ADR-014 OPT-IN — purely additive;M970's positional
//     `.build(...)` surface unchanged

import Foundation

/// Typed pair value type representing the output of one
/// escalation step。 Pairs the post-step permit with the
/// reason codes the step emitted。
public struct BASPermitEscalationStepResult:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    /// Permit after the step ran (may equal the input
    /// permit when the step was identity-pass)。
    public let outputPermit: BASActionPermit

    /// Reason codes the step emitted。 Empty when the
    /// step was identity-pass。
    public let reasonCodes: [String]

    // MARK: - Init

    public init(
        outputPermit: BASActionPermit,
        reasonCodes: [String] = []
    ) {
        self.outputPermit = outputPermit
        self.reasonCodes = reasonCodes
    }

    // MARK: - Convenience factories

    /// Identity-pass step result:output equals input,no
    /// reason codes。 Used by callers that explicitly
    /// declare a stage was bypassed/skipped。
    public static func identity(
        of permit: BASActionPermit
    ) -> BASPermitEscalationStepResult {
        BASPermitEscalationStepResult(
            outputPermit: permit,
            reasonCodes: [])
    }
}

extension BASPermitEscalationLedger {

    // MARK: - Tuple-based builder (M1010 cleaner counterpart)

    /// Pure-function builder taking 5 named typed results
    /// (one per escalation chapter)。 Cleaner counterpart to
    /// M970's 11-positional-param `.build(...)` surface。
    /// Caller cannot scramble step order because each result
    /// param is named after the escalation chapter。
    ///
    /// Stages are recorded in canonical order matching the
    /// chapter 四百三 entropy audit:
    /// `[.abyssal, .assertionCeiling, .kunlun,
    ///   .cthulhuAssertionCeiling, .cthulhuEscalation]`
    public static func buildFromResults(
        initialPermit: BASActionPermit,
        abyssal: BASPermitEscalationStepResult,
        assertionCeiling: BASPermitEscalationStepResult,
        kunlun: BASPermitEscalationStepResult,
        cthulhuAssertionCeiling:
            BASPermitEscalationStepResult,
        cthulhuEscalation: BASPermitEscalationStepResult
    ) -> BASPermitEscalationLedger {
        BASPermitEscalationLedger.build(
            initialPermit: initialPermit,
            afterAbyssal: abyssal.outputPermit,
            afterAbyssalReasonCodes: abyssal.reasonCodes,
            afterAssertionCeiling:
                assertionCeiling.outputPermit,
            afterAssertionCeilingReasonCodes:
                assertionCeiling.reasonCodes,
            afterKunlun: kunlun.outputPermit,
            afterKunlunReasonCodes: kunlun.reasonCodes,
            afterCthulhuAssertionCeiling:
                cthulhuAssertionCeiling.outputPermit,
            afterCthulhuAssertionCeilingReasonCodes:
                cthulhuAssertionCeiling.reasonCodes,
            afterCthulhuEscalation:
                cthulhuEscalation.outputPermit,
            afterCthulhuEscalationReasonCodes:
                cthulhuEscalation.reasonCodes)
    }
}
