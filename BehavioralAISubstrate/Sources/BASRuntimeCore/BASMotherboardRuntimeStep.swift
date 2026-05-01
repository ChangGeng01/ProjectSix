import Foundation

// 六十二.2 — typed canonical 8-step runtime sequence.
//
// ## Why this exists
//
// Manifesto v3 第六节 spells out the canonical execution
// sequence for one turn: input → SDK → sovereign check → L1
// lease → Neural Runtime → state plane → permit gate → SDK
// execute → event sourcing. **8 steps**, ordered, no skipping.
//
// 五十六 typed-pinned the L13 evolution lifecycle as a state
// machine; 六十二.2 typed-pins **the runtime turn** as another
// canonical sequence. Different concern, same discipline.
//
// ## Doctrine (from 六.1-6.8)
//
// 1. Host input enters the SDK
// 2. Sovereign microkernel verifies legality
// 3. L1 lease & life kernel issues RunLease + BudgetFrame
// 4. Neural runtime assembles organs
// 5. State plane flows: SituationField → CognitiveFrame →
//    MemoryBundle → CandidateFrontier → MergedChoice →
//    ActionPermit
// 6. If external action: ActionPermit + SovereignWarrant +
//    snapshot continuity proof
// 7. SDK executes (otherwise compare/draft-only/local-only/
//    delay/silent stub)
// 8. Event sourcing records UpdateTicket + candidates +
//    audit entries + snapshot anchors
//
// ## Properties
//
// - **`hostInputIntoSDK` is the single entry.**
// - **`eventSourcing` is the single terminus.**
// - **Order is canonical** — steps are not reorderable.
// - **Each step → typed kernel/bus/principle association.**

public enum BASMotherboardRuntimeStep:
    String, Sendable, Equatable, Hashable, Codable,
    CaseIterable
{
    case hostInputIntoSDK
    case sovereignKernelCheck
    case leaseAcquire
    case neuralRuntimeAssembly
    case stateGraphFlow
    case permitGate
    case sdkExecute
    case eventSourcing
}

public extension BASMotherboardRuntimeStep {
    /// 0-indexed canonical position in the turn sequence.
    /// Pinned as the source of truth for ordering.
    var canonicalIndex: Int {
        switch self {
        case .hostInputIntoSDK: return 0
        case .sovereignKernelCheck: return 1
        case .leaseAcquire: return 2
        case .neuralRuntimeAssembly: return 3
        case .stateGraphFlow: return 4
        case .permitGate: return 5
        case .sdkExecute: return 6
        case .eventSourcing: return 7
        }
    }

    /// Which kernel is the primary owner of this step.
    var owningKernel: BASMotherboardKernel {
        switch self {
        case .hostInputIntoSDK:
            // SDK input crossing — no kernel "owns" it
            // exclusively, but state graph picks it up first.
            return .stateAndEvolutionGraph
        case .sovereignKernelCheck:
            return .sovereignMicrokernel
        case .leaseAcquire:
            return .leaseAndLife
        case .neuralRuntimeAssembly:
            return .neuralOrganRuntime
        case .stateGraphFlow:
            return .stateAndEvolutionGraph
        case .permitGate:
            return .sovereignMicrokernel
        case .sdkExecute:
            // SDK is the SDK — but execution depends on
            // permit clearance, so sovereign owns the
            // gating; the actual writes happen outside the
            // 4 kernels (in BASOrgan / SDK side effects).
            return .sovereignMicrokernel
        case .eventSourcing:
            return .stateAndEvolutionGraph
        }
    }

    /// Whether this step is a permit checkpoint — without
    /// passing this step, downstream steps must NOT proceed.
    /// Typed audit hook: callers can grep "did we honor
    /// permit checkpoints" via this property.
    var isPermitCheckpoint: Bool {
        switch self {
        case .sovereignKernelCheck, .permitGate:
            return true
        default:
            return false
        }
    }
}

public enum BASMotherboardRuntimeSequence {
    /// Canonical 8-step ordering. Pinned by tests.
    public static let canonical: [BASMotherboardRuntimeStep]
        = [
            .hostInputIntoSDK,
            .sovereignKernelCheck,
            .leaseAcquire,
            .neuralRuntimeAssembly,
            .stateGraphFlow,
            .permitGate,
            .sdkExecute,
            .eventSourcing,
        ]

    /// The single legitimate entry step.
    public static let entry: BASMotherboardRuntimeStep =
        .hostInputIntoSDK

    /// The single legitimate terminus step.
    public static let terminus: BASMotherboardRuntimeStep =
        .eventSourcing

    /// Permit checkpoints — both must succeed for execute to
    /// proceed.
    public static let permitCheckpoints:
        Set<BASMotherboardRuntimeStep> = [
            .sovereignKernelCheck, .permitGate,
        ]
}
