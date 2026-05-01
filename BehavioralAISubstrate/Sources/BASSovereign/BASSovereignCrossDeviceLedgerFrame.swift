import Foundation

// M296.3.x — typed cross-device ledger frame (uses M296.3
// vector-clock primitive).
//
// ## Why this exists
//
// `BASSovereignAuditLedger` (M87) carries entries that are
// hash-chained per device. When two devices need to merge their
// fragments into one shared timeline, "what came first" needs a
// causal verdict — which M296.3's `BASSovereignCrossDeviceClock`
// supplies. M296.3.x bundles the metadata ledger fragment merging
// will need: which audit entry, which device emitted it, and what
// the device's vector clock looked like at emission.
//
// `BASSovereignCrossDeviceLedgerFrame` is intentionally a
// reference-by-ID wrapper — it carries `auditEntryRef: String`
// rather than the entry itself. This decouples the cross-device
// metadata from the audit-entry schema (so future audit-entry
// migrations don't ripple into the cross-device layer) and lets
// callers transmit lightweight frames without serialising whole
// entries.
//
// ## Properties
//
// - **Pure value type.** Sendable + Equatable + Hashable +
//   Codable. Round-trips through JSON / SQLite blob etc. without
//   surprises.
// - **Causal compare delegates to the clock.** `compare(to:)`
//   forwards to `BASSovereignCrossDeviceClock.compare(to:)` —
//   ordering inherits the four-case verdict (before / equal /
//   after / concurrent).
// - **Origin device is recorded.** When two frames come back as
//   `.concurrent`, sync protocol can break ties by origin
//   `deviceID` ASC for determinism.
// - **No entry fetch.** Callers that have the actual audit
//   entry resolve `auditEntryRef` against their own storage.

public struct BASSovereignCrossDeviceLedgerFrame:
    Sendable, Equatable, Hashable, Codable
{
    /// Stable ID referencing the underlying `BASSovereignAuditEntry`.
    /// Hosts resolve this against their own audit storage.
    public let auditEntryRef: String

    /// Device that emitted this frame.
    public let originDeviceID: String

    /// Vector clock at the moment of emission. Other devices
    /// merge their own clocks against this when ingesting the
    /// frame.
    public let clock: BASSovereignCrossDeviceClock

    public init(
        auditEntryRef: String,
        originDeviceID: String,
        clock: BASSovereignCrossDeviceClock
    ) {
        self.auditEntryRef = auditEntryRef
        self.originDeviceID = originDeviceID
        self.clock = clock
    }

    /// Causal compare with another frame. Delegates to the
    /// clock; origin device is *not* used for tie-break here —
    /// concurrent stays concurrent. Sync protocols apply
    /// origin-asc tie-break themselves where they need a total
    /// order.
    public func compare(
        to other: BASSovereignCrossDeviceLedgerFrame
    ) -> BASSovereignCrossDeviceClock.Order {
        clock.compare(to: other.clock)
    }
}
