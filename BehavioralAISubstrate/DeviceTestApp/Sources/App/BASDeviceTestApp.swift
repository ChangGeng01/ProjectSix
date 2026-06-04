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
    @State private var mpsgraphVerify: String = "probing…"
    @State private var mambaVerify: String = "probing…"  // ch 1033
    @State private var ssmVerify: String = "probing…"  // ch1065 — SSM caution operator
    // ch 1025.9 #5 fix:guard probes against onAppear re-fire。
    @State private var probesStarted = false
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
            // ch 1034:on-device MPSGraph kernel verdict surface
            Text("MPSGraph: \(mpsgraphVerify)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            // ch 1033:on-device Mamba SSM verdict surface
            Text("Mamba: \(mambaVerify)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            // ch1065:on-device SSM caution OPERATOR (fire/raise/verdict-gates) surface
            Text("SSM caution: \(ssmVerify)")
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
            // ch1057:tap-to-start. Runs the ~1-hour endurance IN-APP on the phone,
            // fully decoupled from the Mac/xcodebuild — so it survives the host
            // idle-kill that capped prior runs at ~19 min. Tap, then walk away.
            Button {
                endurance.startManual()
            } label: {
                Text(endurance.status.isActive
                     ? "Endurance running…"
                     : "▶︎ Start 1-Hour Endurance")
                    .font(.callout).bold()
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
            }
            .buttonStyle(.borderedProminent)
            .disabled(endurance.status.isActive)
            .padding(.top, 8)
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
            // ch 1027 + 1034:on-device Rust + MPSGraph probes。
            // ch 1025.9 #5 fix:`onAppear` can fire repeatedly(view
            // re-appear / app backgrounding)。 Guard so probes run
            // ONCE per process — without it,a re-fire re-runs the Rust
            // probe AND re-spawns the MPSGraph Task,overlapping GPU
            // dispatch with a still-running prior invocation。
            if !probesStarted {
                probesStarted = true
                // Rust verify:microsecond extern "C" calls,sync-safe。
                rustVerify = BASRustVerifyProbe.run()
                // ch1065:SSM caution operator FIRST, in its OWN task — CPU-only (~2s),
                // so it captures within a brief foreground window, independent of (and
                // concurrent with) the slower GPU probe chain below (no GPU contention).
                Task { ssmVerify = await BASSSMCautionProbe.run() }
                // MPSGraph:async(kernel evaluate)。 Serial,never
                // concurrent with MLX(no GPU contention)。
                Task {
                    // MPSGraph cannot initialize a device on the iOS Simulator —
                    // `MPSGraphDeviceDescriptor initWithMPSGraphDevice:` throws an uncaught
                    // Obj-C NSException (NSArray insert nil) that Swift do/catch cannot
                    // intercept, hard-aborting the app (SIGABRT). The probe is a DEVICE-only
                    // check by design, so skip it on the simulator (run it on real hardware).
                    #if targetEnvironment(simulator)
                    mpsgraphVerify = "skipped (simulator)"
                    #else
                    mpsgraphVerify = await BASMPSGraphProbe.run()
                    #endif
                    // ch 1033:Mamba SSM after MPSGraph(serial,
                    // same Task → never overlap GPU dispatch)。 The Mamba harness handles
                    // gpuAvailable=false on the simulator gracefully (CPU scan still runs)。
                    mambaVerify = await BASMambaProbe.run()
                }
            }
            // ch 1025.4:if BAS_ENDURANCE_AUTOSTART=1,kick off
            // the endurance loop。 No-op otherwise(legacy
            // xcodebuild test mode still works because the
            // controller simply stays idle)。
            endurance.autostartIfEnabled()
        }
    }
}
