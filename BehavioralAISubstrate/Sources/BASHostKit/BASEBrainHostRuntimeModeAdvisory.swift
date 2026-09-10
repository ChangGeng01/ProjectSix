// MARK: - BASEBrainHostRuntimeModeAdvisory
// chapter 四百九十八 / M1370 — typed advisory surface
// for production host runtime-mode opt-in
//
// The plan (chapter 477 / M1332) called for EBrainHost
// RuntimeSynthesis to gain a `runtimeMode` configuration
// knob threading BASTurnRuntimeMode through to the engine。
// Chapter 477+ shipped the typed `BASTurnRuntimeMode` enum
// + the engine-side `runtimeMode` parameter,but production
// hosts (`BASHostRuntime.makeEBrainTurn`) still bypass the
// engine entirely — they go straight to
// `BASEBrainRuntimeCoordinator.runTurn(...)` (V1 path)。
//
// HONEST DOCTRINE NOTE — chapter 四百九十八:
// =============================================================
// This advisory surface ships the TYPED RUNTIME-MODE
// PREFERENCE that production hosts can EMIT。 The substrate
// does NOT yet route based on this preference — that
// requires touching the production V1 path in ways that
// risk byte-equality regression。
//
// The advisory exists so:
//   1. Hosts can record their preferred mode in audit
//      emission today (typed evidence)
//   2. Future production wire-in arc has a stable target
//      to grep + plan against
//   3. ADR-014 OPT-IN is preserved (default `.v1ByteEqual`
//      reads identically to "no advisory present")
//
// Chapter 499+ permit-fold + chapter 500+ V1 deletion will
// consume this surface IF the host-integration stress-sweep
// CI lane signals 0 divergences。 Until then,the advisory
// is observation only。

import Foundation

/// Typed advisory record for a production host's runtime-
/// mode preference。
public struct BASEBrainHostRuntimeModeAdvisory:
    Equatable, Hashable, Codable, Sendable
{

    /// The host's preferred runtime mode。
    public let preferredMode: BASTurnRuntimeMode

    /// Stable host identifier emitting the advisory。
    public let hostID: String

    /// When the advisory was recorded (millis since epoch)。
    public let recordedAtMs: Int64

    /// Whether the substrate honored the advisory or fell
    /// back to default v1ByteEqual path。 At chapter 498
    /// close-out,`wasHonored` is ALWAYS false — production
    /// wire-in is deferred to chapter 499+。
    public let wasHonored: Bool

    /// Typed reason codes describing why the advisory was
    /// or wasn't honored。 Empty when honored;populated
    /// with reason codes (e.g. "tier-1-deferred-no-host-
    /// integration-ci-lane") when not。
    public let reasonCodes: [String]

    public init(
        preferredMode: BASTurnRuntimeMode,
        hostID: String,
        recordedAtMs: Int64,
        wasHonored: Bool,
        reasonCodes: [String]
    ) {
        self.preferredMode = preferredMode
        self.hostID = hostID
        self.recordedAtMs = recordedAtMs
        self.wasHonored = wasHonored
        self.reasonCodes = reasonCodes
    }
}

// MARK: - BASEBrainHostRuntimeModeAdvisoryDoctrine

/// Doctrine namespace declaring how the substrate handles
/// host runtime-mode advisories at chapter 498 close-out。
public enum BASEBrainHostRuntimeModeAdvisoryDoctrine {

    /// The actual default mode the substrate uses today。
    /// ALWAYS `.v1ByteEqual` at chapter 498 close-out。
    public static let activeDefaultMode: BASTurnRuntimeMode =
        .v1ByteEqual

    /// Whether the substrate's production V1 path honors
    /// advisories OTHER THAN `.v1ByteEqual`。 At chapter
    /// 498 close-out,FALSE — wire-in is deferred to
    /// chapter 499+ host-integration stress-sweep CI work。
    public static let advisoryHonoredInProduction: Bool =
        false

    /// Reason codes the substrate emits when an advisory
    /// is NOT honored。 Used by audit walkers to surface
    /// the honest deferral signal。
    public static let unhonoredReasonCodes: [String] = [
        "tier-1-deferred-no-host-integration-ci-lane",
        "v1-byte-equality-preservation-required",
        "stress-sweep-dual-mode-0-divergence-not-yet-proven-in-host"
    ]

    /// Construct a typed advisory record reflecting the
    /// current substrate state for the given host + mode。
    /// At chapter 498 close-out:wasHonored == false for
    /// any mode != .v1ByteEqual。 .v1ByteEqual advisories
    /// are honored vacuously (the substrate already
    /// defaults to v1)。
    public static func advisoryFor(
        preferredMode: BASTurnRuntimeMode,
        hostID: String,
        recordedAtMs: Int64
    ) -> BASEBrainHostRuntimeModeAdvisory {
        let honored = preferredMode == .v1ByteEqual
            || advisoryHonoredInProduction
        return BASEBrainHostRuntimeModeAdvisory(
            preferredMode: preferredMode,
            hostID: hostID,
            recordedAtMs: recordedAtMs,
            wasHonored: honored,
            reasonCodes: honored
                ? []
                : unhonoredReasonCodes)
    }
}
