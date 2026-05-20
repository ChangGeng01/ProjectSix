import XCTest
@testable import Before

final class BeforeProductBootstrapSemanticsTests: XCTestCase {
    func testDefaultTemplateSeedsStayStableForBeforeHost() {
        let now = Date(timeIntervalSince1970: 1_744_000_000)
        let seeds = BeforeProductBootstrapSemantics.defaultTemplateSeeds(now: now)

        XCTAssertEqual(
            seeds.map(\.id),
            [
                "tomorrow_box_interrupt",
                "brief_warm_nudge",
                "reflective_question",
                "slow_delay_guard"
            ]
        )
        XCTAssertTrue(seeds.allSatisfy { $0.createdAt == now && $0.updatedAt == now })
        XCTAssertEqual(seeds.map(\.modeID), [
            DecisionMode.quick.substrateModeID,
            DecisionMode.quick.substrateModeID,
            DecisionMode.mirror.substrateModeID,
            DecisionMode.mirror.substrateModeID
        ])
    }

    func testFailureSynthesisStaysHostOwnedAndExtractsBeforeSpecificGuards() {
        let lateNight = localDate(year: 2026, month: 4, day: 11, hour: 23)
        let events = [
            makeEvent(
                createdAt: lateNight,
                finalAction: .goAheadAnyway,
                reflectionOutcome: .regrettedIt
            ),
            makeEvent(
                createdAt: lateNight.addingTimeInterval(-3600),
                finalAction: .continueMindfully,
                reflectionOutcome: .feltEmptier
            ),
            makeEvent(
                createdAt: lateNight.addingTimeInterval(-7200),
                finalAction: .wait90s,
                reflectionOutcome: .betterThanExpected
            )
        ]

        let seeds = BeforeProductBootstrapSemantics.synthesizedFailurePatternSeeds(
            from: events,
            now: lateNight
        )

        XCTAssertEqual(seeds.map(\.id), ["night_fast_path_failure", "proceed_without_pause_failure"])
        XCTAssertTrue(seeds.allSatisfy { $0.modeID == DecisionMode.quick.substrateModeID })
        XCTAssertEqual(seeds.first?.evidenceCount, 2)
        XCTAssertEqual(seeds.last?.evidenceCount, 2)
    }

    private func makeEvent(
        createdAt: Date,
        finalAction: CheckAction,
        reflectionOutcome: ReflectionOutcome
    ) -> CheckEvent {
        CheckEvent(
            createdAt: createdAt,
            scenario: .buy,
            motivation: .stressed,
            expectedOutcome: .temporaryRelief,
            controlLevel: .no,
            note: "Need to slow down.",
            currentPerspective: "Act now",
            afterPerspective: "Wait until morning",
            verdict: .pause,
            finalAction: finalAction,
            reflectionOutcome: reflectionOutcome,
            entrySource: .app
        )
    }

    private func localDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone.autoupdatingCurrent
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date ?? .distantPast
    }
}
