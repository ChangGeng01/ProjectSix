import Foundation

enum DecisionTestingStubProfile: String, CaseIterable, Equatable, Sendable {
    case smoke

    var title: String {
        switch self {
        case .smoke: "Smoke"
        }
    }

    var detail: String {
        switch self {
        case .smoke:
            "Use deterministic fake model output so tests can verify refinement and reminder selection without a live provider."
        }
    }
}
