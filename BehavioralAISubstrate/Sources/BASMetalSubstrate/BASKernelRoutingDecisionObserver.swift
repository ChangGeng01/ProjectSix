// MARK: - BASKernelRoutingDecisionObserver
// chapter 五百三 / M1389 — actor-isolated observer that
// records typed kernel routing decisions
//
// REAL CONSUMPTION of chapter 500 typed surfaces:
//   - M1377 BASANEKernelEligibilityClassifier — typed
//     3-tier classification for each BASNeuralOp
//   - M1378 BASThermalAwareKernelSelectionPolicy — typed
//     7-rule routing decision policy
//
// Hosts running performance-sensitive turns can attach
// this observer to their dispatch flow。 Per call,the
// observer records:
//   - The op + thermal state + ane priority
//   - The typed ANE eligibility tier (per M1377)
//   - The chosen routing (per M1378)
//   - Whether the routing matched the ANE tier's "best
//     case" (e.g. ANE-native op routed to ANE)
//
// HONEST SCOPE — chapter 五百三:
// =============================================================
// The observer is OPT-IN。 No production executor consults
// it at chapter 503 close-out (preserved from M1377's
// `consultedByExecutorInProduction = false` invariant)。
// Hosts opt-in by constructing the observer + calling
// `recordDecision(...)` before each dispatch。 V1 byte-
// equality preserved。

import Foundation
import BASRuntimeCore

/// Single typed routing decision record — emitted per
/// kernel dispatch attempt。
public struct BASKernelRoutingDecisionRecord:
    Equatable, Hashable, Codable, Sendable
{
    public let operation: BASNeuralOp
    public let thermalState: BASCapabilityThermalSnapshot
    public let anePriority: BASAcceleratorPriority
    public let eligibilityTier: BASANEEligibilityTier
    public let chosenRouting: BASKernelRoutingPreference
    public let matchedBestCase: Bool
    public let recordedAtMs: Int64

    public init(
        operation: BASNeuralOp,
        thermalState: BASCapabilityThermalSnapshot,
        anePriority: BASAcceleratorPriority,
        eligibilityTier: BASANEEligibilityTier,
        chosenRouting: BASKernelRoutingPreference,
        matchedBestCase: Bool,
        recordedAtMs: Int64
    ) {
        self.operation = operation
        self.thermalState = thermalState
        self.anePriority = anePriority
        self.eligibilityTier = eligibilityTier
        self.chosenRouting = chosenRouting
        self.matchedBestCase = matchedBestCase
        self.recordedAtMs = recordedAtMs
    }
}

/// Actor-isolated routing-decision observer。 Records
/// observations in arrival order;snapshot returns an
/// immutable copy of the records list for audit
/// emission。
public actor BASKernelRoutingDecisionObserver {

    private var records:
        [BASKernelRoutingDecisionRecord] = []

    public init() {}

    /// Record a typed routing decision for the given
    /// op + device state。 Internally:
    ///   1. Classifies the op via M1377 classifier
    ///   2. Computes preferred routing via M1378 policy
    ///   3. Determines if routing matched the tier's
    ///      "best case" — for ANE-native ops that means
    ///      routing went to .aneNative;for MPSGraph-
    ///      native ops that means .gpuMPSGraph;for
    ///      fallback-required ops the best case is
    ///      .cpuStub
    public func recordDecision(
        operation: BASNeuralOp,
        thermalState: BASCapabilityThermalSnapshot,
        anePriority: BASAcceleratorPriority,
        recordedAtMs: Int64
    ) {
        let tier = BASANEKernelEligibilityClassifier
            .tier(for: operation)
        let routing =
            BASThermalAwareKernelSelectionPolicy
            .preferredRouting(
                for: operation,
                thermalState: thermalState,
                anePriority: anePriority)
        let bestCase: Bool
        switch tier {
        case .aneNative:
            bestCase = (routing == .aneNative)
        case .mpsGraphNative:
            bestCase = (routing == .gpuMPSGraph)
        case .fallbackRequired:
            bestCase = (routing == .cpuStub)
        }
        records.append(
            BASKernelRoutingDecisionRecord(
                operation: operation,
                thermalState: thermalState,
                anePriority: anePriority,
                eligibilityTier: tier,
                chosenRouting: routing,
                matchedBestCase: bestCase,
                recordedAtMs: recordedAtMs))
    }

    // MARK: - Snapshot accessors

    /// Total decisions recorded since construction。
    public var decisionCount: Int { records.count }

    /// Count of decisions that landed in the typed
    /// best-case routing for the op's tier。 Useful for
    /// "are we using the GPU/ANE efficiently?" audit
    /// rollups。
    public var bestCaseMatchCount: Int {
        records.filter(\.matchedBestCase).count
    }

    /// Best-case match ratio in [0, 1]。 Zero when no
    /// decisions recorded。
    public var bestCaseMatchRatio: Double {
        guard !records.isEmpty else { return 0 }
        return Double(bestCaseMatchCount)
            / Double(records.count)
    }

    /// Snapshot the current records as an immutable
    /// list for audit emission。 Read-only — does not
    /// mutate state。
    public func snapshot()
        -> [BASKernelRoutingDecisionRecord]
    {
        return records
    }

    /// Reset observation state。 Useful for tests +
    /// per-turn observer instances。
    public func reset() {
        records.removeAll()
    }
}
