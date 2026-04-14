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

    private var interactionMode: DecisionEvolutionControlInteractionMode {
        surfaceContract.interactionMode
    }

    private var recommendedKillSwitches: [BASKillSwitchID] {
        BASKillSwitchID.resolvePolicyIDs(recommendedKillSwitchIDs)
    }

    private var unresolvedRecommendedKillSwitches: [BASKillSwitchID] {
        recommendedKillSwitches.filter { !activeKillSwitches.contains($0) }
    }

    var body: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kill-switch control plane")
                        .font(.headline)

                    Text(
                        surfaceContract.allowsMutations
                            ? "Promote runtime kill switches from suggestions into a real host-controlled policy surface."
                            : "This surface shows the active runtime kill-switch policy. Open Evolution Control to mutate it."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    DecisionEvolutionSummaryBadge(
                        title: "\(activeKillSwitches.count) ACTIVE",
                        tint: activeKillSwitches.isEmpty ? .secondary : BeforeTheme.ember
                    )
                    DecisionEvolutionSummaryBadge(
                        title: "\(unresolvedRecommendedKillSwitches.count) RECOMMENDED",
                        tint: unresolvedRecommendedKillSwitches.isEmpty ? .secondary : .orange
                    )
                }

                ForEach(BASKillSwitchID.allCases, id: \.rawValue) { killSwitch in
                    killSwitchRow(for: killSwitch)
                }

                if !recommendedKillSwitchIDs.isEmpty {
                    Text("Recommended: \(recommendedKillSwitchIDs.joined(separator: " • "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if surfaceContract.allowsMutations {
                    HStack(spacing: 10) {
                        BeforeActionButton(
                            "Apply recommended",
                            style: .secondary,
                            isEnabled: !unresolvedRecommendedKillSwitches.isEmpty
                        ) {
                            appModel.applyRecommendedEvolutionKillSwitches(unresolvedRecommendedKillSwitches.map(\.rawValue))
                            afterMutation?()
                        }

                        BeforeActionButton(
                            "Clear active switches",
                            style: .tertiary,
                            isEnabled: !activeKillSwitches.isEmpty
                        ) {
                            appModel.clearEvolutionKillSwitches()
                            afterMutation?()
                        }
                    }
                } else if navigationOptions.showsAnyShortcut {
                    DecisionEvolutionOperatorActionFooterView(
                        interactionMode: interactionMode,
                        navigationOptions: navigationOptions,
                        routesMutationsToControlCenter: surfaceContract.routesMutationsToControlCenter,
                        showsDetail: false,
                        controlCenterStyle: .primary,
                        adjacentShortcutStyle: .secondary
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
                            DecisionEvolutionSummaryBadge(title: "ACTIVE", tint: BeforeTheme.ember)
                        } else if isRecommended {
                            DecisionEvolutionSummaryBadge(title: "RECOMMENDED", tint: .orange)
                        }
                    }

                    Text(killSwitch.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if surfaceContract.allowsMutations {
                    BeforeActionButton(
                        isActive ? "Disable" : "Enable",
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
