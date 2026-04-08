import Foundation

enum LaunchRequestResolution: Equatable {
    case quick(scenario: ScenarioType?, prompt: String)
    case mode(DecisionMode, prompt: String)
    case routedPrompt(String)
}

enum LaunchRequestResolver {
    static func resolve(_ request: PendingLaunchRequest) -> LaunchRequestResolution {
        if let scenario = request.scenario {
            return .quick(
                scenario: scenario,
                prompt: sanitizedPrompt(from: request.prompt)
            )
        }

        if let preferredMode = request.preferredMode {
            return .mode(preferredMode, prompt: sanitizedPrompt(from: request.prompt))
        }

        let prompt = sanitizedPrompt(from: request.prompt)
        if !prompt.isEmpty {
            return .routedPrompt(prompt)
        }

        return .quick(scenario: nil, prompt: "")
    }

    private static func sanitizedPrompt(from prompt: String?) -> String {
        prompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
