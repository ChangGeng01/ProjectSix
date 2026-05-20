import Foundation

enum LaunchRequestResolution: Equatable {
    case quick(scenario: ScenarioType?, prompt: String)
    case mode(DecisionMode, prompt: String)
    case routedPrompt(String)
}

enum LaunchRequestResolver {
    static func resolve(_ envelope: DecisionIntentEnvelope) -> LaunchRequestResolution {
        envelope.launchRequestResolution
    }

    static func resolve(_ request: PendingLaunchRequest) -> LaunchRequestResolution {
        resolve(request.decisionIntentEnvelope)
    }
}
