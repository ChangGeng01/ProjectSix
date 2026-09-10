import SwiftUI
import QinaoSample

/// SwiftUI demo for the Qinao Runtime SDK.
///
/// `swift run QinaoSampleApp` opens a window with a provider
/// picker, prompt input, run/stream pair of buttons, and a
/// response/audit panel. Same `QinaoLoop` API surface as
/// `QinaoSampleHost` (M203) — just visible instead of CLI-only.
///
/// The actual UI lives in the `QinaoSample` library (M228) so
/// snapshot + behaviour tests can drive `ContentView` directly.
/// This file is now just the executable entry point — strip down
/// to @main + window scene; future demo additions go in the
/// library, not here.
@main
struct QinaoSampleApp: App {
    var body: some Scene {
        WindowGroup("Qinao Sample") {
            ContentView()
                .frame(minWidth: 600, idealWidth: 760,
                       minHeight: 460, idealHeight: 600)
        }
        #if canImport(AppKit)
        .windowResizability(.contentSize)
        #endif
    }
}
