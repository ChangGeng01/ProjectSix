import Foundation

struct DecisionContextPreparedState: Codable, Equatable, Sendable {
    var rebuiltSession: Bool
    var generation: Int
    var activeFields: [DecisionContextFieldKey]
    var staleFields: [DecisionContextFieldKey]

    var activeFieldCount: Int {
        activeFields.count
    }

    var staleFieldCount: Int {
        staleFields.count
    }
}
