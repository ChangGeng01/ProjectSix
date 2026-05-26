// MARK: - BASDeviceTestApp
// chapter 九百四十九 / M3450 — initial empty test-host shell
// chapter 九百九十五 / M3680 — host pipeline integration
//
// SwiftUI app target for the BAS iPhone Air device test runner。
// Originally an empty test-host shell (ch 949);ch 995 added
// `BASAgentFabricGate` activation surfacing so the device-side
// 3-mode smoke (`Docs/PHASE_8_CLOSE_SMOKE.md`) can read the
// fabric env-var gate state at glance during physical-device
// test runs。
//
// When `xcodebuild test -destination "platform=iOS,id=<UDID>"`
// runs:
//   1. App launches on the device (this file)
//   2. XCTest injects the test bundle
//   3. Tests run within the app process
//   4. Results stream back to xcodebuild via stdout
//
// The `fabricStatus` field reads BAS_AGENT_FABRIC etc. via
// `BASAgentFabricGate.activationFromEnvironment(...)` and
// surfaces "enabled (core)" / "enabled (all)" / "disabled" so
// the operator running the 3-mode smoke can verify mode
// activation visually before tests dispatch。

import SwiftUI
import BASHostKit

@main
struct BASDeviceTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var fabricStatus: String = "probing…"

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
            // ch 995:fabric env-var gate status surface
            Text("Fabric: \(fabricStatus)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onAppear {
            let activation = BASAgentFabricGate
                .activationFromEnvironment()
            if activation.fabricEnabled {
                fabricStatus =
                    "enabled (\(activation.tier.rawValue)) " +
                    "[\(activation.transcriptMode.rawValue)]"
            } else {
                fabricStatus = "disabled"
            }
        }
    }
}
