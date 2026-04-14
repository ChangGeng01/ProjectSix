import Foundation

struct DecisionEvolutionSurfaceState: Equatable, Sendable {
    let contract: DecisionEvolutionSurfaceContract
    let controlSurface: DecisionEvolutionControlSurface
    let workspace: DecisionEvolutionWorkspaceSnapshot
    let operatorSnapshot: DecisionEvolutionOperatorSnapshot
    let attentionSignal: DecisionEvolutionAttentionSignal

    static func build(
        contract: DecisionEvolutionSurfaceContract,
        controlSurface: DecisionEvolutionControlSurface,
        releaseSummary: DecisionSystemReleaseControlSummary? = nil,
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionSurfaceState {
        let workspace = DecisionEvolutionWorkspaceSnapshot.build(
            controlSurface: controlSurface,
            releaseSummary: releaseSummary,
            historyPresentations: historyPresentations
        )

        return DecisionEvolutionSurfaceState(
            contract: contract,
            controlSurface: controlSurface,
            workspace: workspace,
            operatorSnapshot: DecisionEvolutionOperatorSnapshot.build(
                surfaceKind: contract.kind,
                workspace: workspace,
                contract: contract
            ),
            attentionSignal: DecisionEvolutionAttentionSignal.build(
                workspace: workspace
            )
        )
    }
}

extension BeforeAppModel {
    @MainActor
    func makeEvolutionSurfaceState(
        contract: DecisionEvolutionSurfaceContract,
        flightDeck: DecisionSystemFlightDeck? = nil,
        historyPresentations: [DecisionEvolutionCheckpointPresentation] = []
    ) -> DecisionEvolutionSurfaceState {
        DecisionEvolutionSurfaceState.build(
            contract: contract,
            controlSurface: flightDeck?.evolutionControlSurface ?? makeEvolutionControlSurface(),
            releaseSummary: flightDeck?.releaseControlSummary,
            historyPresentations: historyPresentations
        )
    }

    @MainActor
    func makeEvolutionSurfaceState(
        contract: DecisionEvolutionSurfaceContract,
        flightDeck: DecisionSystemFlightDeck? = nil,
        historyCheckpoints: [DecisionEvolutionCheckpoint]
    ) -> DecisionEvolutionSurfaceState {
        let controlSurface = flightDeck?.evolutionControlSurface ?? makeEvolutionControlSurface()
        return DecisionEvolutionSurfaceState.build(
            contract: contract,
            controlSurface: controlSurface,
            releaseSummary: flightDeck?.releaseControlSummary,
            historyPresentations: controlSurface.resolvedPresentations(for: historyCheckpoints)
        )
    }
}
