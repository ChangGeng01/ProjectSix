import XCTest
@testable import Before

@MainActor
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

    func testNavigationActionRowCanBeBuiltFromSharedPresentation() {
        let presentation = DecisionEvolutionNavigationRowPresentationSupport.pilotMutationHub(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true
            )
        )

        let row = DecisionEvolutionNavigationActionRow(presentation: presentation)

        XCTAssertEqual(row.navigationOptions, presentation.navigationOptions)
        XCTAssertFalse(row.routesMutationsToControlCenter)
        XCTAssertEqual(row.controlCenterTitle, "Control center")
        XCTAssertEqual(row.controlCenterStyle, .tertiary)
        XCTAssertEqual(row.adjacentShortcutStyle, .tertiary)
    }

    func testNavigationActionRowCanBeBuiltFromReadFirstAndCheckpointHubPresentations() {
        let readFirstPresentation = DecisionEvolutionNavigationRowPresentationSupport.settingsReadFirst(
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions(
                showControlCenterShortcut: true,
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )
        let readFirstRow = DecisionEvolutionNavigationActionRow(
            presentation: readFirstPresentation
        )
        XCTAssertTrue(readFirstRow.routesMutationsToControlCenter)
        XCTAssertEqual(readFirstRow.controlCenterTitle, "Open control center")
        XCTAssertEqual(readFirstRow.controlCenterStyle, .primary)
        XCTAssertEqual(readFirstRow.adjacentShortcutStyle, .secondary)
        XCTAssertEqual(readFirstRow.historyTitle, "Open History")
        XCTAssertEqual(readFirstRow.portraitTitle, "Open Portrait")

        let checkpointPresentation = DecisionEvolutionNavigationRowPresentationSupport.checkpointMutationHub(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showPortraitShortcut: true
            )
        )
        let checkpointRow = DecisionEvolutionNavigationActionRow(
            presentation: checkpointPresentation
        )
        XCTAssertFalse(checkpointRow.routesMutationsToControlCenter)
        XCTAssertEqual(checkpointRow.controlCenterTitle, "Control center")
        XCTAssertEqual(checkpointRow.controlCenterStyle, .secondary)
        XCTAssertEqual(checkpointRow.adjacentShortcutStyle, .secondary)
        XCTAssertEqual(checkpointRow.portraitTitle, "Open Portrait")
    }
}
