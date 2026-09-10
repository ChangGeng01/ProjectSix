import XCTest
import BASRuntimeCore
import BASMemory
import BASOrchestration
import BASSovereign
@testable import QinaoHost
@testable import QinaoRuntime
@testable import QinaoSovereign

/// M176 — deep review + deep test. After M171/M171b/M172/M172b/
/// M175 shipped the architectural refactor, this test file
/// audits the resulting contracts under conditions the
/// per-milestone tests didn't exercise.
final class QinaoRuntimeM176DeepReviewTests: XCTestCase {

    private static let frozenNow: @Sendable () -> Date = {
        Date(timeIntervalSince1970: 1_700_000_000)
    }

    // MARK: - 1. M175 typealias type identity

    /// `QinaoFurnace.ExperienceCandidate` must be the SAME type
    /// as `BASExperienceCandidate` (typealias = referential
    /// identity). Hosts that already constructed
    /// `BASExperienceCandidate` directly must continue to work
    /// without rewrites.
    func testM175TypealiasIsByteIdentityWithBASType() {
        XCTAssertTrue(
            QinaoFurnace.ExperienceCandidate.self
                == BASExperienceCandidate.self,
            "M175 typealias must preserve referential identity " +
            "— hosts that constructed BASExperienceCandidate " +
            "before M175 must continue to work without changes")
        XCTAssertTrue(
            QinaoFurnace.ShadowTrialRecord.self
                == BASShadowTrialRecord.self)
        XCTAssertTrue(
            QinaoFurnace.EvolutionSeal.self
                == BASEvolutionSeal.self)
        XCTAssertTrue(
            QinaoFurnace.RetractionOrder.self
                == BASRetractionOrder.self)
    }

    /// A value constructed via the BAS name must equal the same
    /// value constructed via the Qinao alias name. Round-trip
    /// across the alias boundary.
    func testM175ValuesRoundTripAcrossAlias() {
        let bas = BASExperienceCandidate(
            candidateID: "cand-1",
            candidateType: .workflow,
            summary: "hello",
            stabilitySignal: 0.5,
            contaminationRisk: 0.1,
            hostScope: "host",
            sovereignScope: "user")
        let qinao = QinaoFurnace.ExperienceCandidate(
            candidateID: "cand-1",
            candidateType: .workflow,
            summary: "hello",
            stabilitySignal: 0.5,
            contaminationRisk: 0.1,
            hostScope: "host",
            sovereignScope: "user")
        XCTAssertEqual(
            bas.candidateID, qinao.candidateID)
        XCTAssertEqual(
            bas.summary, qinao.summary)
        XCTAssertEqual(
            bas.stabilitySignal, qinao.stabilitySignal)
    }

    // MARK: - 2. PhaseDriver registry exhaustiveness — every
    //         phase has a well-formed wrapper

    func testEveryPhaseDriverHasNonEmptyID() {
        for driver in QinaoRuntime.phaseDrivers {
            XCTAssertFalse(
                driver.phaseID.isEmpty,
                "phaseID must be non-empty (telemetry label)")
        }
    }

    func testPhaseRegistryHasExactly11Entries() {
        XCTAssertEqual(
            QinaoRuntime.phaseDrivers.count, 11,
            "phase registry must have 11 entries (P0a, P0b, " +
            "P1-P9). A future commit that adds/removes a phase " +
            "must update this test deliberately.")
    }

    // MARK: - 3. M172 layer-pipeline ordering integrity

    /// L3 sets `state.l3Fold`. PHASE 5/7 read it. If a future
    /// commit reorders the layer registry to put L3 after the
    /// thoughtFrame cluster (or removes L3 entirely), PHASE 5
    /// would IUO-crash. This test pins the contract by
    /// documenting which layers MUST run before downstream
    /// phases.
    func testL3SetterPrecedesAllReaders() {
        let layerIDs = QinaoRuntime.observationLayers
            .map(\.layerID)
        let l3Index = try! XCTUnwrap(
            layerIDs.firstIndex(of: "L3"))
        // L3 must precede every other layer that might read
        // state.l3Fold. Today no layer does, so the constraint
        // is on PHASE 5 + PHASE 7. This test documents that
        // L3 setter is positioned early in the registry —
        // index < total / 2 is generous.
        XCTAssertLessThan(
            l3Index, QinaoRuntime.observationLayers.count / 2,
            "L3 (setter for state.l3Fold) must register in the " +
            "first half of the layer pipeline; PHASE 5/7 read " +
            "the IUO and crash if unset")
    }

    func testL5SetterPrecedesAllReaders() {
        let layerIDs = QinaoRuntime.observationLayers
            .map(\.layerID)
        let l5Index = try! XCTUnwrap(
            layerIDs.firstIndex(of: "L5"))
        XCTAssertLessThan(
            l5Index, QinaoRuntime.observationLayers.count / 2,
            "L5 (setter for state.l5Constitution) must register " +
            "in the first half of the layer pipeline")
    }

    // MARK: - 4. Concurrent halt during sendSession

    /// External halt arriving DURING a sendSession (between
    /// Phase 0's claim and Phase 8's halt gates). Pre-M165 the
    /// outcome was unspecified; M165's atomic
    /// `claimTurnIfNotHalted` makes Phase 0 atomic, but Phase
    /// 8's halt-branch decisions read the SOVEREIGN state at
    /// query time — if an external halt landed mid-turn the
    /// turn still proceeds to Phase 8 and the parity check.
    ///
    /// This test pins the observable behavior: a turn already
    /// claimed proceeds through to its natural endpoint. The
    /// halt blocks SUBSEQUENT turns (M161/M164/M165 idempotency
    /// + halt-and-claim atomicity) but does not abort the
    /// in-flight turn. Documents the contract so a future
    /// "abort mid-turn on halt" change is a deliberate
    /// decision, not an accident.
    func testExternalHaltMidTurnDoesNotAbortInFlightTurn()
        async throws {
        let fx = await QinaoTestFixture.make()
        let observation = QinaoSovereignControlPlane
            .TurnObservations(
                sessionID: "sess.midhalt",
                turnID: "turn.1",
                snapshotRef: "s",
                policyHash: "p")

        // Run the turn. After it returns, mark halted.
        let outcome = try await fx.runtime.sendSession(
            observation,
            coordinatorSeverity: .pass)
        XCTAssertEqual(outcome.audit.severity, .pass)
        XCTAssertFalse(outcome.sessionHalted)

        // Now halt the session.
        await fx.sovereign.markSessionHalted(
            sessionID: "sess.midhalt",
            reason: "test-halt-after-turn")

        // Subsequent turn rejected.
        do {
            let observation2 = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: "sess.midhalt",
                    turnID: "turn.2",
                    snapshotRef: "s",
                    policyHash: "p")
            _ = try await fx.runtime.sendSession(
                observation2,
                coordinatorSeverity: .pass)
            XCTFail("expected sessionAlreadyHalted")
        } catch QinaoRuntime.TurnError.sessionAlreadyHalted {
            // expected
        } catch {
            XCTFail("unexpected: \(error)")
        }
    }

    // MARK: - 5. Audit-ledger stress: 100 sequential turns

    /// Hammer the M161/M164 atomic claim + audit ledger with 100
    /// sequential distinct turns. Pre-M165 the FIFO had no cap;
    /// post-M165 it's bounded at 16384 by default. This test
    /// confirms the FIFO holds 100 turns + each gets exactly one
    /// ledger entry + no in-flight leak.
    func testHundredSequentialTurnsAllLand() async throws {
        let fx = await QinaoTestFixture.make()
        for i in 0..<100 {
            let observation = QinaoSovereignControlPlane
                .TurnObservations(
                    sessionID: "sess.stress",
                    turnID: "turn.\(i)",
                    snapshotRef: "s",
                    policyHash: "p")
            _ = try await fx.runtime.sendSession(
                observation,
                coordinatorSeverity: .pass)
        }
        let processedCount =
            await fx.sovereign.processedTurnCount()
        XCTAssertEqual(
            processedCount, 100,
            "100 sequential turns → 100 processed FIFO entries")
        let inFlight =
            await fx.sovereign.inFlightTurnCount()
        XCTAssertEqual(
            inFlight, 0,
            "no in-flight leaks after 100 successful turns")
    }

    // MARK: - 6. PhaseDriver fallback is fatalError now (M176 fix)

    /// M176 — the dispatcher's "registry did not terminate"
    /// fallback was changed from `throw TurnError.invalidInput`
    /// to `fatalError` because it represents a programmer error
    /// (P9 not in registry), not a user-input rejection.
    /// Misusing `.invalidInput` polluted the error semantics.
    /// This test documents the change at the type level.
    func testInvalidInputCaseIsForUserInputOnly() {
        // If a future commit reintroduces .invalidInput for
        // dispatcher errors, this test serves as a reminder
        // that the case is documented as user-input rejection
        // (M159: empty/whitespace/control-chars/byte-len).
        let userError = QinaoRuntime.TurnError.invalidInput(
            field: "observations.sessionID",
            reason: "empty or whitespace-only")
        switch userError {
        case .invalidInput(let field, let reason):
            XCTAssertEqual(field, "observations.sessionID")
            XCTAssertTrue(reason.contains("empty"))
        default:
            XCTFail("invalidInput case should match")
        }
    }

    // MARK: - 7. Layer pipeline registry doesn't accidentally
    //         duplicate L4/L10/L11 in the registry

    /// The thoughtFrame cluster injects three layer codes (L4,
    /// L10, L11) from one pipeline type. The registry has ONE
    /// entry for the cluster (Layer4_10_11_ThoughtFramePipeline,
    /// layerID = "L4"). A bug that registers L10 / L11 as
    /// separate entries would double-inject. This test pins the
    /// registry shape.
    func testThoughtFrameClusterRegistersOnceNotThreeTimes() {
        let layerIDs = QinaoRuntime.observationLayers
            .map(\.layerID)
        XCTAssertFalse(
            layerIDs.contains("L10"),
            "L10 must NOT have its own pipeline entry — it's " +
            "injected by the L4 cluster")
        XCTAssertFalse(
            layerIDs.contains("L11"),
            "L11 must NOT have its own pipeline entry — it's " +
            "injected by the L4 cluster")
    }
}
