import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

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

            SupportView()
                .environmentObject(appModel.supportInbox)
                .environmentObject(appModel.sharedLifeStore)
                .tabItem {
                    Label("Support", systemImage: "person.2")
                }
                .tag(AppTab.support)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(AppTab.history)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.settings)
        }
        .sheet(item: $appModel.activeQuickSession) { session in
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
        }
        .onChange(of: appModel.activeQuickSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .sheet(item: $appModel.activeBalanceSession) { session in
            BalanceBoardView(session: session)
                .environmentObject(appModel)
        }
        .onChange(of: appModel.activeBalanceSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .sheet(item: $appModel.activeMirrorSession) { session in
            MirrorWorkspaceView(session: session)
                .environmentObject(appModel)
        }
        .onChange(of: appModel.activeMirrorSession?.id) { _, _ in
            appModel.syncWorkspacePersistence()
        }
        .sheet(item: $appModel.reflectionContext) { context in
            ReflectionPromptView(context: context)
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
}
