import Foundation

struct DecisionContextPreparedState: Codable, Equatable, Sendable {
    var rebuiltSession: Bool
    var generation: Int
    var anchorFields: [DecisionContextFieldKey]
    var activeFields: [DecisionContextFieldKey]
    var staleFields: [DecisionContextFieldKey]

    var anchorFieldCount: Int {
        anchorFields.count
    }

    var activeFieldCount: Int {
        activeFields.count
    }

    var staleFieldCount: Int {
        staleFields.count
    }
}
