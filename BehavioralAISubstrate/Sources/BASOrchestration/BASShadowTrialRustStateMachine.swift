// MARK: - BASShadowTrialRustStateMachine
// chapter 七百七十六 / M2531-M2535 — L13 PHASE 2 close-out
//
// Adapter conforming to `BASShadowTrialStateMachine` (the Phase 1
// protocol seam shipped at chapter 七百七十二) backed by the Rust
// state machine (chapter 七百七十四 bas-shadow-trial crate)。
//
// ## Layering
//
// Lives in BASOrchestration because:
//   - BASMemory hosts the Phase 1 protocol seam
//     (BASShadowTrialStateMachine + StateMachineCore)
//   - BASRuntimeCore hosts the Rust FFI bridge
//     (BASShadowTrialBridge via @_silgen_name)
//   - BASOrchestration composes them — that's the existing leaf-
//     discipline pattern (chapter 二百四十九 module-graph
//     contract)
//
// ## ADR-014 OPT-IN preserved
//
// This adapter is OPT-IN。 The Swift coordinator
// (BASShadowTrialCoordinator) still defaults to
// BASShadowTrialStateMachineCore (the Phase 1 Swift impl) unless
// the host explicitly passes `BASShadowTrialRustStateMachine()`
// to the coordinator's init param。 Existing call sites are
// unchanged。
//
// ## Byte-equality guarantee
//
// Pass-through verification:every (phase, verdict) input produces
// identical outcomes on both BASShadowTrialStateMachineCore and
// BASShadowTrialRustStateMachine。 The cross-language fixture in
// BASInternalRustBridgesTests.testShadowTrialRustMatchesSwiftCore
// ByteForByte already pins this at the bridge layer;the close-
// out integration test in this chapter adds an end-to-end
// equivalence assertion through the protocol seam。

import Foundation
import BASMemory
import BASRuntimeCore

/// Rust-backed implementation of `BASShadowTrialStateMachine`。
/// Drop-in replacement for `BASShadowTrialStateMachineCore` —
/// behavior is byte-equal by construction (chapter 七百七十四
/// cross-language fixture proves this)。
public struct BASShadowTrialRustStateMachine:
    BASShadowTrialStateMachine
{
    public init() {}

    public func transition(
        _ request: BASShadowTrialTransitionRequest
    ) -> BASShadowTrialTransitionOutcome {
        // Map Phase 1 phase enum → Phase 2 byte
        let phaseByte = UInt8(request.currentPhase.rawValue)

        // Map Phase 1 verdictRaw String? → Phase 2 verdict byte
        let verdictByte: UInt8
        switch request.verdictRaw {
        case "passed":  verdictByte = 0
        case "failed":  verdictByte = 1
        case "blocked": verdictByte = 2
        case .none:     verdictByte = 3 // Nil
        default:        verdictByte = 99 // Unknown
        }

        // Call Rust state machine
        let result = BASShadowTrialBridge.transition(
            currentPhaseByte: phaseByte, verdictByte: verdictByte)

        // Map Phase 2 result → Phase 1 outcome enum
        if result.advanced {
            guard let nextPhase = BASShadowTrialPhase(
                rawValue: Int(result.nextPhaseByte))
            else {
                // Defensive — should never happen since Rust's
                // packed format pins next_phase to the 4 valid
                // discriminants (0..3)。
                return .rejected(
                    reason: "Rust returned unknown next_phase byte: " +
                            "\(result.nextPhaseByte)")
            }
            return .advanceTo(nextPhase)
        }

        switch result.outcome {
        case 1:  return .rejected(reason: "terminal phase rejects all transitions")
        case 2:  return .rejected(reason: "unknown verdict raw value")
        case -1: return .rejected(reason: "invalid phase byte (\(phaseByte))")
        default: return .rejected(reason: "unknown rust outcome \(result.outcome)")
        }
    }
}

// MARK: - Chapter 七百七十六 L13 Phase 2 sub-arc scorecard

/// Static read-only scorecard for the complete L13 Phase 2 sub-arc。
public enum BASChapter776L13Phase2Scorecard {
    public static let phase1Chapter: String = "chapter 七百七十二"
    public static let phase2Chapters: [String] = [
        "chapter 七百七十四",  // Rust crate + bridge
        "chapter 七百七十五",  // SQL ledger schemas
        "chapter 七百七十六",  // Adapter + close-out
    ]
    public static let totalKnives: Int = 20  // 5 (Phase 1) + 15 (Phase 2)
    public static let rustCrate: String = "bas-shadow-trial"
    public static let sqlSchemasAdded: [String] = [
        "020_shadow_trial_records",
        "021_evolution_seals",
        "022_retraction_orders",
    ]
    public static let swiftAdapter: String =
        "BASShadowTrialRustStateMachine"

    /// Phase 2 is FEATURE-COMPLETE at this scorecard:Rust state
    /// machine + Swift adapter + SQL persistence schemas all
    /// landed。 Live default remains the Phase 1 Swift Core impl
    /// (ADR-014 OPT-IN);hosts opt-in by passing
    /// `BASShadowTrialRustStateMachine()` to the coordinator init。
    public static let phase2Complete: Bool = true

    /// 5-axis decision:
    ///   - Axis 1 PERF:        TBD (pure-fn port,likely TIE-or-modest-win)
    ///   - Axis 2 MEMORY:      equivalent (stateless leaf fns)
    ///   - Axis 3 STATE-MACHINE: Rust strictly stronger
    ///                          (#[repr(u8)] exhaustive match)
    ///   - Axis 4 PERSISTENCE: SQL schemas 020-022 land,opt-in via
    ///                         future SQLite adapter (not in scope
    ///                         this sub-arc)
    ///   - Axis 5 REPLAY:      proven byte-equal via cross-language
    ///                         fixture (BASInternalRustBridgesTests
    ///                         .testShadowTrialRustMatchesSwiftCore
    ///                         ByteForByte)
    ///
    /// Verdict:OPT-IN until hosts run their own 5-axis comparison
    /// + flip via init-param injection。 No premature production
    /// flip per 「亏的不要硬上」。
    public static let decisionVerdict: String = "OPT-IN"
}
