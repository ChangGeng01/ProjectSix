// MARK: - BASPermitEscalationPipelineObservation
// chapter 四百九十五 / M1357 — typed permit-escalation pipeline observation
//
// The V1 monolith's 5-step boundActionPermit rebind pipeline
// (abyssal → assertionCeiling → kunlun → cthulhuAssertion →
// cthulhuEscalation) was previously NOT typed as a sequence。
// Each step emitted its own Decision struct with reasonCodes
// that flowed into `escalationSuppressionCodes` for audit
// emission,but the pipeline-level metadata (step count,
// per-step input → output permit-mode transitions,total
// reason codes aggregate) was implicit。
//
// This typed observation bundle gives the audit walker
// a single typed surface to inspect:
//   - initialPermitMode (before any escalation)
//   - finalPermitMode (after all 5 steps)
//   - steps: ordered list of step observations
//   - aggregateReasonCodes (typed,deterministic ordering)
//   - escalatedStepCount (steps where output differs from input)
//
// HONEST SCOPE NOTE: this bundle OBSERVES the existing 5-step
// rebind chain。 It does NOT collapse the sequential rebinds
// (those have intermediate dependencies — `unknownReserveForGate`
// derives between abyssal+assertion + kunlun;`cosmicColdCounter
// weight` derives between cthulhuAssertion + cthulhuEscalation)。
//
// The plan's `BASPermitEscalationFoldExecutor.fold(...)`
// (chapter 四百九十二 plannedFutureCuts) would require
// restructuring the substrate to push these intermediate
// derives INSIDE the fold call,which is a separate scope
// expansion deferred to chapter 496+。 Chapter 495 ships
// the observation layer first to give the executor a
// typed integration surface。

import Foundation
import BASPolicy

// MARK: - BASPermitEscalationStepObservation

/// Single step in the escalation pipeline (e.g. abyssal,
/// assertionCeiling, kunlun, cthulhuAssertion, cthulhu
/// Escalation)。 Records the input permit mode,output
/// permit mode after the step,whether escalation fired
/// (mode actually changed),and the typed reason codes
/// the step contributed to the audit trail。
public struct BASPermitEscalationStepObservation:
    Sendable, Codable, Equatable, Hashable
{
    public let stepName: String
    public let inputPermitMode: BASActionPermitMode
    public let outputPermitMode: BASActionPermitMode
    public let escalated: Bool
    public let reasonCodes: [String]

    public init(
        stepName: String,
        inputPermitMode: BASActionPermitMode,
        outputPermitMode: BASActionPermitMode,
        reasonCodes: [String]
    ) {
        self.stepName = stepName
        self.inputPermitMode = inputPermitMode
        self.outputPermitMode = outputPermitMode
        self.escalated =
            inputPermitMode != outputPermitMode
        self.reasonCodes = reasonCodes
    }
}

// MARK: - BASPermitEscalationPipelineObservation

public struct BASPermitEscalationPipelineObservation:
    Sendable, Codable, Equatable, Hashable
{
    public let initialPermitMode: BASActionPermitMode
    public let finalPermitMode: BASActionPermitMode
    public let steps: [BASPermitEscalationStepObservation]

    /// Sum of all step.reasonCodes (preserving step order;
    /// no dedup — dedup is the audit walker's choice)。
    public var aggregateReasonCodes: [String] {
        steps.flatMap(\.reasonCodes)
    }

    /// Count of steps where output ≠ input permit mode。
    public var escalatedStepCount: Int {
        steps.filter(\.escalated).count
    }

    public init(
        initialPermitMode: BASActionPermitMode,
        steps: [BASPermitEscalationStepObservation]
    ) {
        self.initialPermitMode = initialPermitMode
        self.steps = steps
        self.finalPermitMode =
            steps.last?.outputPermitMode
            ?? initialPermitMode
    }
}
