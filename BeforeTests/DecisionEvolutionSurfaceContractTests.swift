import XCTest
@testable import Before

final class DecisionEvolutionSurfaceContractTests: XCTestCase {
    func testSurfaceContractMatrixMatchesOperatorIntent() {
        let home = DecisionEvolutionSurfaceContract.contract(for: .home)
        let history = DecisionEvolutionSurfaceContract.contract(for: .history)
        let portrait = DecisionEvolutionSurfaceContract.contract(for: .portrait)
        let settings = DecisionEvolutionSurfaceContract.contract(for: .settings)
        let controlCenter = DecisionEvolutionSurfaceContract.contract(for: .controlCenter)

        XCTAssertEqual(home.interactionMode, .observeAndRoute)
        XCTAssertEqual(home.releaseSummaryMode, .surface)
        XCTAssertTrue(home.routesMutationsToControlCenter)
        XCTAssertFalse(home.allowsMutations)
        XCTAssertTrue(home.showsControlCenterShortcut)
        XCTAssertTrue(home.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(home.showsCheckpointActionBarInSummary)

        XCTAssertEqual(history.interactionMode, .observeAndRoute)
        XCTAssertEqual(history.releaseSummaryMode, .compact)
        XCTAssertTrue(history.routesMutationsToControlCenter)
        XCTAssertFalse(history.allowsMutations)
        XCTAssertTrue(history.showsControlCenterShortcut)
        XCTAssertTrue(history.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(history.showsCheckpointActionBarInSummary)

        XCTAssertEqual(portrait.interactionMode, .observeAndRoute)
        XCTAssertEqual(portrait.releaseSummaryMode, .surface)
        XCTAssertTrue(portrait.routesMutationsToControlCenter)
        XCTAssertFalse(portrait.allowsMutations)
        XCTAssertTrue(portrait.showsControlCenterShortcut)
        XCTAssertTrue(portrait.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertTrue(portrait.showsCheckpointActionBarInSummary)

        XCTAssertEqual(settings.interactionMode, .observeAndRoute)
        XCTAssertEqual(settings.releaseSummaryMode, .compact)
        XCTAssertTrue(settings.routesMutationsToControlCenter)
        XCTAssertFalse(settings.allowsMutations)
        XCTAssertTrue(settings.showsControlCenterShortcut)
        XCTAssertFalse(settings.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertFalse(settings.showsCheckpointActionBarInSummary)

        XCTAssertEqual(controlCenter.interactionMode, .mutationHub)
        XCTAssertEqual(controlCenter.releaseSummaryMode, .mutationHub)
        XCTAssertFalse(controlCenter.routesMutationsToControlCenter)
        XCTAssertTrue(controlCenter.allowsMutations)
        XCTAssertFalse(controlCenter.showsControlCenterShortcut)
        XCTAssertFalse(controlCenter.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertFalse(controlCenter.showsCheckpointActionBarInSummary)
    }

    func testReleaseSummaryPresentationModesExposeExpectedRenderingContract() {
        XCTAssertTrue(DecisionEvolutionReleaseSummaryPresentationMode.surface.showsCheckpointHeadlines)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.surface.operatorHeadline)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.surface.operatorDetail)

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.compact.showsCheckpointHeadlines)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.compact.operatorHeadline)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationMode.compact.operatorDetail)

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.showsCheckpointHeadlines)
        XCTAssertEqual(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.operatorHeadline, "Mutation hub")
        XCTAssertNotNil(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.operatorDetail)
    }

    func testSummarySurfaceOptionsDefaultToContractBehavior() {
        let settings = DecisionEvolutionSurfaceContract.settings.summarySurfaceOptions()
        XCTAssertFalse(settings.showCheckpointActionBar)
        XCTAssertTrue(settings.showControlCenterShortcut)
        XCTAssertFalse(settings.showHistoryShortcut)
        XCTAssertFalse(settings.showPortraitShortcut)

        let controlCenter = DecisionEvolutionSurfaceContract.controlCenter.summarySurfaceOptions()
        XCTAssertFalse(controlCenter.showCheckpointActionBar)
        XCTAssertFalse(controlCenter.showControlCenterShortcut)
    }

    func testSummarySurfaceOptionsAllowPerSurfaceShortcutOverridesWithoutBreakingDefaults() {
        let portrait = DecisionEvolutionSurfaceContract.portrait.summarySurfaceOptions(
            showHistoryShortcut: true
        )
        XCTAssertTrue(portrait.showCheckpointActionBar)
        XCTAssertTrue(portrait.showControlCenterShortcut)
        XCTAssertTrue(portrait.showHistoryShortcut)
        XCTAssertFalse(portrait.showPortraitShortcut)

        let settings = DecisionEvolutionSurfaceContract.settings.summarySurfaceOptions(
            showCheckpointActionBar: true,
            showPortraitShortcut: true
        )
        XCTAssertTrue(settings.showCheckpointActionBar)
        XCTAssertTrue(settings.showControlCenterShortcut)
        XCTAssertTrue(settings.showPortraitShortcut)
    }

    func testSettingsSurfaceRemainsReadFirstAndRoutesMutationsToControlCenter() {
        let settings = DecisionEvolutionSurfaceContract.settings

        XCTAssertTrue(settings.routesMutationsToControlCenter)
        XCTAssertFalse(settings.allowsMutations)
        XCTAssertEqual(settings.releaseSummaryMode, .compact)
        XCTAssertFalse(settings.showsEmbeddedReleaseSummaryInPilotPanel)
        XCTAssertFalse(settings.showsCheckpointActionBarInSummary)

        let summaryOptions = settings.summarySurfaceOptions()
        XCTAssertFalse(summaryOptions.showCheckpointActionBar)
        XCTAssertTrue(summaryOptions.showControlCenterShortcut)
        XCTAssertFalse(summaryOptions.showHistoryShortcut)
        XCTAssertFalse(summaryOptions.showPortraitShortcut)
    }

    func testNavigationSurfaceOptionsDefaultToControlCenterRoutingContract() {
        let settings = DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions()
        XCTAssertTrue(settings.showControlCenterShortcut)
        XCTAssertFalse(settings.showHistoryShortcut)
        XCTAssertFalse(settings.showPortraitShortcut)

        let controlCenter = DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        XCTAssertFalse(controlCenter.showControlCenterShortcut)
        XCTAssertFalse(controlCenter.showHistoryShortcut)
        XCTAssertFalse(controlCenter.showPortraitShortcut)
    }

    func testNavigationSurfaceOptionsAllowShortcutOverridesWithoutMutatingContractDefaults() {
        let home = DecisionEvolutionSurfaceContract.home.navigationSurfaceOptions(
            showControlCenterShortcut: false,
            showHistoryShortcut: true
        )
        XCTAssertFalse(home.showControlCenterShortcut)
        XCTAssertTrue(home.showHistoryShortcut)
        XCTAssertFalse(home.showPortraitShortcut)

        let portrait = DecisionEvolutionSurfaceContract.portrait.navigationSurfaceOptions(
            showPortraitShortcut: true
        )
        XCTAssertTrue(portrait.showControlCenterShortcut)
        XCTAssertFalse(portrait.showHistoryShortcut)
        XCTAssertTrue(portrait.showPortraitShortcut)
    }

    func testNavigationSurfaceOptionsExposeSharedShortcutAndDestinationSemantics() {
        let none = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: false,
            showHistoryShortcut: false,
            showPortraitShortcut: false
        )
        XCTAssertFalse(none.showsAnyShortcut)
        XCTAssertNil(none.preferredDestination)

        let historyOnly = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: false,
            showHistoryShortcut: true,
            showPortraitShortcut: true
        )
        XCTAssertTrue(historyOnly.showsAnyShortcut)
        XCTAssertEqual(historyOnly.preferredDestination, .history)

        let controlCenterPreferred = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: true,
            showHistoryShortcut: true,
            showPortraitShortcut: true
        )
        XCTAssertEqual(controlCenterPreferred.preferredDestination, .controlCenter)
        XCTAssertEqual(
            controlCenterPreferred.preferredDestination?.actionTitle(routesMutationsToControlCenter: true),
            "Open control center"
        )
        XCTAssertEqual(
            controlCenterPreferred.preferredDestination?.actionTitle(routesMutationsToControlCenter: false),
            "Control center"
        )
        XCTAssertEqual(
            DecisionEvolutionNavigationDestination.history.actionTitle(routesMutationsToControlCenter: true),
            "Open History"
        )
        XCTAssertEqual(
            DecisionEvolutionNavigationDestination.portrait.actionTitle(routesMutationsToControlCenter: false),
            "Open Portrait"
        )
    }

    func testCheckpointPanelNavigationOverridesStaySurfaceScoped() {
        let historyPanels = DecisionEvolutionSurfaceContract.history.navigationSurfaceOptions(
            showPortraitShortcut: true
        )
        XCTAssertTrue(historyPanels.showControlCenterShortcut)
        XCTAssertFalse(historyPanels.showHistoryShortcut)
        XCTAssertTrue(historyPanels.showPortraitShortcut)

        let portraitPanels = DecisionEvolutionSurfaceContract.portrait.navigationSurfaceOptions(
            showHistoryShortcut: true
        )
        XCTAssertTrue(portraitPanels.showControlCenterShortcut)
        XCTAssertTrue(portraitPanels.showHistoryShortcut)
        XCTAssertFalse(portraitPanels.showPortraitShortcut)

        let controlCenterPanels = DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions()
        XCTAssertFalse(controlCenterPanels.showControlCenterShortcut)
        XCTAssertFalse(controlCenterPanels.showHistoryShortcut)
        XCTAssertFalse(controlCenterPanels.showPortraitShortcut)
    }

    func testCheckpointNavigationOptionsExposePerSurfaceDefaults() {
        let home = DecisionEvolutionSurfaceContract.home.checkpointNavigationOptions
        XCTAssertTrue(home.showControlCenterShortcut)
        XCTAssertTrue(home.showHistoryShortcut)
        XCTAssertTrue(home.showPortraitShortcut)

        let settings = DecisionEvolutionSurfaceContract.settings.checkpointNavigationOptions
        XCTAssertTrue(settings.showControlCenterShortcut)
        XCTAssertTrue(settings.showHistoryShortcut)
        XCTAssertTrue(settings.showPortraitShortcut)

        let history = DecisionEvolutionSurfaceContract.history.checkpointNavigationOptions
        XCTAssertTrue(history.showControlCenterShortcut)
        XCTAssertFalse(history.showHistoryShortcut)
        XCTAssertTrue(history.showPortraitShortcut)

        let portrait = DecisionEvolutionSurfaceContract.portrait.checkpointNavigationOptions
        XCTAssertTrue(portrait.showControlCenterShortcut)
        XCTAssertTrue(portrait.showHistoryShortcut)
        XCTAssertFalse(portrait.showPortraitShortcut)

        let controlCenter = DecisionEvolutionSurfaceContract.controlCenter.checkpointNavigationOptions
        XCTAssertFalse(controlCenter.showControlCenterShortcut)
        XCTAssertFalse(controlCenter.showHistoryShortcut)
        XCTAssertFalse(controlCenter.showPortraitShortcut)
    }

    func testSummarySurfaceOptionsExposeNavigationOptionsProjection() {
        let summary = DecisionEvolutionSummarySurfaceOptions(
            showCheckpointActionBar: true,
            showControlCenterShortcut: true,
            showHistoryShortcut: false,
            showPortraitShortcut: true
        )

        XCTAssertEqual(
            summary.navigationOptions,
            DecisionEvolutionNavigationSurfaceOptions(
                showControlCenterShortcut: true,
                showHistoryShortcut: false,
                showPortraitShortcut: true
            )
        )
    }

    func testSummarySurfaceOptionsCanBeProjectedDirectlyFromNavigationOptions() {
        let navigation = DecisionEvolutionNavigationSurfaceOptions(
            showControlCenterShortcut: true,
            showHistoryShortcut: true,
            showPortraitShortcut: false
        )

        let summary = DecisionEvolutionSurfaceContract.settings.summarySurfaceOptions(
            navigationOptions: navigation
        )

        XCTAssertFalse(summary.showCheckpointActionBar)
        XCTAssertEqual(summary.navigationOptions, navigation)
    }
}
