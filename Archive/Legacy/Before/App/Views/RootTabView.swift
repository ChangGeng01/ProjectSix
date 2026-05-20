import SwiftData
import SwiftUI

private enum RootTabPresentedSheet: Identifiable {
    case quick(QuickCheckSession)
    case balance(BalanceBoardSession)
    case mirror(MirrorWorkspaceSession)
    case reflection(ReflectionContext)
    case evolutionControl
    case sessionEngineControl

    var id: String {
        switch self {
        case .quick(let session):
            "quick:\(session.id)"
        case .balance(let session):
            "balance:\(session.id)"
        case .mirror(let session):
            "mirror:\(session.id)"
        case .reflection(let context):
            "reflection:\(context.id)"
        case .evolutionControl:
            "evolution-control"
        case .sessionEngineControl:
            "session-engine-control"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var appModel: BeforeAppModel
    @Query(sort: \TomorrowBoxItem.createdAt, order: .reverse) private var tomorrowItems: [TomorrowBoxItem]

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            TomorrowBoxView()
                .tabItem {
                    Label("Box", systemImage: "tray")
                }
                .tag(AppTab.box)
                .badge(tomorrowBoxBadge)

            SupportView()
                .environmentObject(appModel.supportInbox)
                .environmentObject(appModel.sharedLifeStore)
                .tabItem {
                    Label("Support", systemImage: "person.2")
                }
                .tag(AppTab.support)
                .badge(supportBadge)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(AppTab.history)
                .badge(evolutionHistoryBadge)

            SelfPortraitView()
                .tabItem {
                    Label("Portrait", systemImage: "person.crop.circle.badge.checkmark")
                }
                .tag(AppTab.portrait)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
                .badge(evolutionSettingsBadge)
        }
        .sheet(item: rootPresentedSheet) { sheet in
            rootSheetContent(for: sheet)
        }
        .onChange(of: appModel.activeQuickSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .onChange(of: appModel.activeBalanceSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .onChange(of: appModel.activeMirrorSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .fullScreenCover(item: $appModel.letGoContext) { context in
            LetGoView(context: context)
                .environmentObject(appModel)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !appModel.hasSeenOnboarding },
            set: { appModel.hasSeenOnboarding = !$0 }
        )) {
            OnboardingView {
                appModel.hasSeenOnboarding = true
            }
        }
    }

    private var rootPresentedSheet: Binding<RootTabPresentedSheet?> {
        Binding(
            get: { currentRootPresentedSheet },
            set: { newValue in
                guard newValue == nil, let presentedSheet = currentRootPresentedSheet else {
                    return
                }
                clear(presentedSheet)
            }
        )
    }

    private var currentRootPresentedSheet: RootTabPresentedSheet? {
        if let session = appModel.activeQuickSession {
            return .quick(session)
        }
        if let session = appModel.activeBalanceSession {
            return .balance(session)
        }
        if let session = appModel.activeMirrorSession {
            return .mirror(session)
        }
        if let context = appModel.reflectionContext {
            return .reflection(context)
        }
        if appModel.isEvolutionControlCenterPresented {
            return .evolutionControl
        }
        if appModel.isSessionEngineControlCenterPresented {
            return .sessionEngineControl
        }
        return nil
    }

    @ViewBuilder
    private func rootSheetContent(
        for sheet: RootTabPresentedSheet
    ) -> some View {
        switch sheet {
        case .quick(let session):
            QuickCheckView(session: session)
                .environmentObject(appModel)
                .sheet(
                    isPresented: Binding(
                        get: { session.isShowingWaitSheet },
                        set: { session.isShowingWaitSheet = $0 }
                    )
                ) {
                    WaitView(session: session)
                        .environmentObject(appModel)
                }
        case .balance(let session):
            BalanceBoardView(session: session)
                .environmentObject(appModel)
        case .mirror(let session):
            MirrorWorkspaceView(session: session)
                .environmentObject(appModel)
        case .reflection(let context):
            ReflectionPromptView(context: context)
                .environmentObject(appModel)
        case .evolutionControl:
            NavigationStack {
                DecisionEvolutionControlCenterView()
                    .environmentObject(appModel)
            }
        case .sessionEngineControl:
            NavigationStack {
                DecisionSessionEngineControlCenterView()
                    .environmentObject(appModel)
            }
        }
    }

    private func clear(
        _ sheet: RootTabPresentedSheet
    ) {
        switch sheet {
        case .quick:
            appModel.activeQuickSession = nil
        case .balance:
            appModel.activeBalanceSession = nil
        case .mirror:
            appModel.activeMirrorSession = nil
        case .reflection:
            appModel.reflectionContext = nil
        case .evolutionControl:
            appModel.dismissEvolutionControlCenter()
        case .sessionEngineControl:
            appModel.isSessionEngineControlCenterPresented = false
        }
    }

    private var tomorrowBoxBadge: Int {
        tomorrowItems.count
    }

    private var supportBadge: Int {
        appModel.supportInbox.activeRequests.count + appModel.sharedLifeStore.pendingItems.count
    }

    private var evolutionAttention: DecisionEvolutionAttentionSignal {
        appModel.makeEvolutionSurfaceState(
            contract: .settings
        ).attentionSignal
    }

    private var evolutionHistoryBadge: String? {
        guard evolutionAttention.pendingReviewCount > 0 else { return nil }
        return evolutionAttention.pendingReviewCount > 9
            ? "9+"
            : String(evolutionAttention.pendingReviewCount)
    }

    private var evolutionSettingsBadge: String? {
        evolutionAttention.badgeValue
    }
}
