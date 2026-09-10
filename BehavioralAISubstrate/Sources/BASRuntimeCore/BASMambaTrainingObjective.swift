// MARK: - BASMambaTrainingObjective — chapter 四百 / M922
//
// G8 收尾 step 3:typed enum naming the training objective the
// Mamba SSM learns。Trainer reads this from the corpus
// manifest + builds the corresponding loss function。
// Pre-M922 the M917 corpus schema didn't pin what the model
// is TRYING to predict — different objectives demand
// different vocab sizes,output heads,loss formulations。
// Post-M922 the substrate makes the decision explicit + typed
// so trainer + downstream consumers agree。
//
// ## Available objectives
//
//   - `.nextEventKind` — predict the next event's
//     `BASEventLogKind`(12-class softmax)。Cheapest objective
//     to validate the pipeline。
//
//   - `.nextRiskBand` — predict the next event's
//     `BASEventLogRiskBand`(4-class softmax)。Targets the
//     thermal-pressure / failure prediction use case
//     directly。
//
//   - `.permitVerdictNextStep` — predict the L11 commit-mouth
//     permit verdict for the next event (3-class:allow /
//     softCaution / hardNoGo)。Most useful objective for
//     the cognitive OS use case but requires permit verdict
//     to be present in the M903 corpus,which today's
//     export schema does NOT include (M903 carries the event
//     but not the L11 outcome)。Future M-number extends M903
//     to capture verdicts。
//
//   - `.nextEventEmbedding` — predict a continuous embedding
//     of the next event (regression objective)。Used for
//     pre-training where the model learns event-stream
//     dynamics without a discrete label。
//
//   - `.cycleClosingTrigger` — predict a binary "will the
//     graph extractor synthesize a heuristic-7 closing edge
//     at this point"。Direct supervised signal for cycle
//     detection。Requires labels from M857 extractor passes
//     (M903 doesn't currently emit these labels — future
//     M-number adds them)。
//
// ## Why this is typed not a string
//
// The Python trainer needs to:
//   - know which loss class to use (CrossEntropy / MSE /
//     BinaryCrossEntropy)
//   - size the model's output head to match
//   - report metrics keyed to the objective
// A typed enum prevents typos and makes the substrate-side
// decision auditable。
//
// ## Doctrine pins held
//
// - chapter 二百一一 single-source-of-truth — ONE typed
//   objective enum, trainer + substrate both consume it
// - chapter 一百八十五 anti-magic-number — output dim per
//   objective named typed constants
// - ADR-014 OPT-IN — substrate doesn't pick an objective;
//   only declares the typed surface the trainer chooses from

import Foundation

// MARK: - Objective enum

public enum BASMambaTrainingObjective:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    case nextEventKind = "nextEventKind"
    case nextRiskBand = "nextRiskBand"
    case permitVerdictNextStep = "permitVerdictNextStep"
    case nextEventEmbedding = "nextEventEmbedding"
    case cycleClosingTrigger = "cycleClosingTrigger"
}

// MARK: - Loss class

/// Typed enum of loss-function families。Trainer maps the
/// objective to one of these for `torch.nn` instantiation。
public enum BASMambaTrainingLossClass:
    String, Codable, Equatable, Sendable, Hashable, CaseIterable
{
    /// Multi-class classification (CrossEntropyLoss)
    case crossEntropy = "crossEntropy"
    /// Continuous regression (MSELoss)
    case meanSquaredError = "meanSquaredError"
    /// Binary classification (BinaryCrossEntropyLoss)
    case binaryCrossEntropy = "binaryCrossEntropy"
}

// MARK: - Objective shape

/// Typed Codable bundle pinning the output-head shape per
/// objective。Trainer uses this to size the model's final
/// linear layer。
public struct BASMambaTrainingObjectiveShape:
    Codable, Equatable, Sendable, Hashable
{
    public let objective: BASMambaTrainingObjective
    public let lossClass: BASMambaTrainingLossClass
    /// Number of output classes (for classification) OR
    /// embedding dim (for regression)。
    public let outputDim: Int
    /// True if the M903 corpus today carries the labels
    /// needed for this objective。`permitVerdictNextStep` and
    /// `cycleClosingTrigger` are FALSE — they need future
    /// M-number to extend M903's export。Trainer asserts on
    /// load。
    public let labelsAvailableInCurrentExport: Bool

    public init(
        objective: BASMambaTrainingObjective,
        lossClass: BASMambaTrainingLossClass,
        outputDim: Int,
        labelsAvailableInCurrentExport: Bool
    ) {
        self.objective = objective
        self.lossClass = lossClass
        self.outputDim = outputDim
        self.labelsAvailableInCurrentExport =
            labelsAvailableInCurrentExport
    }
}

// MARK: - Schema namespace

public enum BASMambaTrainingObjectiveSchema {

    /// chapter 一百八十五 anti-magic-number — output dims
    public static let nextEventKindClassCount: Int = 12
    public static let nextRiskBandClassCount: Int = 4
    public static let permitVerdictClassCount: Int = 3
    public static let defaultEmbeddingDim: Int = 64
    public static let cycleClosingClassCount: Int = 2

    /// Pure factory:given an objective,return the typed
    /// shape descriptor。Pinned mapping。
    public static func shape(
        for objective: BASMambaTrainingObjective
    ) -> BASMambaTrainingObjectiveShape {
        switch objective {
        case .nextEventKind:
            return BASMambaTrainingObjectiveShape(
                objective: .nextEventKind,
                lossClass: .crossEntropy,
                outputDim: nextEventKindClassCount,
                labelsAvailableInCurrentExport: true)
        case .nextRiskBand:
            return BASMambaTrainingObjectiveShape(
                objective: .nextRiskBand,
                lossClass: .crossEntropy,
                outputDim: nextRiskBandClassCount,
                labelsAvailableInCurrentExport: true)
        case .permitVerdictNextStep:
            return BASMambaTrainingObjectiveShape(
                objective: .permitVerdictNextStep,
                lossClass: .crossEntropy,
                outputDim: permitVerdictClassCount,
                // M903 corpus does NOT carry permit
                // verdicts today — future M-number adds
                labelsAvailableInCurrentExport: false)
        case .nextEventEmbedding:
            return BASMambaTrainingObjectiveShape(
                objective: .nextEventEmbedding,
                lossClass: .meanSquaredError,
                outputDim: defaultEmbeddingDim,
                labelsAvailableInCurrentExport: true)
        case .cycleClosingTrigger:
            return BASMambaTrainingObjectiveShape(
                objective: .cycleClosingTrigger,
                lossClass: .binaryCrossEntropy,
                outputDim: cycleClosingClassCount,
                // M903 corpus does NOT carry cycle-closing
                // labels — future M-number adds
                labelsAvailableInCurrentExport: false)
        }
    }

    /// All objectives whose labels are available in the
    /// CURRENT M903 export。Trainer warns / aborts if caller
    /// picks an unavailable objective。
    public static func availableObjectivesToday()
        -> [BASMambaTrainingObjective]
    {
        BASMambaTrainingObjective.allCases.filter {
            shape(for: $0).labelsAvailableInCurrentExport
        }
    }
}
