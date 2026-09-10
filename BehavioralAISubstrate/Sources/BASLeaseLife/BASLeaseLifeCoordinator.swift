import Foundation
import BASRuntimeCore

/// L1 Lease & Life coordinator — the single entry point that glues
/// the three primitives of this library:
///
///   - `BASLungStateAccumulator` (cross-turn pressure)
///   - `BASThermalTwin` (OS thermal + fused guard level)
///   - `BASBreathScheduler` (BGTask-backed maintenance windows)
///
/// Callers in the orchestration layer don't have to re-wire the
/// same three dependencies in every test. They instantiate one
/// coordinator, feed it turn completions, and ask it for the
/// current `BASBudgetFrame.thermalGuardLevel` whenever they're
/// building a budget.
///
/// ## Why a coordinator instead of letting callers compose
///
/// The three primitives have real ordering constraints:
///
/// 1. Lung state must decay before the thermal twin reads it
///    (otherwise the guard level reflects stale pressure).
/// 2. Breath scheduler must be reconciled with the guard level
///    whenever that level changes (otherwise we'll keep a
///    standard-class breath scheduled after thermal escalates).
///
/// If every caller re-implements this glue, we'll have five
/// subtly different implementations and three hard-to-diagnose
/// bugs. Concentrate the glue here, test it once.
public actor BASLeaseLifeCoordinator {
    public struct TurnRecorded: Codable, Sendable, Equatable {
        public let lung: BASLungStateAccumulator.Snapshot
        public let thermal: BASThermalTwin.Reading
        public let cancelledBreathIDs: [String]
    }

    private let lung: BASLungStateAccumulator
    private let thermal: BASThermalTwin
    private let scheduler: BASBreathScheduler

    public init(
        lung: BASLungStateAccumulator,
        thermal: BASThermalTwin,
        scheduler: BASBreathScheduler
    ) {
        self.lung = lung
        self.thermal = thermal
        self.scheduler = scheduler
    }

    /// Convenience constructor that wires fresh primitives with
    /// sensible defaults. Test-heavy code paths should construct
    /// primitives themselves and use `init(lung:thermal:scheduler:)`
    /// so each can be inspected independently.
    public static func makeDefault(
        timeConstantSeconds: Double = 180,
        thermalReader: @escaping BASThermalTwin.Reader =
            BASThermalTwin.defaultReader,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) -> BASLeaseLifeCoordinator {
        BASLeaseLifeCoordinator(
            lung: BASLungStateAccumulator(
                timeConstantSeconds: timeConstantSeconds, clock: clock),
            thermal: BASThermalTwin(reader: thermalReader, clock: clock),
            scheduler: BASBreathScheduler(clock: clock))
    }

    public func lungActor() -> BASLungStateAccumulator { lung }
    public func thermalActor() -> BASThermalTwin { thermal }
    public func schedulerActor() -> BASBreathScheduler { scheduler }

    // MARK: - Turn lifecycle

    /// Record a turn. Updates the lung state, pushes new pressure
    /// into the thermal twin, and reconciles the scheduler against
    /// the resulting guard level.
    @discardableResult
    public func recordTurn(
        runMode: BASEBrainRunMode,
        durationSeconds: Double
    ) async -> TurnRecorded {
        let lungSnap = await lung.record(
            runMode: runMode, durationSeconds: durationSeconds)
        let reading = await thermal.updateAccumulatedPressure(
            lungSnap.pressure)

        // Capture the ids we're about to cancel BEFORE reconcile
        // so the caller can observe the side-effect.
        let beforeIDs = Set(
            (await scheduler.scheduledBreaths()).map(\.request.id))
        await scheduler.reconcile(with: reading.guardLevel)
        let afterIDs = Set(
            (await scheduler.scheduledBreaths()).map(\.request.id))
        let cancelled = beforeIDs.subtracting(afterIDs)

        return TurnRecorded(
            lung: lungSnap,
            thermal: reading,
            cancelledBreathIDs: Array(cancelled).sorted())
    }

    /// Resample without recording a turn. Useful for idle heartbeats
    /// (e.g. the orchestrator is dormant but wants to decay
    /// accumulated pressure and re-reconcile).
    @discardableResult
    public func resample() async -> TurnRecorded {
        let lungSnap = await lung.settle()
        let reading = await thermal.updateAccumulatedPressure(
            lungSnap.pressure)
        let beforeIDs = Set(
            (await scheduler.scheduledBreaths()).map(\.request.id))
        await scheduler.reconcile(with: reading.guardLevel)
        let afterIDs = Set(
            (await scheduler.scheduledBreaths()).map(\.request.id))
        let cancelled = beforeIDs.subtracting(afterIDs)
        return TurnRecorded(
            lung: lungSnap,
            thermal: reading,
            cancelledBreathIDs: Array(cancelled).sorted())
    }

    // MARK: - Breath forwarding

    public func scheduleBreath(
        _ request: BASBreathScheduler.Request
    ) async throws -> BASBreathScheduler.ScheduledBreath {
        // audit policy-obs-misc LOW-6: use a fresh-or-resample reading, not a possibly-stale cache.
        let reading = await thermal.readingFresherThan()
        return try await scheduler.schedule(
            request, guardLevel: reading.guardLevel)
    }
}
