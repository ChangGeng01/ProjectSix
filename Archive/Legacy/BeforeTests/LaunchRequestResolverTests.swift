import XCTest
@testable import Before

final class LaunchRequestResolverTests: XCTestCase {
    func testSharedIntentEnvelopeScenarioWinsAndPreservesPrompt() {
        let envelope = DecisionIntentEnvelope.quickCapture(
            entrySource: .shortcut,
            scenario: .buy,
            promptSeed: "  think twice  "
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(envelope),
            .quick(scenario: .buy, prompt: "think twice")
        )
    }

    func testSharedIntentEnvelopePreferredModeWinsWhenScenarioIsMissing() {
        let envelope = DecisionIntentEnvelope.openMode(
            entrySource: .shortcut,
            mode: .balance,
            promptSeed: "Which plan fits better?"
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(envelope),
            .mode(.balance, prompt: "Which plan fits better?")
        )
    }

    func testSharedIntentEnvelopePromptFallsBackToAutoRoutingWhenNoExplicitTargetExists() {
        let envelope = DecisionIntentEnvelope.routedInput(
            entrySource: .shortcut,
            promptSeed: "Should I leave this job?"
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(envelope),
            .routedPrompt("Should I leave this job?")
        )
    }

    func testEmptySharedIntentEnvelopeFallsBackToQuickMode() {
        let envelope = DecisionIntentEnvelope(
            kind: .routedInput,
            sourceSurface: .widget,
            entrySource: .homeWidgetSmall,
            requestedAt: .now
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(envelope),
            .quick(scenario: nil, prompt: "")
        )
    }

    func testSharedIntentEnvelopeSanitizedPromptSeedTrimsLegacyPromptAccess() {
        let envelope = DecisionIntentEnvelope(
            kind: .routedInput,
            sourceSurface: .shortcut,
            entrySource: .shortcut,
            promptSeed: "  shared trim  ",
            requestedAt: .now
        )

        XCTAssertEqual(envelope.sanitizedPromptSeed, "shared trim")
        XCTAssertEqual(
            LaunchRequestResolver.resolve(envelope),
            .routedPrompt("shared trim")
        )
    }

    func testLegacyPendingLaunchRequestForwardsToSharedIntentResolution() {
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            prompt: "  legacy trim  ",
            requestedAt: .now
        )

        XCTAssertEqual(request.sanitizedPrompt, "legacy trim")
        XCTAssertEqual(
            LaunchRequestResolver.resolve(request),
            LaunchRequestResolver.resolve(request.decisionIntentEnvelope)
        )
    }
}
