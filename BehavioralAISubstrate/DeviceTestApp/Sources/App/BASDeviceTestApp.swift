// MARK: - BASDeviceTestApp
// chapter 九百四十九 / M3450 — initial empty test-host shell
// chapter 九百九十五 / M3680 — host pipeline integration
// chapter 一千零二十五.4 / M3899 — endurance autostart entry
//
// SwiftUI app target for the BAS iPhone Air device test runner。
// Originally an empty test-host shell (ch 949);ch 995 added
// `BASAgentFabricGate` activation surfacing so the device-side
// 3-mode smoke (`Docs/PHASE_8_CLOSE_SMOKE.md`) can read the
// fabric env-var gate state at glance。 ch 1025.4 added the
// `BAS_ENDURANCE_AUTOSTART=1` env-var entry so endurance runs
// can execute as a standalone app process(no xcodebuild test
// controller required — see `BASEnduranceAppRunner.swift`)。
//
// Two modes:
//
// 1. **xcodebuild test mode**(legacy):
//    `xcodebuild test -destination "platform=iOS,id=<UDID>"` —
//    XCTest injects the test bundle,tests run inside this app
//    process,results stream to Mac via stdout。 Limitation:
//    competing xcodebuild on the Mac kills the test session
//    (see ch 1025 v4 diagnosis)。
//
// 2. **Endurance autostart mode**(ch 1025.4):
//    `xcrun devicectl device process launch --device <UDID> ` +
//    `--environment BAS_ENDURANCE_AUTOSTART=1 ` +
//    `com.changgeng.basdevicetest` —
//    App launches,reads the env var,spawns the endurance loop
//    inside the app process。 Mac can disconnect freely;the
//    iPhone-side run continues。 Log to stdout(via idevicesyslog)
//    + Documents/ch1025-endurance-<stamp>.log。
//
// The `fabricStatus` field reads BAS_AGENT_FABRIC etc. via
// `BASAgentFabricGate.activationFromEnvironment(...)`。

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
    @State private var rustVerify: String = "probing…"
    @StateObject private var endurance =
        BASEnduranceAppController.shared

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
            // ch 1027:on-device Rust verify verdict surface
            Text("Rust: \(rustVerify)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            // ch 1025.4:endurance autostart status surface
            Text("Endurance: \(endurance.status.label)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
            // ch 1027:on-device Rust verify — runs every launch,
            // proves Rust symbols resolve + execute on iPhone(not
            // just present in the binary)。 Microsecond-level extern
            // "C" calls,safe to run synchronously。
            rustVerify = BASRustVerifyProbe.run()
            // ch 1025.4:if BAS_ENDURANCE_AUTOSTART=1,kick off
            // the endurance loop。 No-op otherwise(legacy
            // xcodebuild test mode still works because the
            // controller simply stays idle)。
            endurance.autostartIfEnabled()
        }
    }
}
