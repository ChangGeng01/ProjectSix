import Foundation

/// audit M-i MED-4 — the RdarProbe.runM4 burn-in deadline state machine, extracted
/// from the iOS-only DeviceTestApp into a pure, macOS-unit-testable value type.
///
/// The energy-per-token (M4) run must, at the 100%-battery plateau, decode WITHOUT
/// counting (the reading is pinned) until the battery first dips below the plateau,
/// then restart a fresh COUNTED window. The bug (cebea725a fixed inline, on-device
/// only): the counted window was armed unconditionally right after unplug, clobbering
/// the burn-in cap — so a plateau lasting longer than the window ended M4 mid-burn-in,
/// yielding an invalid/empty measurement. This models that logic as pure transitions
/// so the guard is deterministically verified on any Mac (the actual energy reading
/// stays device-only).
public struct BASBurnInDeadline: Equatable, Sendable {
    /// True while decoding at the 100% plateau WITHOUT counting (uncounted burn-in).
    public let burning: Bool
    /// Absolute deadline (epoch seconds) for the current phase.
    public let deadlineEpoch: Double
    /// Length of the counted measurement window.
    public let windowSec: Double
    /// Cap on the uncounted burn-in phase (safety bound; iOS holds "100%" ~10-20 min).
    public let burnCapSec: Double

    /// At unplug: if at the 100% plateau, enter uncounted burn-in bounded by the
    /// burn cap; otherwise arm the counted window immediately.
    public static func atUnplug(
        nowEpoch: Double, atPlateau: Bool, windowSec: Double, burnCapSec: Double
    ) -> BASBurnInDeadline {
        BASBurnInDeadline(
            burning: atPlateau,
            deadlineEpoch: nowEpoch + (atPlateau ? burnCapSec : windowSec),
            windowSec: windowSec, burnCapSec: burnCapSec)
    }

    /// A periodic sample. While burning, once the (unplugged) reading first dips
    /// below the plateau, burn-in is COMPLETE → restart a fresh counted window.
    /// Otherwise unchanged — crucially, the counted window is NEVER (re)armed while
    /// still burning, which is exactly the clobber MED-4 fixed.
    public func onSample(nowEpoch: Double, plugged: Bool, batteryPct: Double) -> BASBurnInDeadline {
        guard burning, !plugged, batteryPct < 99.5 else { return self }
        return BASBurnInDeadline(
            burning: false, deadlineEpoch: nowEpoch + windowSec,
            windowSec: windowSec, burnCapSec: burnCapSec)
    }

    /// Whether the current phase's deadline has passed.
    public func isExpired(nowEpoch: Double) -> Bool { nowEpoch >= deadlineEpoch }
}
