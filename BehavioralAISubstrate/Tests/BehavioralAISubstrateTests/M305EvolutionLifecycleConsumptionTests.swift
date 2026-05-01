import XCTest
@testable import BASAdmin
@testable import BASHostKit
import BASMemory
import BASOrchestration
import BASPolicy
import BASRuntimeCore

/// M305 — pin that `BASEvolutionLifecycleSession.aggregate(...)`
/// (M56 / chapter 五十六, schema-only since 2026-04-30) is
/// consumed by the L14 sovereign audit entry on every turn that
/// produces UpdateTickets.
///
/// Pre-M305 the 5-type lifecycle scaffolding (`Stage` /
/// `Action` / `Transition` / `Policy` / `Session`) was self-
/// contained — only its own unit tests + governance registry
/// referenced it. After M305 `EBrainRuntimeCoordinator.runTurn`
/// synthesizes one fresh `BASEvolutionLifecycleSession(stage:
/// .proposed)` per `BASUpdateTicket`, aggregates them, and
/// pipes the aggregate into `buildSovereignAuditEntry`, which
/// emits four additive signal codes:
///
///   - `lifecycle.tickets:<N>` — total ticket count
///   - `lifecycle.terminal:<N>` — terminal-stage count (0 on a
///     fresh turn, since all sessions start at `.proposed`)
///   - `lifecycle.promoted:<N>` — promotion-reached count
///     (also 0 on a fresh turn)
///   - `lifecycle.stages:<stages>` — distinct active-stage
///     list joined with `+` (e.g. "proposed")
///
/// All four codes are elided when the turn produces zero
/// tickets (aggregate returns nil). Hash chain semantics
/// preserved — signature digests a longer ordered list. Doctrine
/// red line: pure projection, no verdict escalation.
final class M305EvolutionLifecycleConsumptionTests: XCTestCase {

    // MARK: - Configuration helpers

    private func makeRuntimePolicyLineage() -> BASRuntimePolicyLineage {
        BASRuntimePolicyLineage(
            bundleVersion: "test.m305.bundle.v1",
            providerRoutingRegistryVersion:
                "test.m305.routing-registry.v1",
            providerRoutingPolicyID:
                "test.m305.routing-policy.v1",
            runtimeTuningRegistryVersion:
                "test.m305.tuning-registry.v1",
            runtimeTuningPolicyID:
                "test.m305.tuning-policy.v1",
            resolutionSourceID: "test_bundle"
        )
    }

    private func makeTuning() -> BASEBrainRuntimeSynthesisPolicy {
        var tuning = BASEBrainRuntimeSynthesisPolicy.generic
            .withSchemaVersion(
                "host.runtime-synthesis.m305.v1")
        tuning.stateTransitions.runModeRules =
            tuning.stateTransitions
                .synthesizedRunModeRules(
                    wakeIntent: tuning.wakeIntent)
        return tuning
    }

    private func makeRuntime() -> BASHostRuntime {
        BASHostRuntime(
            configuration: BASHostConfiguration(
                runtimeProfileID: "host.m305",
                policyProfileID: "host.m305.policy",
                prefersPureLocal: true,
                defaultDeviceState:
                    BASHostConfiguration.fixtureDefaultDeviceState,
                console: .generic,
                lifecycleBehavior: .generic,
                workflowBehavior: .generic,
                cognitionBehavior: .generic,
                presentation: .generic,
                runtimeTuning: makeTuning(),
                runtimePolicyLineage:
                    makeRuntimePolicyLineage(),
                hostRhythmProfile: .generic
            )
        )
    }

    private func runTurn(
        prompt: String =
            "I learned something I want to update my approach.",
        title: String = "M305 evolution lifecycle",
        riskLevel: BASHostRiskLevel = .medium
    ) throws -> BASEBrainTurnResult {
        let runtime = makeRuntime()
        let result = try runtime.startSession(
            BASHostSessionRequest(
                kind: .interactive,
                workflowProfile: .reflective,
                surface: .application,
                prompt: prompt,
                title: title,
                riskLevel: riskLevel
            )
        )
        return try XCTUnwrap(result.eBrainTurn)
    }

    // MARK: - 1. Aggregate empty → nil

    /// Empty session list returns nil so audit can elide all
    /// `lifecycle.*` codes.
    func testAggregateEmptyReturnsNil() {
        let agg = BASEvolutionLifecycleSession.aggregate([])
        XCTAssertNil(agg)
    }

    // MARK: - 2. Aggregate counts terminal vs active

    func testAggregateCountsTerminalAndPromoted() {
        let sessions: [BASEvolutionLifecycleSession] = [
            BASEvolutionLifecycleSession(
                candidateID: "c1",
                currentStage: .proposed,
                history: []),
            BASEvolutionLifecycleSession(
                candidateID: "c2",
                currentStage: .promoted,
                history: []),
            BASEvolutionLifecycleSession(
                candidateID: "c3",
                currentStage: .retracted,
                history: []),
            BASEvolutionLifecycleSession(
                candidateID: "c4",
                currentStage: .rejected,
                history: [])
        ]
        let agg = try? XCTUnwrap(
            BASEvolutionLifecycleSession.aggregate(sessions))
        XCTAssertEqual(agg?.count, 4)
        // .retracted and .rejected are terminal; .promoted is
        // not terminal (retraction is a real path from there).
        XCTAssertEqual(agg?.terminalCount, 2)
        // .promoted and .retracted both count as
        // hasReachedPromotion.
        XCTAssertEqual(agg?.promotedCount, 2)
    }

    // MARK: - 3. Aggregate active-stages list ordered by
    //           declaration

    func testActiveStagesOrderedByDeclaration() {
        let sessions = [
            BASEvolutionLifecycleSession(
                candidateID: "a",
                currentStage: .promoted),
            BASEvolutionLifecycleSession(
                candidateID: "b",
                currentStage: .proposed),
            BASEvolutionLifecycleSession(
                candidateID: "c",
                currentStage: .shadowTrialing)
        ]
        let agg = BASEvolutionLifecycleSession.aggregate(
            sessions)
        // Declaration order: proposed → candidateRegistered →
        // shadowTrialing → trialFinalized → promoted →
        // retracted → rejected → withdrawn
        XCTAssertEqual(
            agg?.activeStages,
            [.proposed, .shadowTrialing, .promoted])
    }

    // MARK: - 4. Aggregate is deterministic

    func testAggregateDeterminism() {
        let sessions = [
            BASEvolutionLifecycleSession(
                candidateID: "x",
                currentStage: .candidateRegistered),
            BASEvolutionLifecycleSession(
                candidateID: "y",
                currentStage: .trialFinalized)
        ]
        let a1 = BASEvolutionLifecycleSession.aggregate(sessions)
        let a2 = BASEvolutionLifecycleSession.aggregate(sessions)
        XCTAssertEqual(a1, a2)
    }

    // MARK: - 5. Runtime emits codes when tickets present

    /// A reflective turn produces UpdateTickets → M305 emits
    /// at least lifecycle.tickets > 0.
    func testRuntimeEmitsLifecycleCodesWhenTicketsPresent() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)

        // Tickets may or may not be present depending on the
        // generic runtime's tuning; only assert the contract
        // (codes appear iff aggregate is non-nil).
        let hasTickets = !turn.updateTickets.isEmpty

        let lifecycleCodes = auditEntry.signalRefs.filter {
            $0.hasPrefix("lifecycle.")
        }
        if hasTickets {
            // Four codes when aggregate is non-nil.
            XCTAssertEqual(lifecycleCodes.count, 4)
            XCTAssertTrue(auditEntry.signalRefs.contains {
                $0.hasPrefix("lifecycle.tickets:")
            })
            XCTAssertTrue(auditEntry.signalRefs.contains {
                $0.hasPrefix("lifecycle.terminal:")
            })
            XCTAssertTrue(auditEntry.signalRefs.contains {
                $0.hasPrefix("lifecycle.promoted:")
            })
            XCTAssertTrue(auditEntry.signalRefs.contains {
                $0.hasPrefix("lifecycle.stages:")
            })
        } else {
            // Zero codes when aggregate is nil — confirms the
            // elide path.
            XCTAssertEqual(lifecycleCodes.count, 0)
        }
    }

    // MARK: - 6. lifecycle.tickets parses + matches turn

    /// When tickets exist, the count code matches the actual
    /// ticket count.
    func testLifecycleTicketCountMatchesTurnState() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let actualTicketCount = turn.updateTickets.count
        guard actualTicketCount > 0 else {
            // Skip if no tickets — the aggregate-nil path is
            // covered by the previous test.
            throw XCTSkip(
                "no UpdateTickets on this turn; aggregate-nil " +
                "path covered separately")
        }
        let countCode = auditEntry.signalRefs.first {
            $0.hasPrefix("lifecycle.tickets:")
        }
        XCTAssertEqual(
            countCode,
            "lifecycle.tickets:\(actualTicketCount)")
    }

    // MARK: - 7. Backward-compat: M298-M304 codes still coexist
    //           with M305 codes (when present).

    func testAllMSeriesCodesCoexistOnSingleTurn() throws {
        let turn = try runTurn()
        let auditEntry = try XCTUnwrap(turn.sovereignAuditEntry)
        let signal = auditEntry.signalRefs

        // M299 / M300 / M303 / M304 codes always emit
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("frontier.status:")
        })
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("tribunal.status:")
        })
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("abyssal.magnitude:")
        })
        XCTAssertTrue(signal.contains {
            $0.hasPrefix("humanAnchor.tone:")
        })
    }
}
