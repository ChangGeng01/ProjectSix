import Foundation
import QinaoSeats
import QinaoLoop

// M292.6d — default reader adapters bridging existing QinaoLoop
// public API to M292.6c reader protocols.
//
// ## Why this exists
//
// M292.6c shipped 3 reader protocols (Memory / HostAlignment /
// EvolutionShadow) for loop-bound seats. Hosts implement those
// against their own substrate adapters. But for **first-day
// integration / smoke testing / proof-of-concept**, hosts often
// lack a real memory adapter / host-constitution reader / update-
// ticket lifecycle reader. They want a "best-effort default" that
// uses whatever the existing public `QinaoLoop` API exposes.
//
// M292.6d provides those proxy adapters:
//
// - `QinaoLoopMemoryAdapterReader`: synthesizes memory pressure
//   from `triSelfScores` harmony-voice readings (proxy: high
//   regret cost ≈ memory pressure).
// - `QinaoLoopHostAlignmentAdapterReader`: synthesizes alignment
//   pressure from `triSelfScores` guardian-voice boundary signals.
// - `QinaoLoopEvolutionShadowAdapterReader`: returns a
//   no-pending-tickets readout (no public API exposes ticket
//   lifecycle yet; honest zero rather than fake signal).
//
// These are **proxy mappings**, not authoritative substrate reads.
// Hosts running production should ship dedicated readers against
// real substrate adapters; the proxies are explicitly documented
// as "best-effort default until M292.6d.x exposes proper
// substrate readers."
//
// ## Doctrine
//
// - **Honest proxy mapping.** Each adapter documents what signal
//   it derives from what existing public API and what's NOT
//   captured.
// - **No fake signals.** When the loop doesn't expose anything
//   relevant (e.g., update tickets), the adapter returns
//   zero / empty / clean state rather than fabricating data.
// - **Same `QinaoLoopBoundSeat` reuse path.** Adapters fit
//   directly into M292.6c readers; loop-bound seats compose
//   the same way as host-implemented readers.

// MARK: - Memory adapter

/// Proxy reader: synthesizes memory pressure from harmony-voice
/// concern (regret-cost signal). High regret cost is a proxy for
/// "memory says we'd regret this" — useful as a default until a
/// dedicated memory pressure adapter ships.
public struct QinaoLoopMemoryAdapterReader:
    QinaoMemoryStateReader
{
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func readMemoryState(
        sessionID: String
    ) async throws -> QinaoMemoryReadout {
        let scores = try await loop.triSelfScores(
            sessionID: sessionID)
        let harmonyMax =
            scores.map(\.harmonyVoice.concern).max() ?? 0
        // Continuity at risk when regret cost crosses
        // veto-tier (0.7) — proxy for "memory says this
        // breaks continuity".
        return QinaoMemoryReadout(
            memoryPressure: harmonyMax,
            conflictClusterCount: 0,
            continuityAtRisk: harmonyMax >= 0.7)
    }
}

// MARK: - HostAlignment adapter

/// Proxy reader: synthesizes alignment pressure from guardian-
/// voice boundary signals. Counts candidates whose guardian
/// voice flagged boundary-conflict.
public struct QinaoLoopHostAlignmentAdapterReader:
    QinaoHostAlignmentStateReader
{
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func readHostAlignmentState(
        sessionID: String
    ) async throws -> QinaoHostAlignmentReadout {
        let scores = try await loop.triSelfScores(
            sessionID: sessionID)
        // Count candidates whose guardian voice flagged
        // boundary-conflict.
        let boundaryViolations = scores.filter { score in
            score.guardVoice.reasonCodes.contains(
                "boundary-conflict")
        }.count
        // Use guardian's max concern as the value-axis-conflict
        // proxy.
        let guardianMax =
            scores.map(\.guardVoice.concern).max() ?? 0
        return QinaoHostAlignmentReadout(
            boundaryViolationCount: boundaryViolations,
            valueAxisConflict: guardianMax,
            consentScopeBreach: false)
    }
}

// MARK: - EvolutionShadow adapter

/// Proxy reader: no public API exposes update-ticket lifecycle
/// yet, so this adapter honestly returns the zero readout rather
/// than fabricate signals. Hosts wanting evolution-shadow
/// signals should ship a dedicated reader against
/// `BASUpdateTicketLifecycle`.
public struct QinaoLoopEvolutionShadowAdapterReader:
    QinaoEvolutionShadowStateReader
{
    private let loop: QinaoLoop

    public init(loop: QinaoLoop) {
        self.loop = loop
    }

    public func readEvolutionShadowState(
        sessionID _: String
    ) async throws -> QinaoEvolutionShadowReadout {
        // No public loop API exposes ticket lifecycle. Honest
        // zero rather than fake signal.
        QinaoEvolutionShadowReadout(
            pendingTicketCount: 0,
            recentRejectionRate: 0,
            shadowTrialFailureRate: 0)
    }
}

// MARK: - Convenience: loop-bound seats with adapter readers

public extension QinaoSeatRegistry {
    /// Register the 3 loop-bound seats wrapping M292.6d adapter
    /// readers. Use as a "first-day integration" complement to
    /// `standardLoopSeats(loop:)` — together they register all
    /// 9 seats.
    static func adapterBoundSeats(
        loop: QinaoLoop
    ) async -> QinaoSeatRegistry {
        let registry = QinaoSeatRegistry()
        await registry.register(
            QinaoMemoryLoopBoundSeat(
                reader: QinaoLoopMemoryAdapterReader(
                    loop: loop)))
        await registry.register(
            QinaoHostAlignmentLoopBoundSeat(
                reader:
                    QinaoLoopHostAlignmentAdapterReader(
                        loop: loop)))
        await registry.register(
            QinaoEvolutionShadowLoopBoundSeat(
                reader:
                    QinaoLoopEvolutionShadowAdapterReader(
                        loop: loop)))
        return registry
    }
}
