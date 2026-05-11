// MARK: - BASPermitEscalationDecisionsBundle
// chapter 四百九十五 / M1359 — typed batch of all 5 escalation decisions
//
// The V1 monolith's 5-step permit-escalation pipeline emits 5
// distinct Decision struct types:
//   - BASAbyssalPermitEscalationDecision (M384)
//   - BASAssertionCeilingDecision (M385)
//   - BASKunlunPermitEscalationDecision (M406)
//   - BASCthulhuAssertionCeilingDecision (M449)
//   - BASCthulhuPermitEscalationDecision (M446)
//
// Each is consumed individually in the V1 monolith for:
//   (a) `boundActionPermit = decision.permit` rebind
//   (b) reasonCodes aggregation into `escalationSuppressionCodes`
//   (c) downstream audit emission
//
// This typed bundle batches all 5 decisions into a single
// Sendable + Equatable struct that can be:
//   - Passed through actor boundaries as a single value
//   - Inspected by audit walkers via .pipelineObservation
//     (delegate to BASPermitEscalationPipelineObservation.build —
//      the Codable representation lives on the observation,not
//      the underlying Decision-types-bundle)
//
// HONEST SCOPE NOTE: like M1357 + M1358, this is a typed-surface
// ship。 V1 byte-equality preserved — the V1 monolith doesn't
// consume this bundle yet。 The planned BASPermitEscalation
// FoldExecutor (chapter 496+) will produce instances of this
// bundle and wire it into audit emission。

import Foundation
import BASOrchestration
import BASPolicy

public struct BASPermitEscalationDecisionsBundle:
    Sendable, Equatable
{
    public let abyssal: BASAbyssalPermitEscalationDecision
    public let assertionCeiling: BASAssertionCeilingDecision
    public let kunlun: BASKunlunPermitEscalationDecision
    public let cthulhuAssertion:
        BASCthulhuAssertionCeilingDecision
    public let cthulhuEscalation:
        BASCthulhuPermitEscalationDecision

    public init(
        abyssal: BASAbyssalPermitEscalationDecision,
        assertionCeiling: BASAssertionCeilingDecision,
        kunlun: BASKunlunPermitEscalationDecision,
        cthulhuAssertion:
            BASCthulhuAssertionCeilingDecision,
        cthulhuEscalation:
            BASCthulhuPermitEscalationDecision
    ) {
        self.abyssal = abyssal
        self.assertionCeiling = assertionCeiling
        self.kunlun = kunlun
        self.cthulhuAssertion = cthulhuAssertion
        self.cthulhuEscalation = cthulhuEscalation
    }

    /// Final permit after all 5 escalation steps。 Delegates
    /// to the last step's `.permit`。
    public var finalPermit: BASActionPermit {
        cthulhuEscalation.permit
    }

    /// Convert to a BASPermitEscalationPipelineObservation
    /// — the typed audit surface from M1357 / M1358。 Allows
    /// audit walkers to inspect per-step transitions + aggregate
    /// reason codes without unpacking each Decision type individually。
    public func pipelineObservation(
        initialPermitMode: BASActionPermitMode
    ) -> BASPermitEscalationPipelineObservation {
        return BASPermitEscalationPipelineObservation.build(
            initialPermitMode: initialPermitMode,
            chain: [
                (stepName: "abyssal",
                 outputPermitMode: abyssal.permit.mode,
                 reasonCodes: abyssal.reasonCodes),
                (stepName: "assertion-ceiling",
                 outputPermitMode:
                    assertionCeiling.permit.mode,
                 reasonCodes:
                    assertionCeiling.reasonCodes),
                (stepName: "kunlun",
                 outputPermitMode: kunlun.permit.mode,
                 reasonCodes: kunlun.reasonCodes),
                (stepName: "cthulhu-assertion",
                 outputPermitMode:
                    cthulhuAssertion.permit.mode,
                 reasonCodes:
                    cthulhuAssertion.reasonCodes),
                (stepName: "cthulhu-escalation",
                 outputPermitMode:
                    cthulhuEscalation.permit.mode,
                 reasonCodes:
                    cthulhuEscalation.reasonCodes),
            ])
    }
}
