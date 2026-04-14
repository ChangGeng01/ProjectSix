import XCTest
@testable import Before

final class DecisionEvolutionNavigationActionRowTests: XCTestCase {
    func testNavigationActionRowDefaultsStayAlignedWithSharedNavigationContract() {
        let options = DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions(
            showControlCenterShortcut: true,
            showHistoryShortcut: false,
            showPortraitShortcut: true
        )

        let row = DecisionEvolutionNavigationActionRow(navigationOptions: options)

        XCTAssertTrue(row.navigationOptions.showsAnyShortcut)
        XCTAssertEqual(row.navigationOptions.preferredDestination, .controlCenter)
        XCTAssertEqual(row.controlCenterTitle, "Open control center")
        XCTAssertEqual(row.historyTitle, "Open History")
        XCTAssertEqual(row.portraitTitle, "Open Portrait")
    }

    func testNavigationActionRowFallsBackToHistoryThenPortraitWhenControlCenterShortcutIsHidden() {
        let options = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: false,
            showHistoryShortcut: true,
            showPortraitShortcut: true
        )

        let row = DecisionEvolutionNavigationActionRow(navigationOptions: options)

        XCTAssertTrue(row.navigationOptions.showsAnyShortcut)
        XCTAssertEqual(row.navigationOptions.preferredDestination, .history)
        XCTAssertEqual(
            row.navigationOptions.preferredDestination?.actionTitle(routesMutationsToControlCenter: true),
            "Open History"
        )
        XCTAssertEqual(
            row.navigationOptions.preferredDestination?.actionTitle(routesMutationsToControlCenter: false),
            "Open History"
        )
    }

    func testNavigationActionRowDerivesControlCenterTitleFromRoutingMode() {
        let options = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: true,
            showHistoryShortcut: false,
            showPortraitShortcut: false
        )

        let observeRow = DecisionEvolutionNavigationActionRow(
            navigationOptions: options,
            routesMutationsToControlCenter: true
        )
        XCTAssertEqual(observeRow.controlCenterTitle, "Open control center")

        let mutationHubRow = DecisionEvolutionNavigationActionRow(
            navigationOptions: options,
            routesMutationsToControlCenter: false
        )
        XCTAssertEqual(mutationHubRow.controlCenterTitle, "Control center")
    }

    func testNavigationActionRowHidesShortcutsWhenNavigationOptionsAreEmpty() {
        let row = DecisionEvolutionNavigationActionRow(
            navigationOptions: DecisionEvolutionNavigationSurfaceOptions(
                showControlCenterShortcut: false,
                showHistoryShortcut: false,
                showPortraitShortcut: false
            ),
            controlCenterTitle: "Inspect control center",
            controlCenterStyle: .tertiary,
            adjacentShortcutStyle: .secondary,
            historyTitle: "Inspect history",
            portraitTitle: "Inspect portrait"
        )

        XCTAssertFalse(row.navigationOptions.showsAnyShortcut)
        XCTAssertNil(row.navigationOptions.preferredDestination)
        XCTAssertEqual(row.controlCenterTitle, "Inspect control center")
        XCTAssertEqual(row.historyTitle, "Inspect history")
        XCTAssertEqual(row.portraitTitle, "Inspect portrait")
    }
}
