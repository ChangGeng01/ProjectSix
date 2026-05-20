import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        TabView {
            WatchQuickCaptureView()
            WatchTomorrowBoxView()
            WatchPauseView()
            WatchBrainGlanceView()
        }
        .tabViewStyle(.verticalPage)
    }
}
