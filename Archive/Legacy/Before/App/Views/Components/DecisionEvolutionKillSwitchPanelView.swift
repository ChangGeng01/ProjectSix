import SwiftUI
import BASHostKit

struct DecisionEvolutionKillSwitchPanelView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    let activeKillSwitches: [BASKillSwitchID]
    let recommendedKillSwitchIDs: [String]
    let surfaceContract: DecisionEvolutionSurfaceContract
    let navigationOptions: DecisionEvolutionNavigationSurfaceOptions
    let afterMutation: (() -> Void)?

    init(
        activeKillSwitches: [BASKillSwitchID],
        recommendedKillSwitchIDs: [String],
        surfaceContract: DecisionEvolutionSurfaceContract,
        navigationOptions: DecisionEvolutionNavigationSurfaceOptions? = nil,
        afterMutation: (() -> Void)? = nil
    ) {
        self.activeKillSwitches = activeKillSwitches
        self.recommendedKillSwitchIDs = recommendedKillSwitchIDs
        self.surfaceContract = surfaceContract
        self.navigationOptions = navigationOptions ?? surfaceContract.navigationSurfaceOptions()
        self.afterMutation = afterMutation
    }

    private var recommendedKillSwitches: [BASKillSwitchID] {
        BASKillSwitchID.resolvePolicyIDs(recommendedKillSwitchIDs)
    }

    private var unresolvedRecommendedKillSwitches: [BASKillSwitchID] {
        recommendedKillSwitches.filter { !activeKillSwitches.contains($0) }
    }

    private var presentation: DecisionEvolutionKillSwitchPanelPresentation {
        DecisionEvolutionKillSwitchPanelPresentationSupport.build(
            surfaceContract: surfaceContract,
            navigationOptions: navigationOptions,
            activeKillSwitchCount: activeKillSwitches.count,
            recommendedKillSwitchIDs: recommendedKillSwitchIDs,
            unresolvedRecommendedCount: unresolvedRecommendedKillSwitches.count
        )
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(presentation.headerTitle)
                        .font(.headline)

                    Text(presentation.headerDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    DecisionEvolutionSummaryBadge(
                        title: presentation.activeBadgeTitle,
                        tint: activeKillSwitches.isEmpty ? .secondary : BeforeTheme.ember
                    )
                    DecisionEvolutionSummaryBadge(
                        title: presentation.recommendedBadgeTitle,
                        tint: unresolvedRecommendedKillSwitches.isEmpty ? .secondary : .orange
                    )
                }

                ForEach(BASKillSwitchID.allCases, id: \.rawValue) { killSwitch in
                    killSwitchRow(for: killSwitch)
                }

                if let recommendedLine = presentation.recommendedLine {
                    Text(recommendedLine)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if presentation.showsMutationActions {
                    HStack(spacing: 10) {
                        BeforeActionButton(
                            presentation.applyRecommendedTitle,
                            style: .secondary,
                            isEnabled: !unresolvedRecommendedKillSwitches.isEmpty
                        ) {
                            appModel.applyRecommendedEvolutionKillSwitches(unresolvedRecommendedKillSwitches.map(\.rawValue))
                            afterMutation?()
                        }

                        BeforeActionButton(
                            presentation.clearActiveTitle,
                            style: .tertiary,
                            isEnabled: !activeKillSwitches.isEmpty
                        ) {
                            appModel.clearEvolutionKillSwitches()
                            afterMutation?()
                        }
                    }
                } else if let footerPresentation = presentation.footerPresentation {
                    DecisionEvolutionOperatorActionFooterView(
                        presentation: footerPresentation
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func killSwitchRow(for killSwitch: BASKillSwitchID) -> some View {
        let isActive = activeKillSwitches.contains(killSwitch)
        let isRecommended = unresolvedRecommendedKillSwitches.contains(killSwitch)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(killSwitch.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BeforeTheme.ink)

                        if isActive {
                            DecisionEvolutionSummaryBadge(
                                title: presentation.activeStateBadgeTitle,
                                tint: BeforeTheme.ember
                            )
                        } else if isRecommended {
                            DecisionEvolutionSummaryBadge(
                                title: presentation.recommendedStateBadgeTitle,
                                tint: .orange
                            )
                        }
                    }

                    Text(killSwitch.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if presentation.showsMutationActions {
                    BeforeActionButton(
                        isActive ? presentation.disableTitle : presentation.enableTitle,
                        style: isActive ? .secondary : .primary
                    ) {
                        appModel.setEvolutionKillSwitch(killSwitch, enabled: !isActive)
                        afterMutation?()
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill((isActive ? BeforeTheme.ember : .white).opacity(isActive ? 0.12 : 0.55))
        )
    }
}
