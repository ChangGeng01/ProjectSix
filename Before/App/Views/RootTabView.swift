import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var appModel: BeforeAppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(2)
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
        .sheet(item: $appModel.activeBalanceSession) { session in
            BalanceBoardView(session: session)
                .environmentObject(appModel)
        }
        .sheet(item: $appModel.activeMirrorSession) { session in
            MirrorWorkspaceView(session: session)
                .environmentObject(appModel)
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
