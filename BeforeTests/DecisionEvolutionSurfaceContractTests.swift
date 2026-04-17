import XCTest
@testable import Before

final class DecisionEvolutionSurfaceContractTests: XCTestCase {
    func testNarrativeFormattingSupportExposesSharedJoinAndCountContract() {
        XCTAssertEqual(
            DecisionEvolutionNarrativeFormattingSupport.joined(["alpha", "beta"]),
            "alpha • beta"
        )
        XCTAssertEqual(
            DecisionEvolutionNarrativeFormattingSupport.prefixedLine(
                prefix: "eBrain active kill switches:",
                values: ["force_guard_mode", "require_reviewed_writes"]
            ),
            "eBrain active kill switches: force_guard_mode • require_reviewed_writes"
        )
        XCTAssertEqual(
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Review audit",
                values: ["guardrail-a", "guardrail-b"]
            ),
            "Review audit: guardrail-a • guardrail-b"
        )
        XCTAssertNil(
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Review audit",
                values: []
            )
        )
        XCTAssertEqual(
            DecisionEvolutionNarrativeFormattingSupport.checkpointCountLine(
                2,
                suffix: DecisionEvolutionPendingReviewPresentationSupport.beforePromotionSuffix
            ),
            "2 checkpoint(s) still require review before promotion."
        )
    }

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
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationSupport.operatorHeadline(for: .surface))
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationSupport.operatorDetail(for: .surface))

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.compact.showsCheckpointHeadlines)
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationSupport.operatorHeadline(for: .compact))
        XCTAssertNil(DecisionEvolutionReleaseSummaryPresentationSupport.operatorDetail(for: .compact))

        XCTAssertFalse(DecisionEvolutionReleaseSummaryPresentationMode.mutationHub.showsCheckpointHeadlines)
        XCTAssertEqual(
            DecisionEvolutionReleaseSummaryPresentationSupport.operatorHeadline(for: .mutationHub),
            "Mutation hub"
        )
        XCTAssertNotNil(DecisionEvolutionReleaseSummaryPresentationSupport.operatorDetail(for: .mutationHub))
    }

    func testLineagePresentationSupportExposesSharedQueueAndSelectionCopy() {
        XCTAssertEqual(
            DecisionEvolutionLineagePresentationSupport.pendingReviewLineageNotice(
                pendingReviewLineageCount: 1,
                hasReleaseSummary: true
            ),
            "1 pending checkpoints still carry recovered lineage."
        )
        XCTAssertNil(
            DecisionEvolutionLineagePresentationSupport.pendingReviewLineageNotice(
                pendingReviewLineageCount: 1,
                hasReleaseSummary: false
            )
        )
        XCTAssertEqual(
            DecisionEvolutionLineagePresentationSupport.retainedPendingReviewFactsLine(
                lineageBackedCount: 2
            ),
            "2 lineage-backed review checkpoint(s) keep their recovered facts."
        )
        XCTAssertEqual(
            DecisionEvolutionLineagePresentationSupport.retainedSelectedFactsAfterApprovalLine(
                lineageBackedCount: 1
            ),
            "1 selected checkpoint(s) keep their recovered lineage facts after approval."
        )
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

    func testOperatorFooterPresentationSupportExposesReleaseSummaryAndKillSwitchContracts() {
        let releaseSummary = DecisionEvolutionOperatorFooterPresentationSupport.releaseSummary(
            surfaceContract: .home,
            navigationOptions: DecisionEvolutionSurfaceContract.home.navigationSurfaceOptions()
        )
        XCTAssertEqual(releaseSummary.headline, "Mutations are centralized in Evolution Control")
        XCTAssertEqual(
            releaseSummary.detail,
            DecisionEvolutionMutationRoutingPresentationSupport.readFirstOperatorDetail
        )
        XCTAssertEqual(releaseSummary.interactionMode, .observeAndRoute)
        XCTAssertTrue(releaseSummary.routesMutationsToControlCenter)
        XCTAssertFalse(releaseSummary.showsDetail)
        XCTAssertEqual(releaseSummary.controlCenterStyle, .primary)
        XCTAssertEqual(releaseSummary.adjacentShortcutStyle, .secondary)
        XCTAssertEqual(
            releaseSummary.navigationRowPresentation.controlCenterTitle,
            "Open control center"
        )

        let killSwitch = DecisionEvolutionOperatorFooterPresentationSupport.killSwitchPanel(
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions()
        )
        XCTAssertEqual(killSwitch.headline, "Mutations are centralized in Evolution Control")
        XCTAssertEqual(killSwitch.interactionMode, .observeAndRoute)
        XCTAssertTrue(killSwitch.routesMutationsToControlCenter)
        XCTAssertFalse(killSwitch.showsDetail)
        XCTAssertEqual(killSwitch.controlCenterStyle, .primary)
        XCTAssertEqual(killSwitch.adjacentShortcutStyle, .secondary)
    }

    func testOperatorFooterPresentationSupportExposesPilotAndCheckpointContracts() {
        let pilot = DecisionEvolutionOperatorFooterPresentationSupport.pilotControl(
            surfaceContract: .home,
            navigationOptions: DecisionEvolutionSurfaceContract.home.navigationSurfaceOptions()
        )
        XCTAssertEqual(pilot.interactionMode, .observeAndRoute)
        XCTAssertTrue(pilot.routesMutationsToControlCenter)
        XCTAssertTrue(pilot.showsDetail)
        XCTAssertEqual(pilot.controlCenterStyle, .primary)
        XCTAssertEqual(pilot.adjacentShortcutStyle, .tertiary)

        let checkpoint = DecisionEvolutionOperatorFooterPresentationSupport.checkpointAction(
            surfaceContract: .history,
            navigationOptions: DecisionEvolutionSurfaceContract.history.navigationSurfaceOptions()
        )
        XCTAssertEqual(checkpoint.interactionMode, .observeAndRoute)
        XCTAssertTrue(checkpoint.routesMutationsToControlCenter)
        XCTAssertTrue(checkpoint.showsDetail)
        XCTAssertEqual(checkpoint.controlCenterStyle, .primary)
        XCTAssertEqual(checkpoint.adjacentShortcutStyle, .secondary)
    }

    func testNavigationRowPresentationSupportExposesReadFirstAndMutationHubContracts() {
        let settings = DecisionEvolutionNavigationRowPresentationSupport.settingsReadFirst(
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions()
        )
        XCTAssertTrue(settings.routesMutationsToControlCenter)
        XCTAssertEqual(settings.controlCenterStyle, .primary)
        XCTAssertEqual(settings.adjacentShortcutStyle, .secondary)
        XCTAssertEqual(settings.historyTitle, DecisionEvolutionNavigationRowPresentationSupport.historyTitle)
        XCTAssertEqual(settings.portraitTitle, DecisionEvolutionNavigationRowPresentationSupport.portraitTitle)
        XCTAssertEqual(
            DecisionEvolutionMutationRoutingPresentationSupport.routedPilotDetail(),
            "See release blockers and queue state here, then jump into Evolution Control for checkpoint mutations."
        )

        let pilot = DecisionEvolutionNavigationRowPresentationSupport.pilotMutationHub(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true
            )
        )
        XCTAssertFalse(pilot.routesMutationsToControlCenter)
        XCTAssertEqual(pilot.controlCenterStyle, .tertiary)
        XCTAssertEqual(pilot.adjacentShortcutStyle, .tertiary)
        XCTAssertEqual(pilot.historyTitle, DecisionEvolutionNavigationRowPresentationSupport.historyTitle)
        XCTAssertEqual(pilot.portraitTitle, DecisionEvolutionNavigationRowPresentationSupport.portraitTitle)
    }

    func testNavigationRowPresentationSupportExposesCheckpointMutationHubContract() {
        let checkpoint = DecisionEvolutionNavigationRowPresentationSupport.checkpointMutationHub(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )

        XCTAssertFalse(checkpoint.routesMutationsToControlCenter)
        XCTAssertEqual(checkpoint.controlCenterStyle, .secondary)
        XCTAssertEqual(checkpoint.adjacentShortcutStyle, .secondary)
        XCTAssertTrue(checkpoint.navigationOptions.showHistoryShortcut)
        XCTAssertTrue(checkpoint.navigationOptions.showPortraitShortcut)
    }

    func testNavigationRowPresentationSupportExposesReadFirstSurfaceAndControlCenterCompanionContracts() {
        let homeRuntime = DecisionEvolutionNavigationRowPresentationSupport.readFirstSurface(
            surfaceContract: .home,
            navigationOptions: DecisionEvolutionSurfaceContract.home.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )
        XCTAssertTrue(homeRuntime.routesMutationsToControlCenter)
        XCTAssertEqual(homeRuntime.controlCenterStyle, .primary)
        XCTAssertEqual(homeRuntime.adjacentShortcutStyle, .secondary)
        XCTAssertTrue(homeRuntime.navigationOptions.showControlCenterShortcut)
        XCTAssertTrue(homeRuntime.navigationOptions.showHistoryShortcut)
        XCTAssertTrue(homeRuntime.navigationOptions.showPortraitShortcut)

        let controlCenter = DecisionEvolutionNavigationRowPresentationSupport.controlCenterCompanion(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            )
        )
        XCTAssertFalse(controlCenter.routesMutationsToControlCenter)
        XCTAssertEqual(controlCenter.controlCenterStyle, .secondary)
        XCTAssertEqual(controlCenter.adjacentShortcutStyle, .secondary)
        XCTAssertFalse(controlCenter.navigationOptions.showControlCenterShortcut)
        XCTAssertTrue(controlCenter.navigationOptions.showHistoryShortcut)
        XCTAssertTrue(controlCenter.navigationOptions.showPortraitShortcut)
    }

    func testBatchMutationPresentationSupportExposesMutationHubAndReadFirstContracts() {
        XCTAssertEqual(DecisionEvolutionBatchMutationLexiconSupport.headerTitle, "Batch mutation workspace")
        XCTAssertEqual(DecisionEvolutionBatchMutationLexiconSupport.selectAllTitle, "Select all")
        XCTAssertEqual(DecisionEvolutionBatchMutationLexiconSupport.reviewQueueTitle, "Review queue")
        XCTAssertEqual(DecisionEvolutionBatchMutationLexiconSupport.lineageBackedTitle, "Lineage-backed")
        XCTAssertEqual(DecisionEvolutionBatchMutationLexiconSupport.applySelectedTitle, "Apply selected")
        XCTAssertEqual(
            DecisionEvolutionBatchMutationLexiconSupport.emptySelectionSummary,
            "No checkpoints are selected yet. Pick a slice of the control surface, then run guarded batch mutations from here."
        )

        let mutationHub = DecisionEvolutionBatchMutationPresentationSupport.build(
            surfaceContract: .controlCenter
        )
        XCTAssertEqual(mutationHub.headerTitle, "Batch mutation workspace")
        XCTAssertEqual(
            mutationHub.headerDetail,
            "Select checkpoints from the control surface, then run guarded batch actions without drilling into every card."
        )
        XCTAssertEqual(
            mutationHub.emptySelectionLine,
            "Pick one or more checkpoints to unlock selection-scoped approve / mark-review / clear-lineage mutations here."
        )
        XCTAssertEqual(mutationHub.selectAllTitle, "Select all")
        XCTAssertEqual(mutationHub.reviewQueueTitle, "Review queue")
        XCTAssertEqual(mutationHub.automaticTitle, "Automatic")
        XCTAssertEqual(mutationHub.lineageBackedTitle, "Lineage-backed")
        XCTAssertEqual(mutationHub.clearSelectionTitle, "Clear")
        XCTAssertEqual(mutationHub.targetsPrefix, "Targets")
        XCTAssertEqual(
            mutationHub.targetsPrefix,
            DecisionEvolutionMutationLabelPresentationSupport.targetsPrefix
        )
        XCTAssertEqual(mutationHub.applySelectedTitle, "Apply selected")
        XCTAssertEqual(mutationHub.approveSelectedTitle, "Approve selected")
        XCTAssertEqual(mutationHub.markSelectedTitle, "Mark selected")
        XCTAssertEqual(mutationHub.clearSelectedLineageTitle, "Clear selected lineage")
        XCTAssertNil(mutationHub.readOnlyHeadline)
        XCTAssertNil(mutationHub.readOnlyDetail)

        let readFirst = DecisionEvolutionBatchMutationPresentationSupport.build(
            surfaceContract: .history
        )
        XCTAssertEqual(readFirst.selectAllTitle, "Select all")
        XCTAssertNil(readFirst.emptySelectionLine)
        XCTAssertEqual(readFirst.readOnlyHeadline, "Mutations are centralized in Evolution Control")
        XCTAssertEqual(
            readFirst.readOnlyDetail,
            "This surface stays aligned as a read-first status view. Open the control center to mutate checkpoints without splitting review facts across multiple shells."
        )
    }

    func testCheckpointActionPresentationSupportExposesMutationAndReadFirstContracts() {
        XCTAssertEqual(DecisionEvolutionCheckpointMutationLexiconSupport.markCheckpointTitle, "Mark checkpoint")
        XCTAssertEqual(
            DecisionEvolutionCheckpointMutationLexiconSupport.clearCheckpointLineageTitle,
            "Clear checkpoint lineage"
        )

        let mutationHub = DecisionEvolutionCheckpointActionPresentationSupport.build(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true,
                showPortraitShortcut: true
            ),
            applyReady: true,
            approvalState: .reviewSuggested,
            hasLineage: true
        )
        XCTAssertTrue(mutationHub.showsMutationActions)
        XCTAssertTrue(mutationHub.showsApplyAction)
        XCTAssertEqual(mutationHub.secondaryActionKind, .approve)
        XCTAssertTrue(mutationHub.showsClearLineageAction)
        XCTAssertNil(mutationHub.footerPresentation)
        XCTAssertNotNil(mutationHub.navigationPresentation)
        XCTAssertEqual(mutationHub.applyTitle, "Apply checkpoint")
        XCTAssertEqual(mutationHub.approveTitle, "Approve checkpoint")
        XCTAssertEqual(mutationHub.clearLineageTitle, "Clear checkpoint lineage")
        XCTAssertEqual(mutationHub.markTitle, "Mark checkpoint")

        let readFirst = DecisionEvolutionCheckpointActionPresentationSupport.build(
            surfaceContract: .history,
            navigationOptions: DecisionEvolutionSurfaceContract.history.navigationSurfaceOptions(
                showPortraitShortcut: true
            ),
            applyReady: true,
            approvalState: .automatic,
            hasLineage: true
        )
        XCTAssertFalse(readFirst.showsMutationActions)
        XCTAssertFalse(readFirst.showsApplyAction)
        XCTAssertNil(readFirst.secondaryActionKind)
        XCTAssertFalse(readFirst.showsClearLineageAction)
        XCTAssertNotNil(readFirst.footerPresentation)
        XCTAssertNil(readFirst.navigationPresentation)
    }

    func testKillSwitchPanelPresentationSupportExposesMutationAndReadFirstContracts() {
        XCTAssertEqual(
            DecisionEvolutionKillSwitchControlLexiconSupport.mutationHeaderDetail,
            "Promote runtime kill switches from suggestions into a real host-controlled policy surface."
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchControlLexiconSupport.readOnlyHeaderDetail(),
            "This surface shows the active runtime kill-switch policy. Open Evolution Control to mutate it."
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchControlLexiconSupport.recommendedLine(
                ids: ["thermal_guard", "tool_burst"]
            ),
            "Recommended: thermal_guard • tool_burst"
        )
        XCTAssertEqual(
            DecisionEvolutionKillSwitchControlLexiconSupport.recommendedLine(
                ids: ["thermal_guard", "tool_burst"]
            ),
            DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: DecisionEvolutionKillSwitchControlLexiconSupport.recommendedPrefix,
                values: ["thermal_guard", "tool_burst"]
            )
        )
        XCTAssertEqual(DecisionEvolutionKillSwitchControlLexiconSupport.applyRecommendedTitle, "Apply recommended")
        XCTAssertEqual(DecisionEvolutionKillSwitchControlLexiconSupport.clearActiveTitle, "Clear active switches")
        XCTAssertEqual(DecisionEvolutionKillSwitchControlLexiconSupport.enableTitle, "Enable")
        XCTAssertEqual(DecisionEvolutionKillSwitchControlLexiconSupport.disableTitle, "Disable")

        let mutationHub = DecisionEvolutionKillSwitchPanelPresentationSupport.build(
            surfaceContract: .controlCenter,
            navigationOptions: DecisionEvolutionSurfaceContract.controlCenter.navigationSurfaceOptions(
                showHistoryShortcut: true
            ),
            activeKillSwitchCount: 2,
            recommendedKillSwitchIDs: ["thermal_guard", "tool_burst"],
            unresolvedRecommendedCount: 1
        )
        XCTAssertEqual(mutationHub.headerTitle, "Kill-switch control plane")
        XCTAssertEqual(
            mutationHub.headerDetail,
            "Promote runtime kill switches from suggestions into a real host-controlled policy surface."
        )
        XCTAssertEqual(mutationHub.activeBadgeTitle, "2 ACTIVE")
        XCTAssertEqual(mutationHub.recommendedBadgeTitle, "1 RECOMMENDED")
        XCTAssertEqual(mutationHub.recommendedLine, "Recommended: thermal_guard • tool_burst")
        XCTAssertTrue(mutationHub.showsMutationActions)
        XCTAssertNil(mutationHub.footerPresentation)
        XCTAssertEqual(mutationHub.applyRecommendedTitle, "Apply recommended")
        XCTAssertEqual(mutationHub.clearActiveTitle, "Clear active switches")
        XCTAssertEqual(mutationHub.enableTitle, "Enable")
        XCTAssertEqual(mutationHub.disableTitle, "Disable")
        XCTAssertEqual(mutationHub.activeStateBadgeTitle, "ACTIVE")
        XCTAssertEqual(mutationHub.recommendedStateBadgeTitle, "RECOMMENDED")

        let readFirst = DecisionEvolutionKillSwitchPanelPresentationSupport.build(
            surfaceContract: .settings,
            navigationOptions: DecisionEvolutionSurfaceContract.settings.navigationSurfaceOptions(),
            activeKillSwitchCount: 0,
            recommendedKillSwitchIDs: [],
            unresolvedRecommendedCount: 0
        )
        XCTAssertEqual(
            readFirst.headerDetail,
            "This surface shows the active runtime kill-switch policy. Open Evolution Control to mutate it."
        )
        XCTAssertNil(readFirst.recommendedLine)
        XCTAssertFalse(readFirst.showsMutationActions)
        XCTAssertNotNil(readFirst.footerPresentation)
    }

    func testControlCenterSectionPresentationSupportExposesSharedNarrativeContracts() {
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.releaseReadinessTitle,
            "Release readiness"
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.releaseReadinessDetail,
            "One summary strip for rollout state, blockers, rollback readiness, and kill-switch posture."
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.releaseReadinessEmptyMessage,
            "Release readiness will appear here once a flight-deck summary is available."
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.operatorMutationHubTitle,
            "Operator mutation hub"
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.operatorMutationHubDetail,
            "Queue-wide pilot controls and selection-scoped checkpoint mutations now live in one guarded workspace."
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.checkpointSpotlightTitle,
            "Checkpoint spotlight"
        )
        XCTAssertEqual(
            DecisionEvolutionControlCenterNarrativeSupport.checkpointSpotlightDetail,
            "Keep the current active checkpoint and review head visible even as the queue evolves."
        )

        let releaseReadiness = DecisionEvolutionSectionPresentationSupport.controlCenter(.releaseReadiness)
        XCTAssertEqual(releaseReadiness.title, "Release readiness")
        XCTAssertEqual(
            releaseReadiness.detail,
            "One summary strip for rollout state, blockers, rollback readiness, and kill-switch posture."
        )
        XCTAssertEqual(
            releaseReadiness.emptyMessage,
            "Release readiness will appear here once a flight-deck summary is available."
        )

        let mutationHub = DecisionEvolutionSectionPresentationSupport.controlCenter(.operatorMutationHub)
        XCTAssertEqual(mutationHub.title, "Operator mutation hub")
        XCTAssertEqual(
            mutationHub.detail,
            "Queue-wide pilot controls and selection-scoped checkpoint mutations now live in one guarded workspace."
        )
        XCTAssertNil(mutationHub.emptyMessage)

        let checkpointSpotlight = DecisionEvolutionSectionPresentationSupport.controlCenter(.checkpointSpotlight)
        XCTAssertEqual(checkpointSpotlight.title, "Checkpoint spotlight")
        XCTAssertEqual(
            checkpointSpotlight.emptyMessage,
            "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this control center will show active risk, permit, rollback and review facts."
        )
    }

    func testSurfaceStatusPresentationSupportExposesSharedRefreshAndEmptyStateCopy() {
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.refreshTitle,
            "Refresh"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.doneTitle,
            "Done"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.refreshingTitle,
            "Refreshing…"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(for: .history),
            "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this summary will show its risk, permit, tickets, audit, and rollback readiness."
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(for: .settings),
            "No persisted checkpoint lineage is attached yet. Once review traffic appears, Settings will mirror the shared evolution workspace here."
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(for: .controlCenter),
            "No persisted checkpoint lineage is available yet. Once a checkpoint lands, this control center will show active risk, permit, rollback and review facts."
        )
        XCTAssertNil(
            DecisionEvolutionSurfaceStatusPresentationSupport.summaryEmptyMessage(for: .portrait)
        )

        let settings = DecisionEvolutionSurfaceStatusPresentationSupport.settingsReadFirstPresentation()
        XCTAssertEqual(
            DecisionEvolutionReadFirstNarrativeSupport.settingsTitle,
            "Read-first evolution control"
        )
        XCTAssertEqual(
            DecisionEvolutionReadFirstNarrativeSupport.settingsDetail,
            "Settings mirrors the shared evolution workspace, but routes any mutation work to the control center."
        )
        XCTAssertEqual(settings.title, DecisionEvolutionReadFirstNarrativeSupport.settingsTitle)
        XCTAssertEqual(
            settings.detail,
            DecisionEvolutionReadFirstNarrativeSupport.settingsDetail
        )
        XCTAssertEqual(settings.refreshTitle, "Refresh")
    }

    func testControlCenterHeaderAndCheckpointRolePresentationsExposeSharedCopyContracts() {
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle,
            "Evolution Control"
        )
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceLexiconSupport.controlCenterTitle,
            "Evolution control center"
        )
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceLexiconSupport.killSwitchControlPlaneTitle,
            "Kill-switch control plane"
        )
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceLexiconSupport.mutationCentralizedHeadline,
            "Mutations are centralized in Evolution Control"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.headline,
            "Mutation hub"
        )
        XCTAssertTrue(
            DecisionEvolutionMutationHubPresentationSupport.operatorDetail
                .contains("Apply, approve, rollback")
        )
        XCTAssertTrue(
            DecisionEvolutionMutationHubPresentationSupport.releaseSummaryDetail
                .contains("Apply, approve, rollback")
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.quickActionsTitle,
            "Quick actions"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.restoreActivePathTitle,
            "Restore active path"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.rollbackActivePathTitle,
            "Rollback active path"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.approveQueueTitle,
            "Approve queue"
        )
        XCTAssertEqual(
            DecisionEvolutionMutationHubPresentationSupport.clearQueueLineageTitle,
            "Clear queue lineage"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceTitleLexiconSupport.homeTitle,
            "Home runtime"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceTitleLexiconSupport.historyTitle,
            "History workbench"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceTitleLexiconSupport.portraitTitle,
            "Portrait overview"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceTitleLexiconSupport.settingsTitle,
            "Settings monitor"
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceTitleLexiconSupport.title(for: .controlCenter),
            DecisionEvolutionControlSurfaceLexiconSupport.controlCenterNavigationTitle
        )

        let header = DecisionEvolutionSectionPresentationSupport.controlCenterHeader()
        XCTAssertEqual(header.navigationTitle, "Evolution Control")
        XCTAssertEqual(header.title, "Evolution control center")
        XCTAssertEqual(
            header.detail,
            "Operate the full L13 review path from one place: active checkpoint, review head, pending queue, release readiness, rollback, and persisted lineage."
        )
        XCTAssertEqual(header.refreshTitle, "Refresh")
        XCTAssertEqual(header.dismissTitle, "Done")

        let activeRole = DecisionEvolutionSectionPresentationSupport.checkpointRole(.active)
        XCTAssertEqual(activeRole.title, "Active checkpoint")

        let reviewRole = DecisionEvolutionSectionPresentationSupport.checkpointRole(.reviewHead)
        XCTAssertEqual(reviewRole.title, "Review head")
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionTitle(for: .active),
            "Active checkpoint"
        )
        XCTAssertEqual(
            DecisionEvolutionControlSurfaceSummaryPresentationSupport.sectionTitle(for: .reviewHead),
            "Review head"
        )

        XCTAssertEqual(
            DecisionEvolutionSurfaceBadgePresentationSupport.pendingReviewBadge(count: 1),
            DecisionEvolutionSummaryBadgePresentation(title: "1 PENDING", tone: .orange)
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceBadgePresentationSupport.rollbackReadyBadge(count: 0),
            DecisionEvolutionSummaryBadgePresentation(title: "0 ROLLBACK READY", tone: .secondary)
        )
        XCTAssertEqual(
            DecisionEvolutionSurfaceBadgePresentationSupport.lineageBackedBadge(count: 1),
            DecisionEvolutionSummaryBadgePresentation(title: "1 LINEAGE-BACKED", tone: .ember)
        )
        XCTAssertNil(
            DecisionEvolutionSurfaceBadgePresentationSupport.lineageBackedBadge(count: 0)
        )
    }

    func testHistoryTrailPresentationSupportExposesSharedHeaderAndInventoryCopy() {
        let presentation = DecisionEvolutionHistoryTrailPresentationSupport.build()
        XCTAssertEqual(presentation.sectionTitle, "Evolution control center")
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.sectionSubtitle,
            "Checkpoint lineage, risk permits, review state, rollback readiness, and queue operations now stay visible in one full workspace."
        )
        XCTAssertEqual(presentation.sectionSubtitle, DecisionEvolutionHistoryTrailLexiconSupport.sectionSubtitle)
        XCTAssertEqual(DecisionEvolutionHistoryTrailLexiconSupport.workspaceTitle, "Evolution trail")
        XCTAssertEqual(presentation.workspaceTitle, DecisionEvolutionHistoryTrailLexiconSupport.workspaceTitle)
        XCTAssertEqual(presentation.refreshTitle, "Refresh")
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.queueSectionTitle,
            "Pending review queue"
        )
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.queueSectionDetail,
            "Every remaining review-suggested checkpoint stays operable here, not just the queue head."
        )
        XCTAssertEqual(presentation.queueSection.title, DecisionEvolutionHistoryTrailLexiconSupport.queueSectionTitle)
        XCTAssertEqual(
            presentation.queueSection.detail,
            DecisionEvolutionHistoryTrailLexiconSupport.queueSectionDetail
        )
        XCTAssertNil(presentation.queueSection.emptyMessage)
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.historySectionTitle,
            "Checkpoint history"
        )
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.historySectionDetail,
            "The full recovered trail stays browseable here even after the active/review spotlight changes."
        )
        XCTAssertEqual(
            presentation.historySection.title,
            DecisionEvolutionHistoryTrailLexiconSupport.historySectionTitle
        )
        XCTAssertEqual(
            presentation.historySection.detail,
            DecisionEvolutionHistoryTrailLexiconSupport.historySectionDetail
        )
        XCTAssertNil(presentation.historySection.emptyMessage)
        XCTAssertEqual(DecisionEvolutionHistoryTrailLexiconSupport.filterTitle, "Evolution filter")
        XCTAssertEqual(presentation.filterTitle, DecisionEvolutionHistoryTrailLexiconSupport.filterTitle)
        XCTAssertEqual(
            DecisionEvolutionHistoryTrailLexiconSupport.inventoryLine(
                checkpointCount: 4,
                pendingReviewCount: 2,
                rollbackReadyCount: 1
            ),
            "4 checkpoints • 2 pending review • 1 rollback-ready"
        )
        XCTAssertEqual(
            presentation.inventoryLine(
                checkpointCount: 4,
                pendingReviewCount: 2,
                rollbackReadyCount: 1
            ),
            "4 checkpoints • 2 pending review • 1 rollback-ready"
        )
    }

    func testHomeQueuePresentationSupportExposesSharedSummaryCopy() {
        XCTAssertEqual(DecisionEvolutionHomeQueueLexiconSupport.title, "Evolution review queue")
        XCTAssertEqual(
            DecisionEvolutionHomeQueueLexiconSupport.detail,
            "Home keeps the review head in spotlight, while the remaining queue stays visible here and mutations stay centralized in Evolution Control."
        )
        XCTAssertEqual(
            DecisionEvolutionHomeQueueLexiconSupport.queuedBadgeTitle(count: 2),
            "2 queued"
        )
        XCTAssertEqual(
            DecisionEvolutionHomeQueueLexiconSupport.countsLine(
                totalPendingReviewCount: 3,
                spotlightedPendingReviewCount: 1,
                queuedPendingReviewCount: 2
            ),
            "Total pending 3 • review head 1 • queue tail 2"
        )
        XCTAssertNil(
            DecisionEvolutionHomeQueueLexiconSupport.countsLine(
                totalPendingReviewCount: 2,
                spotlightedPendingReviewCount: 0,
                queuedPendingReviewCount: 2
            )
        )

        let presentation = DecisionEvolutionHomeQueuePresentationSupport.build(
            totalPendingReviewCount: 3,
            spotlightedPendingReviewCount: 1,
            queuedPendingReviewCount: 2
        )

        XCTAssertEqual(presentation.title, DecisionEvolutionHomeQueueLexiconSupport.title)
        XCTAssertEqual(
            presentation.detail,
            DecisionEvolutionHomeQueueLexiconSupport.detail
        )
        XCTAssertEqual(presentation.queuedBadgeTitle, DecisionEvolutionHomeQueueLexiconSupport.queuedBadgeTitle(count: 2))
        XCTAssertEqual(
            presentation.countsLine,
            DecisionEvolutionHomeQueueLexiconSupport.countsLine(
                totalPendingReviewCount: 3,
                spotlightedPendingReviewCount: 1,
                queuedPendingReviewCount: 2
            )
        )

        let queueOnlyPresentation = DecisionEvolutionHomeQueuePresentationSupport.build(
            totalPendingReviewCount: 2,
            spotlightedPendingReviewCount: 0,
            queuedPendingReviewCount: 2
        )
        XCTAssertNil(queueOnlyPresentation.countsLine)
    }
}
