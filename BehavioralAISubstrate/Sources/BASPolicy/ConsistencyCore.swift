import Foundation

public struct BASStructuredTruthState: Codable, Sendable, Equatable {
    public var mode: String
    public var currentGoal: String?
    public var allowedActions: [String]
    public var forbiddenActions: [String]
    public var personaRules: [String]
    public var sessionFacts: [String: String]

    public init(
        mode: String,
        currentGoal: String? = nil,
        allowedActions: [String] = [],
        forbiddenActions: [String] = [],
        personaRules: [String] = [],
        sessionFacts: [String: String] = [:]
    ) {
        self.mode = mode
        self.currentGoal = currentGoal
        self.allowedActions = allowedActions
        self.forbiddenActions = forbiddenActions
        self.personaRules = personaRules
        self.sessionFacts = sessionFacts
    }
}

public enum BASConsistencyViolationKind: String, Codable, Sendable, CaseIterable {
    case modeMismatch
    case forbiddenAction
    case unsupportedAction
    case factConflict
    case personaDrift
}

public struct BASConsistencyViolation: Codable, Sendable, Equatable, Identifiable {
    public var id: String { "\(kind.rawValue):\(message)" }
    public var kind: BASConsistencyViolationKind
    public var message: String

    public init(kind: BASConsistencyViolationKind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public struct BASConsistencyCheckInput: Codable, Sendable, Equatable {
    public var truthState: BASStructuredTruthState
    public var responseMode: String
    public var responseText: String
    public var proposedActions: [String]
    public var referencedFacts: [String: String]

    public init(
        truthState: BASStructuredTruthState,
        responseMode: String,
        responseText: String,
        proposedActions: [String] = [],
        referencedFacts: [String: String] = [:]
    ) {
        self.truthState = truthState
        self.responseMode = responseMode
        self.responseText = responseText
        self.proposedActions = proposedActions
        self.referencedFacts = referencedFacts
    }
}

public struct BASConsistencyCheckResult: Codable, Sendable, Equatable {
    public var violations: [BASConsistencyViolation]

    public init(violations: [BASConsistencyViolation]) {
        self.violations = violations
    }

    public var isConsistent: Bool {
        violations.isEmpty
    }

    public var severityScore: Double {
        guard !violations.isEmpty else { return 0 }
        return min(1, Double(violations.count) / 4.0)
    }

    public var shouldRepair: Bool {
        !isConsistent
    }
}

public enum BASConsistencyHarness {
    public static func evaluate(
        _ input: BASConsistencyCheckInput
    ) -> BASConsistencyCheckResult {
        var violations: [BASConsistencyViolation] = []

        if input.responseMode != input.truthState.mode {
            violations.append(
                BASConsistencyViolation(
                    kind: .modeMismatch,
                    message: "Response mode \(input.responseMode) drifted away from \(input.truthState.mode)."
                )
            )
        }

        let forbiddenMatches = input.proposedActions.filter { input.truthState.forbiddenActions.contains($0) }
        violations.append(
            contentsOf: forbiddenMatches.map {
                BASConsistencyViolation(
                    kind: .forbiddenAction,
                    message: "Action \($0) is forbidden in the current truth state."
                )
            }
        )

        if !input.truthState.allowedActions.isEmpty {
            let unsupported = input.proposedActions.filter { !input.truthState.allowedActions.contains($0) }
            violations.append(
                contentsOf: unsupported.map {
                    BASConsistencyViolation(
                        kind: .unsupportedAction,
                        message: "Action \($0) is not in the current allowed action set."
                    )
                }
            )
        }

        for (key, value) in input.referencedFacts {
            if let known = input.truthState.sessionFacts[key], known != value {
                violations.append(
                    BASConsistencyViolation(
                        kind: .factConflict,
                        message: "Fact \(key) expected \(known) but response referenced \(value)."
                    )
                )
            }
        }

        if let currentGoal = input.truthState.currentGoal,
           let responseGoal = input.referencedFacts["current_goal"],
           responseGoal != currentGoal {
            violations.append(
                BASConsistencyViolation(
                    kind: .factConflict,
                    message: "Current goal drifted from \(currentGoal) to \(responseGoal)."
                )
            )
        }

        let normalizedRules = input.truthState.personaRules.map { $0.lowercased() }
        let normalizedResponse = input.responseText.lowercased()

        if normalizedRules.contains(where: { $0.contains("句子短") || $0.contains("short") || $0.contains("brief") }),
           input.responseText.count > 280 {
            violations.append(
                BASConsistencyViolation(
                    kind: .personaDrift,
                    message: "Response exceeded the brevity rule for the current persona."
                )
            )
        }

        if normalizedRules.contains(where: { $0.contains("不批评") || $0.contains("non-judgmental") || $0.contains("gentle") }),
           ["you should have", "that was wrong", "obviously", "you failed"].contains(where: normalizedResponse.contains) {
            violations.append(
                BASConsistencyViolation(
                    kind: .personaDrift,
                    message: "Response tone drifted outside the non-judgmental persona boundary."
                )
            )
        }

        return BASConsistencyCheckResult(violations: violations)
    }
}
