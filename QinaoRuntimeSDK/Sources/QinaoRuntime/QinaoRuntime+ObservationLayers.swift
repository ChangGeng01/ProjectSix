import Foundation
import BASRuntimeCore
import BASLeaseLife
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASWorldPrior
import QinaoHost
import QinaoSovereign

// M172 — per-layer observation pipeline.
//
// Pre-M172 PHASE 3 of `sendSession` was 14 inline `if let X =
// state.inputs.X { let bundle = BAS*ObservationBundle.derive(...);
// state.pipeline.inject(bundle.coverageSummary, "L<n>") }`
// blocks crammed into one ~150-line helper. Adding a new
// observation layer meant editing the same long file in two
// places (gate block + bookkeeping) — exactly what the senior
// review (item 14) called out: "L 轴（空间）× Phase 轴（时间）
// 耦合在同一函数".
//
// M172 lifts each layer into an independent `LayerPipeline`
// value type. Adding a new layer is now: add one struct in this
// file + one entry in the `observationLayers` array. The
// driver in `streamObservationLayers` dispatches in a 5-line
// loop.
//
// Why the protocol method takes its dependencies explicitly
// (host / lifecycle / now) rather than a `runtime: QinaoRuntime`
// reference: the layer types live OUTSIDE the runtime's actor
// isolation so they can be unit-tested by mocking the
// dependencies. Passing the runtime would force every property
// access to be a cross-actor `await`.

extension QinaoRuntime {

    /// One layer's contribution to the per-turn observation
    /// stream. Conformers decide whether to run (gate check on
    /// `state.inputs`), optionally mutate `state` for downstream
    /// phases, and optionally inject a coverage summary into the
    /// pipeline.
    package protocol LayerPipeline: Sendable {
        /// Stable layer ID (e.g. "L1", "L4"). Used as the
        /// pipeline's layer-code marker.
        var layerID: String { get }

        /// Execute this layer for the current turn.
        ///
        /// - Parameters:
        ///   - state: in/out turn state. Layers that produce
        ///     downstream-needed values (L3 fold, L5 constitution)
        ///     write them here. Layers that only inject coverage
        ///     summaries leave `state.l3Fold` /
        ///     `state.l5Constitution` untouched.
        ///   - host: the host actor for `currentConstitution()`
        ///     style reads (used by L5).
        ///   - lifecycle: optional L1 lifecycle for thermal/budget
        ///     observation derivation (used by L1).
        ///   - now: clock closure for `emittedAt` stamps.
        func process(
            state: inout QinaoRuntime.TurnState,
            host: QinaoHost,
            lifecycle: QinaoLifecycle?,
            now: @Sendable () -> Date
        ) async
    }

    /// Ordered list of layer pipelines that PHASE 3 runs. Order
    /// matters: L3 must run before any phase that reads
    /// `state.l3Fold`; L5 before anything reading
    /// `state.l5Constitution`. PHASE 5+ depends on both.
    package static let observationLayers: [any LayerPipeline] = [
        Layer1LeaseLifePipeline(),
        Layer3ThoughtFoldPipeline(),
        Layer5HostConstitutionPipeline(),
        Layer6PresencePipeline(),
        Layer7DecompositionPipeline(),
        Layer8MemoryPipeline(),
        Layer4_10_11_ThoughtFramePipeline(),
        Layer13UpdateTicketPipeline(),
        Layer2NeuralOrganPipeline(),
        Layer12SoftHandPipeline(),
        Layer9CandidateFrontierPipeline(),
    ]
}

// MARK: - L1 — Lease & Life

/// L1 — gated by lifecycle + routed budget. When either is
/// absent the layer skips silently.
package struct Layer1LeaseLifePipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L1"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let lifecycle = lifecycle,
              let routed = state.routedBudget
        else { return }
        let bundle = lifecycle
            .deriveLeaseLifeObservationBundle(
                fromRoutedBudget: routed,
                sessionID: state.inputs.observations.sessionID,
                turnID: state.inputs.observations.turnID,
                emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L3 — Thought fold

/// L3 — unconditional; assembles a minimum-viable fold and
/// writes it to `state.l3Fold` for PHASE 5 / PHASE 7 to read
/// back. Layer ordering guarantees L3 runs before phases that
/// dereference `state.l3Fold`.
package struct Layer3ThoughtFoldPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L3"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        let sid = state.inputs.observations.sessionID
        let tid = state.inputs.observations.turnID
        state.l3Fold = BASThoughtFold(
            foldID: QinaoSovereignControlPlane.syntheticRef(
                prefix: "fold",
                sessionID: sid, turnID: tid),
            hostEffectSummary: "",
            restorePointer: state.inputs.observations.snapshotRef,
            checksum: state.inputs.observations.policyHash,
            snapshotRef: state.inputs.observations.snapshotRef)
        state.pipeline.inject(
            state.l3Fold.coverageSummary(
                turnID: tid,
                sessionID: sid,
                emittedAt: now()),
            layerID)
    }
}

// MARK: - L5 — Host constitution

/// L5 — unconditional; reads host actor state and writes
/// `state.l5Constitution` for downstream phases.
package struct Layer5HostConstitutionPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L5"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        state.l5Constitution = await host.currentConstitution()
        let versionTree = await host.currentVersionTree()
        let bundle = BASHostConstitutionObservationBundle.derive(
            fromHostConstitution: state.l5Constitution,
            versionTree: versionTree,
            forgetRequest: nil,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L6 — Presence

package struct Layer6PresencePipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L6"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let frame = state.inputs.contextFrame else { return }
        let bundle = BASPresenceObservationBundle.derive(
            from: frame,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L7 — Decomposition

package struct Layer7DecompositionPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L7"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let frame = state.inputs.decomposeFrame else { return }
        let bundle = BASDecompositionObservationBundle.derive(
            from: frame,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L8 — Hippocampal memory

package struct Layer8MemoryPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L8"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let mb = state.inputs.memoryBundle else { return }
        let bundle = BASHippocampalMemoryObservationBundle.derive(
            fromMemoryBundle: mb,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L4 + L10 + L11 — Thought-frame cluster

/// Three layers co-gated on `thoughtFrame`. Pre-M172 they were
/// inline as one block; here a single layer struct injects all
/// three coverage summaries when the gate fires. The
/// `layerID == "L4"` is nominal — the pipeline's layer-code
/// list still records each individual code via three
/// `inject(_:_:)` calls.
package struct Layer4_10_11_ThoughtFramePipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L4"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let frame = state.inputs.thoughtFrame else { return }
        let tid = state.inputs.observations.turnID
        let sid = state.inputs.observations.sessionID
        let l10 = BASTribunalObservationBundle.derive(
            from: frame,
            turnID: tid, sessionID: sid,
            emittedAt: now())
        let l11 = BASRiskObservationBundle.derive(
            from: frame,
            turnID: tid, sessionID: sid,
            emittedAt: now())
        let l4 = BASWorldPriorObservationBundle.derive(
            fromThoughtFrame: frame,
            turnID: tid, sessionID: sid,
            emittedAt: now())
        state.pipeline.inject(l4.coverageSummary, "L4")
        state.pipeline.inject(l10.coverageSummary, "L10")
        state.pipeline.inject(l11.coverageSummary, "L11")
    }
}

// MARK: - L13 — Update tickets

package struct Layer13UpdateTicketPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L13"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard !state.inputs.updateTickets.isEmpty else { return }
        let bundle = BASUpdateTicketObservationBundle.derive(
            fromUpdateTickets: state.inputs.updateTickets,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L2 — Neural organ

package struct Layer2NeuralOrganPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L2"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let map = state.inputs.neuralOrganMap else { return }
        let bundle = BASNeuralOrganObservationBundle.derive(
            fromOrganMap: map,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L12 — Soft hand (gentle hand)

/// Co-gated on `thoughtFrame + renderedOutput`.
package struct Layer12SoftHandPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L12"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let tf = state.inputs.thoughtFrame,
              let rendered = state.inputs.renderedOutput
        else { return }
        let bundle = BASSoftHandObservationBundle.derive(
            from: tf,
            renderedOutput: rendered,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}

// MARK: - L9 — Candidate frontier (dream loop)

package struct Layer9CandidateFrontierPipeline:
    QinaoRuntime.LayerPipeline
{
    package let layerID = "L9"
    package init() {}

    package func process(
        state: inout QinaoRuntime.TurnState,
        host: QinaoHost,
        lifecycle: QinaoLifecycle?,
        now: @Sendable () -> Date
    ) async {
        guard let frontier = state.inputs.candidateFrontier
        else { return }
        let bundle = BASCandidateObservationBundle.derive(
            fromFrontier: frontier,
            turnID: state.inputs.observations.turnID,
            sessionID: state.inputs.observations.sessionID,
            emittedAt: now())
        state.pipeline.inject(bundle.coverageSummary, layerID)
    }
}
