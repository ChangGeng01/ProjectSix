// MARK: - BASPermitEscalationStepResults — chapter 四百十 / M1012
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百十 third cut:typed bundle
// aggregating all 5 step results + initial permit into one
// value type。 Collapses M1010's 6-arg `.buildFromResults(...)`
// surface to a 1-arg `.toLedger()` surface。
//
// ## Why this exists (system entropy framing)
//
// M1010 ships per-step typed result (output + reasonCodes)
// + a tuple builder taking 6 named args (initial + 5 step
// results)。 But future fold drivers and audit consumers
// will hold all 5 step results as a single value before
// they ever build the ledger。 Without a typed bundle,each
// caller would aggregate the 5 results into ad-hoc local
// variables → scattered "step-results-aggregation entropy"。
//
// `BASPermitEscalationStepResults` ships the typed 5-step
// bundle。 `.toLedger()` produces the M970/M1010-equivalent
// ledger in one call。 `.allIdentity(of:)` factory produces
// a "no-op" bundle (every step identity-pass) for callers
// that need a placeholder during typed wiring tests。
//
// ## What this ships (M1012)
//
//   - `BASPermitEscalationStepResults` Codable Sendable
//     value type with 6 typed slots:
//       * initialPermit: BASActionPermit
//       * abyssal / assertionCeiling / kunlun /
//         cthulhuAssertionCeiling / cthulhuEscalation
//   - `.toLedger()` method producing the ledger via the
//     M1010 tuple builder
//   - `.allIdentity(of:)` factory (every step pass-through)
//
// ## Doctrine pins held
//
//   - All chapter 四百三/四百四/…/四百九/四百十 doctrine pins
//   - chapter 一百八十五 — typed bundle not raw 6-tuple
//   - chapter 二百一一 — single source-of-truth for the
//     5-step results aggregation shape
//   - chapter 三百九二 — same bundle → same ledger
//   - ADR-014 OPT-IN — purely additive

import Foundation

/// Typed bundle aggregating all 5 step results plus the
/// initial permit。 Future fold drivers + audit consumers
/// hold this as one value before producing the ledger via
/// `.toLedger()`。
public struct BASPermitEscalationStepResults:
    Codable, Equatable, Sendable
{

    // MARK: - Storage

    public let initialPermit: BASActionPermit
    public let abyssal: BASPermitEscalationStepResult
    public let assertionCeiling:
        BASPermitEscalationStepResult
    public let kunlun: BASPermitEscalationStepResult
    public let cthulhuAssertionCeiling:
        BASPermitEscalationStepResult
    public let cthulhuEscalation:
        BASPermitEscalationStepResult

    // MARK: - Init

    public init(
        initialPermit: BASActionPermit,
        abyssal: BASPermitEscalationStepResult,
        assertionCeiling: BASPermitEscalationStepResult,
        kunlun: BASPermitEscalationStepResult,
        cthulhuAssertionCeiling:
            BASPermitEscalationStepResult,
        cthulhuEscalation:
            BASPermitEscalationStepResult
    ) {
        self.initialPermit = initialPermit
        self.abyssal = abyssal
        self.assertionCeiling = assertionCeiling
        self.kunlun = kunlun
        self.cthulhuAssertionCeiling =
            cthulhuAssertionCeiling
        self.cthulhuEscalation = cthulhuEscalation
    }

    // MARK: - Convenience factories

    /// Build a bundle where every step is identity-pass。
    /// Useful for tests + V1↔V2 stub harnesses。
    public static func allIdentity(
        of permit: BASActionPermit
    ) -> BASPermitEscalationStepResults {
        let identity = BASPermitEscalationStepResult
            .identity(of: permit)
        return BASPermitEscalationStepResults(
            initialPermit: permit,
            abyssal: identity,
            assertionCeiling: identity,
            kunlun: identity,
            cthulhuAssertionCeiling: identity,
            cthulhuEscalation: identity)
    }

    // MARK: - Ledger production

    /// Produce the ledger via the M1010 tuple builder。
    /// Pure;same bundle → same ledger (chapter 三百九二)。
    public func toLedger() -> BASPermitEscalationLedger {
        BASPermitEscalationLedger.buildFromResults(
            initialPermit: initialPermit,
            abyssal: abyssal,
            assertionCeiling: assertionCeiling,
            kunlun: kunlun,
            cthulhuAssertionCeiling:
                cthulhuAssertionCeiling,
            cthulhuEscalation: cthulhuEscalation)
    }

    // MARK: - Aggregate accessors

    /// Number of steps where the result fired (output ≠
    /// input OR reasonCodes non-empty)。 Computed via a
    /// short-form recheck rather than allocating the full
    /// ledger。
    public var firedStepCount: Int {
        toLedger().firedStageCount
    }

    /// Final permit after all 5 steps executed,equal to
    /// `cthulhuEscalation.outputPermit`。
    public var finalPermit: BASActionPermit {
        cthulhuEscalation.outputPermit
    }
}
