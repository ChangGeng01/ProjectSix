# iOS 27 Adaptation — readiness assessment + checklist

> Audited 2026-06-09 (project on iOS 26.5 toolchain; device upgrading to iOS 27). Per 亏的不要上:
> nothing here is "done/adapted" until it has compiled against the iOS 27 SDK and re-certified on-device.

## TL;DR — the codebase is ALREADY iOS-27-ready; the gating item is the Mac's toolchain

The audit found **nothing in our code or config that blocks iOS 27**. The work is almost entirely
environment (install Xcode 27) → recompile → fix any new SDK deprecations → re-certify on-device.

## Readiness audit (facts)

| Item | Finding | iOS 27 impact |
|------|---------|----------------|
| Deployment target | iOS 18 (`Package.swift .iOS(.v18)`; xcodeproj `IPHONEOS_DEPLOYMENT_TARGET=18.0`) | ✅ none — an iOS-18-min app runs on iOS 27; keep 18 (broad device support) |
| SDKROOT | `iphoneos` (unpinned, not `iphoneos26.5`) | ✅ auto-uses the active Xcode's iOS SDK → iOS 27 once Xcode 27 is installed |
| Availability gates | only reach `iOS 26` (Apple Foundation Models in `AppleFoundationOrganAdapter[+Streaming].swift`) | ✅ `if #available(iOS 26, *)` is TRUE on 27 → those Apple-LLM paths activate; forward-compatible |
| Hardcoded version gates | none — OS version only logged (`operatingSystemVersionString`) | ✅ none |
| Swift language mode | app `SWIFT_VERSION = 5.10`; package `swift-tools-version: 6.0` | ✅ independent of the iOS SDK; leave as-is (don't bump speculatively) |

**Conclusion:** no speculative code changes are warranted now. Bumping the deploy target or Swift mode
without the iOS 27 SDK to verify would be a 亏的不要上 violation (claiming adaptation we can't compile).

## The gating item

This Mac has only the **iOS 26.5 SDK** (`xcodebuild -showsdks` → `iphoneos26.5`). To build/deploy to an
iOS 27 device you need **Xcode 27 (beta)** installed — until then, device builds fail with
"iOS 27 is not installed" (the same class as the current 26.5 platform glitch; the SDK + device platform
must match the device OS).

## Checklist — run after Xcode 27 is installed

1. **Confirm SDK:** `xcodebuild -showsdks | grep iphoneos` shows `iphoneos27.x`.
2. **Prepare the device:** unlock the iPhone; open Xcode → Window → Devices and Simulators → wait for
   "Preparing iPhone…" to finish (state goes from "connected" → ready).
3. **macOS regression baseline:** `swift test --disable-swift-testing` — fix any new
   Swift-27-toolchain warnings/errors. (Last-known-green this session: full suite 15058 passed;
   Metal suites 301 passed.)
4. **Device build:** rebuild `BASDeviceTestApp` for the iOS 27 device. Fix any iOS-27-SDK deprecations
   as they surface (none predicted from the audit).
5. **On-device re-cert (the REAL adaptation proof — 亏的不要上):**
   - Metal smoke: `scripts/run-device-app-cert.sh` — kernels run on the GPU with topK parity.
   - Endurance + watchdog: `scripts/run-endurance-watchdog.sh WEDGE_FAST=1` — **does the wedge still
     occur on iOS 27?** (a useful MLX-vs-OS control — see below).
   - ADR-038 §10 probe + `MLX_WEDGE_TRACE` localization (Phase 2): `/tmp/adr038_wedge_locate.sh`
     (the trace build + script are already staged; commit `bc5bae1b8`).
6. **Record honestly** in ADR-038 §11 (or a new ADR): iOS 27 is a **beta → results are diagnostic, not a
   GA cert baseline**. Re-cert for a real ship happens on the iOS 27 GA build.

## The wedge × iOS 27 (what to expect)

The decode wedge is **MLX-process-local** (GPU exonerated on-device — ADR-038 §10.2), so iOS 27 is
**unlikely to fix the root cause** (it lives in MLX's `scheduler` lost-completion-signal, not the OS).
Re-running on 27 is a clean control:
- **Still wedges** → reconfirms "it's MLX, not the OS" → localize + fix in MLX on 27.
- **Stops wedging** → the OS timing shifted the trigger probability, but the MLX bug is still latent
  (could resurface) → the Phase-2 MLX fix + the watchdog (both OS-independent) still apply.

Either way: the watchdog (test/cert auto-recovery, no reboot) and the MLX fix are **OS-version-independent**,
so the iOS 27 move does not invalidate the work already banked.
