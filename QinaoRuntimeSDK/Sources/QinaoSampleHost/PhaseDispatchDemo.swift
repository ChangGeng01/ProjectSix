import Foundation
import QinaoDefaults
import QinaoLoop
import QinaoLoopSeats
import QinaoSeats

/// M313 — phase-dispatch demo.
///
/// Drives the manifesto v4 三阶段并发 dispatch path
/// (`QinaoSeatRegistry.dispatchByPhase`, M309) against a 9-seat
/// council built via `QinaoDefaults.makeStandardWithAdapters`
/// (M312). Pre-M313 both M309 and M312 had **0 production-path
/// callers** outside their own definitions and tests. This demo
/// is the surgical wiring that proves they compose end-to-end.
///
/// The demo does NOT require real model inference — `InertEndpoint`
/// returns empty bodies; default seats read whatever loop state
/// exists (which is empty until `submit(...)` runs) and report
/// urgency 0 with `no-scores` / `no-candidates` reason codes.
/// What we're proving is the **dispatch shape** (3 phases, all
/// 9 seats partitioned, sequential phase ordering, per-phase
/// failure isolation), not the verdict content.
///
/// ## Doctrine
///
/// - **No verdict escalation, no permit mutation, no weight
///   write.** Same advisory contract as M309.
/// - **All 3 phases produce a SeatBoard, even if empty.** Demo
///   asserts this explicitly so a future regression that drops
///   a phase entry surfaces here.
/// - **Phase ordering is observable.** Demo prints phases in
///   manifesto v4 order (perception → cognition → landing); tests
///   pin the canonical headers.
public struct PhaseDispatchDemo {

    /// One phase's observable result. Mirrors `SeatBoard` but
    /// reduced to fields the demo banner cares about.
    public struct PhaseRecord: Sendable, Equatable {
        public let phaseRawValue: String
        public let seatRawValuesASC: [String]
        public let verdictsCount: Int
        public let failuresCount: Int

        public init(
            phaseRawValue: String,
            seatRawValuesASC: [String],
            verdictsCount: Int,
            failuresCount: Int
        ) {
            self.phaseRawValue = phaseRawValue
            self.seatRawValuesASC = seatRawValuesASC
            self.verdictsCount = verdictsCount
            self.failuresCount = failuresCount
        }
    }

    /// Demo outcome. All 3 phases always present (M309 contract).
    public struct Outcome: Sendable, Equatable {
        public let snapshotID: String
        public let totalSeats: Int
        public let perceptionPhase: PhaseRecord
        public let cognitionPhase: PhaseRecord
        public let landingPhase: PhaseRecord

        public init(
            snapshotID: String,
            totalSeats: Int,
            perceptionPhase: PhaseRecord,
            cognitionPhase: PhaseRecord,
            landingPhase: PhaseRecord
        ) {
            self.snapshotID = snapshotID
            self.totalSeats = totalSeats
            self.perceptionPhase = perceptionPhase
            self.cognitionPhase = cognitionPhase
            self.landingPhase = landingPhase
        }
    }

    /// Inert endpoint: returns empty body deterministically. The
    /// loop is wired but never asked to produce real candidates
    /// because the demo is about seat-dispatch shape, not LLM
    /// inference.
    private actor InertEndpoint: QinaoOrganEndpoint {
        func produceBody(
            prompt _: String,
            context _: [String],
            role _: QinaoLoop.OrganRole,
            sessionID _: String
        ) async throws -> QinaoLoop.OrganResponse {
            QinaoLoop.OrganResponse(
                body: "",
                providerID: "phase-demo-inert",
                traceID: "phase-demo")
        }
    }

    /// Build a 9-seat council via M312 + M308, dispatch one
    /// snapshot through M309's three-phase ordering, and surface
    /// the per-phase shape.
    public static func run(
        snapshotID: String = "phase-demo-\(UUID().uuidString)"
    ) async throws -> Outcome {
        let endpoint = InertEndpoint()
        let (_, registry) = try await QinaoDefaults
            .makeStandardWithAdapters(endpoint: endpoint)

        let totalSeats = await registry.registeredSeats().count
        let boards = await registry.dispatchByPhase(
            snapshotID: snapshotID)

        // M309 contract: all 3 phases always present, even if
        // empty. Force-unwrap is doctrinally safe here — a
        // missing phase is a regression, not a runtime
        // condition.
        guard
            let perception = boards[.perception],
            let cognition = boards[.cognition],
            let landing = boards[.landing]
        else {
            throw DemoError.missingPhase(
                "M309 dispatchByPhase must return all 3 phases")
        }

        return Outcome(
            snapshotID: snapshotID,
            totalSeats: totalSeats,
            perceptionPhase: makeRecord(
                phase: .perception, board: perception),
            cognitionPhase: makeRecord(
                phase: .cognition, board: cognition),
            landingPhase: makeRecord(
                phase: .landing, board: landing))
    }

    /// Reduce a (phase, board) pair to a `PhaseRecord` keyed by
    /// raw values so test assertions don't depend on the enum
    /// identity.
    private static func makeRecord(
        phase: QinaoAgentConcurrencyPhase,
        board: SeatBoard
    ) -> PhaseRecord {
        let seats = board.verdicts
            .map(\.seat.rawValue)
            .sorted()
        return PhaseRecord(
            phaseRawValue: phase.rawValue,
            seatRawValuesASC: seats,
            verdictsCount: board.verdicts.count,
            failuresCount: board.failures.count)
    }

    public enum DemoError: Error, Equatable {
        case missingPhase(String)
    }
}
