// MARK: - BASPermitEscalationFoldExecutor — chapter 四百二十五 / M1070
// 系统熵 reduction
//
// Phase 2 entropy chapter 四百二十五 entry:REAL working
// permit-escalation fold executor。 Moves the first
// ADR-018-pending item (`permitEscalationFold`) from
// `.pending` to `.shipped`。
//
// ## Why this is REAL (not scaffolding)
//
// Previous chapters 四百十-四百十二 shipped the typed
// scaffolding for the fold (M966 ledger,M970 builder,
// M1010 step result,M1011 stage order,M1012 results
// bundle)。 But no actual fold function existed — every
// caller still had to rebind `var boundActionPermit` 4
// times by hand。
//
// `BASPermitEscalationFoldExecutor` ships the REAL fold:
//
//   - Takes 5 typed step closures (one per escalation
//     chapter:M384 / M385 / M406 / M449 / M450)
//   - Sequentially threads input → output through all 5
//   - Returns a typed `BASPermitEscalationStepResults`
//     bundle (M1012) which auto-converts to
//     `BASPermitEscalationLedger` via `.toLedger()`
//
// ## Composition entropy reduction (real)
//
// V1 runTurn rebinds `var boundActionPermit` 4-5 times
// across L1005 / L1057 / L1069 / L1178 / L1397 / L1437。
// V2 callers now write:
//
//   let executor = BASPermitEscalationFoldExecutor(
//       abyssal: { permit in
//           let next = await abyssalActor.escalate(permit)
//           return BASPermitEscalationStepResult(
//               outputPermit: next.permit,
//               reasonCodes: next.reasonCodes)
//       },
//       assertionCeiling: { ... },
//       kunlun: { ... },
//       cthulhuAssertionCeiling: { ... },
//       cthulhuEscalation: { ... })
//   let results = await executor.fold(
//       initialPermit: initial)
//   let ledger = results.toLedger()
//   let finalPermit = results.finalPermit
//
// 4 var-rebinds → 1 fold call。 Composition entropy
// collapsed。
//
// ## What this ships (M1070)
//
//   - `BASPermitEscalationFoldExecutor` actor
//   - `BASPermitEscalationFoldExecutor.EscalationStep`
//     typealias for the typed step closure shape
//   - `init(abyssal:assertionCeiling:kunlun:
//      cthulhuAssertionCeiling:cthulhuEscalation:)`
//   - `fold(initialPermit:) async ->
//      BASPermitEscalationStepResults`
//   - `.identity()` static factory producing an executor
//     where every step is identity-pass (useful for tests
//     + stub harnesses)
//
// ## Doctrine pins held
//
//   - 不变量 #1/#2/#3 — fold is pure dispatch over typed
//     step closures;callers retain commitment authority
//   - 红线 7 — fold is hint-only orchestration
//   - chapter 一百八十五 — typed closure shape
//   - chapter 二百一一 — single source-of-truth for
//     fold-execution logic
//   - chapter 三百九二 — same step closures + same input
//     → same ledger
//   - ADR-014 OPT-IN — purely additive;V1 var-rebind
//     path unchanged
//   - ADR-018 — moves `permitEscalationFold` from
//     `.pending` to `.shipped`

import Foundation

/// Real working actor that executes the 5-stage permit
/// escalation chain via typed step closures。 Replaces V1's
/// 4-5× `var boundActionPermit` rebinds with a single
/// `fold(initialPermit:)` call。
public actor BASPermitEscalationFoldExecutor {

    // MARK: - Typed step closure

    /// Typed closure shape for one escalation step。 Caller
    /// wraps a real escalation actor service (or a stub for
    /// tests) inside this closure。 Pure with respect to the
    /// fold:input-permit-in,result-out。
    public typealias EscalationStep = @Sendable (
        BASActionPermit
    ) async -> BASPermitEscalationStepResult

    // MARK: - Storage

    private let abyssalStep: EscalationStep
    private let assertionCeilingStep: EscalationStep
    private let kunlunStep: EscalationStep
    private let cthulhuAssertionCeilingStep:
        EscalationStep
    private let cthulhuEscalationStep: EscalationStep

    // MARK: - Init

    public init(
        abyssal: @escaping EscalationStep,
        assertionCeiling: @escaping EscalationStep,
        kunlun: @escaping EscalationStep,
        cthulhuAssertionCeiling:
            @escaping EscalationStep,
        cthulhuEscalation: @escaping EscalationStep
    ) {
        self.abyssalStep = abyssal
        self.assertionCeilingStep = assertionCeiling
        self.kunlunStep = kunlun
        self.cthulhuAssertionCeilingStep =
            cthulhuAssertionCeiling
        self.cthulhuEscalationStep = cthulhuEscalation
    }

    // MARK: - REAL fold execution

    /// Execute the 5-stage escalation chain sequentially,
    /// threading each step's outputPermit into the next
    /// step's input。 Returns the typed
    /// `BASPermitEscalationStepResults` bundle which
    /// callers convert to a ledger via `.toLedger()`。
    ///
    /// Sequential by design (composition entropy fold per
    /// chapter 四百三 entropy audit):M385 reads M384's
    /// output,M406 reads both,etc。
    ///
    /// Pure with respect to input + step closures:same
    /// initial permit + same step closures → same results
    /// (chapter 三百九二)。
    public func fold(
        initialPermit: BASActionPermit
    ) async -> BASPermitEscalationStepResults {
        let r1 = await abyssalStep(initialPermit)
        let r2 = await assertionCeilingStep(r1.outputPermit)
        let r3 = await kunlunStep(r2.outputPermit)
        let r4 = await cthulhuAssertionCeilingStep(
            r3.outputPermit)
        let r5 = await cthulhuEscalationStep(r4.outputPermit)
        return BASPermitEscalationStepResults(
            initialPermit: initialPermit,
            abyssal: r1,
            assertionCeiling: r2,
            kunlun: r3,
            cthulhuAssertionCeiling: r4,
            cthulhuEscalation: r5)
    }

    // MARK: - Convenience factories

    /// Build an executor where every escalation step is
    /// identity-pass (output = input,no reason codes)。
    /// Useful for stub harnesses + V1↔V2 byte-equality
    /// tests where escalation chain should be a no-op。
    public static func identity()
        -> BASPermitEscalationFoldExecutor
    {
        let step: EscalationStep = { permit in
            BASPermitEscalationStepResult.identity(of: permit)
        }
        return BASPermitEscalationFoldExecutor(
            abyssal: step,
            assertionCeiling: step,
            kunlun: step,
            cthulhuAssertionCeiling: step,
            cthulhuEscalation: step)
    }
}
