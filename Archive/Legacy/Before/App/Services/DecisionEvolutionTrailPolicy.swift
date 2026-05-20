import Foundation

extension DecisionEvolutionCheckpoint {
    var isIncludedInEvolutionTrail: Bool {
        lineageSummary != nil || !diffSummary.isEmpty
    }
}

extension Array where Element == DecisionEvolutionCheckpoint {
    func evolutionTrailCheckpoints() -> [DecisionEvolutionCheckpoint] {
        filter(\.isIncludedInEvolutionTrail)
    }
}
