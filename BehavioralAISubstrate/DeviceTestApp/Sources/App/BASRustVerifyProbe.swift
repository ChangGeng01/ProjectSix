// MARK: - BASRustVerifyProbe
// chapter 一千零二十七 / M3900 — on-device iOS Rust verify
//
// ## Mandate
//
// User mandate「全面 修复」 → systematic ship of the audited
// coverage-widening backlog,one chapter per cascade。 ch 1027 is
// the cheapest(verify-only)per the 2026-05-29 pre-ship audit。
//
// ## What the audit found(Docs/CH_1024_PLUS_OPTIMIZATION_BACKLOG.md
// "Audit 1 — ch 1027 iOS Rust:ALREADY DONE")
//
// The BACKLOG's original "iOS has no Rust,major infra needed"(HIGH,
// multi-session)was a MISDIAGNOSIS。 The iOS arm64 Rust slice has been
// built + git-committed since ch 707/M2191:
//   - `Vendor/bas-rust-binaries/BASRustMemoryTracker.xcframework/`
//     `ios-arm64/libbas_memory_usage_tracker.a`(21.6 MB,250 `bas_`
//     exported symbols = same count as the macOS slice)
//   - Ships as a STATIC `.a` linked into the app's own Mach-O — that's
//     why there's no separate `.dylib`(the original "no dylib =
//     no Rust" inference was wrong)
//
// ## Build-time verification already done(this chapter)
//
// `nm` on the built `BASDeviceTestApp.debug.dylib` confirmed all
// `bas_*_abi_version` symbols present as DEFINED text(`T`,not `U`
// undefined)— so SPM did NOT dead-strip the static archive(the one
// risk the audit flagged)。 Real Rust logic symbols
// (`bas_agent_fabric::winner::pick_winner` etc.)are also present。
//
// ## Runtime verification(this probe)
//
// Build-time symbol presence proves linkage;this probe proves
// RUNTIME resolve + execution on a physical iPhone:
//   1. `BASRustABIRegistry.auditMismatches()` — aggregate check
//      (bundle crate count + bas-agent-fabric ABI probe)
//   2. 8 namespace `liveAbiVersion()` vs Swift-side `abiVersion`
//      constant — proves each crate's extern "C" symbol resolves +
//      the compiled-in ABI matches what Swift expects
//   3. `BASAgentFabricBridge.fnv1a64()` — proves Rust runs REAL
//      COMPUTE,not just constant returns:empty input must equal the
//      FNV-1a offset basis,a non-empty input must differ from it
//
// Emitted as `📊 ch1027 rust_verify …` lines(idevicesyslog-visible,
// same os.Logger pattern as ch 1025.4)。 The 10-hour ch 1025.7
// endurance already proved this INDIRECTLY(BASCognitiveBrain is
// Rust-backed via `import BASRustMemoryTrackerBinary`;0 crashes over
// 100 iters);this probe makes it EXPLICIT + repeatable per launch。

import Foundation
import os
import BASRuntimeCore

enum BASRustVerifyProbe {

    private static let log = Logger(
        subsystem: "com.changgeng.basdevicetest",
        category: "ch1027-rust-verify")

    /// FNV-1a 64-bit offset basis — the documented empty-input return
    /// of `BASAgentFabricBridge.fnv1a64`(BASInternalRustBridges.swift
    /// doc-comment line 572-573)。 Used to assert Rust compute is real。
    private static let fnvOffsetBasis: UInt64 = 0xcbf2_9ce4_8422_2325

    private struct ABICheck {
        let namespace: String
        let expected: Int32
        let live: Int32
        var ok: Bool { expected == live }
    }

    /// Run all Rust verification probes,emit detail lines,return a
    /// short verdict string for the UI surface。 Synchronous —
    /// each call is a microsecond-level extern "C" invocation。
    @discardableResult
    static func run() -> String {
        emit("📊 ch1027 rust_verify START")

        // ── 1. Aggregate audit(bundle crate count + agent-fabric ABI)
        let mismatches = BASRustABIRegistry.auditMismatches()
        let auditOK = mismatches.isEmpty
        emit("📊 ch1027 rust_verify auditMismatches count=" +
             "\(mismatches.count) " +
             (auditOK
                ? "ALL_MATCH"
                : "MISMATCHES=[\(mismatches.joined(separator: ";"))]"))

        // ── 2. Per-namespace liveAbiVersion vs Swift abiVersion
        let checks: [ABICheck] = [
            ABICheck(namespace: "leaseLife",
                     expected: BASLeaseLifeBridge.abiVersion,
                     live: BASLeaseLifeBridge.liveAbiVersion()),
            ABICheck(namespace: "mirrorBlade",
                     expected: BASMirrorBladeBridge.abiVersion,
                     live: BASMirrorBladeBridge.liveAbiVersion()),
            ABICheck(namespace: "presenceEye",
                     expected: BASPresenceEyeBridge.abiVersion,
                     live: BASPresenceEyeBridge.liveAbiVersion()),
            ABICheck(namespace: "hostConstitution",
                     expected: BASHostConstitutionBridge.abiVersion,
                     live: BASHostConstitutionBridge.liveAbiVersion()),
            ABICheck(namespace: "shadowTrial",
                     expected: BASShadowTrialBridge.abiVersion,
                     live: BASShadowTrialBridge.liveAbiVersion()),
            ABICheck(namespace: "worldPrior",
                     expected: BASWorldPriorBridge.abiVersion,
                     live: BASWorldPriorBridge.liveAbiVersion()),
            ABICheck(namespace: "atomLifecycle",
                     expected: BASAtomLifecycleBridge.abiVersion,
                     live: BASAtomLifecycleBridge.liveAbiVersion()),
            ABICheck(namespace: "agentFabric",
                     expected: BASAgentFabricBridge.abiVersion,
                     live: BASAgentFabricBridge.liveAbiVersion()),
        ]
        for c in checks {
            emit("📊 ch1027 rust_verify abi ns=\(c.namespace) " +
                 "expected=\(c.expected) live=\(c.live) " +
                 "ok=\(c.ok)")
        }
        let matched = checks.filter { $0.ok }.count
        emit("📊 ch1027 rust_verify abi_summary " +
             "resolved=\(checks.count)/8 matched=\(matched)/8")

        // ── 3. Real-compute proof via fnv1a64
        let emptyHash = BASAgentFabricBridge.fnv1a64(Data())
        let emptyOK = emptyHash == fnvOffsetBasis
        emit(String(format:
            "📊 ch1027 rust_verify fnv1a64_empty=0x%016llx " +
            "expected=0x%016llx ok=%@",
            emptyHash, fnvOffsetBasis, emptyOK ? "true" : "false"))

        let probeData = Data("ch1027-rust-verify".utf8)
        let probeHash = BASAgentFabricBridge.fnv1a64(probeData)
        let computeOK = probeHash != fnvOffsetBasis
        emit(String(format:
            "📊 ch1027 rust_verify fnv1a64_probe=0x%016llx " +
            "non_constant=%@",
            probeHash, computeOK ? "true" : "false"))

        // ── VERDICT
        let allOK = auditOK && matched == 8 && emptyOK && computeOK
        emit("📊 ch1027 rust_verify VERDICT all_ok=\(allOK) " +
             "(audit=\(auditOK) abi=\(matched)/8 " +
             "fnv_empty=\(emptyOK) fnv_compute=\(computeOK))")

        return allOK
            ? "✓ all_ok (8/8 abi, fnv real)"
            : "✗ FAIL (audit=\(auditOK) abi=\(matched)/8 " +
              "fnv_empty=\(emptyOK) fnv_compute=\(computeOK))"
    }

    private static func emit(_ line: String) {
        print(line)
        log.notice("\(line, privacy: .public)")
    }
}
