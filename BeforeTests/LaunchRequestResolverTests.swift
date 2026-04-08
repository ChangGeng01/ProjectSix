import XCTest
@testable import Before

final class LaunchRequestResolverTests: XCTestCase {
    func testScenarioWinsAndPreservesPrompt() {
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            preferredMode: .mirror,
            scenario: .buy,
            prompt: "  think twice  ",
            requestedAt: .now
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(request),
            .quick(scenario: .buy, prompt: "think twice")
        )
    }

    func testPreferredModeWinsWhenScenarioIsMissing() {
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            preferredMode: .balance,
            prompt: "Which plan fits better?",
            requestedAt: .now
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(request),
            .mode(.balance, prompt: "Which plan fits better?")
        )
    }

    func testPromptFallsBackToAutoRoutingWhenNoExplicitTargetExists() {
        let request = PendingLaunchRequest(
            entrySource: .shortcut,
            prompt: "Should I leave this job?",
            requestedAt: .now
        )

        XCTAssertEqual(
            LaunchRequestResolver.resolve(request),
            .routedPrompt("Should I leave this job?")
        )
    }

    func testEmptyRequestFallsBackToQuickMode() {
        let request = PendingLaunchRequest(entrySource: .homeWidgetSmall, requestedAt: .now)

        XCTAssertEqual(
            LaunchRequestResolver.resolve(request),
            .quick(scenario: nil, prompt: "")
        )
    }
}
