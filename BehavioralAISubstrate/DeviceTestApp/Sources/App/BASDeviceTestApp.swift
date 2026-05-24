// MARK: - BASDeviceTestApp
// chapter 九百四十九 / M3450
//
// Minimal SwiftUI app target for the BAS iPhone Air device test
// runner。 The app itself is intentionally empty — it just hosts
// the test bundle so XCTest can run on a physical iOS device。
//
// When `xcodebuild test -destination "platform=iOS,id=<UDID>"`
// runs:
//   1. App launches on the device
//   2. XCTest injects the test bundle (BASDeviceTests.xctest)
//   3. Tests run within the app process (test host pattern)
//   4. Results stream back to xcodebuild via stdout
//
// No user-facing UI matters — the app exits as soon as the test
// bundle completes。 The blank「Hello」 screen is just for the
// brief moment the app is in the foreground during test run。

import SwiftUI

@main
struct BASDeviceTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("BAS Device Test Host")
                .font(.title2)
            Text("Running test bundle…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
