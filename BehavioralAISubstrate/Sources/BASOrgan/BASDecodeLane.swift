// MARK: - BASDecodeLane — Tranche A2 decode dual-lane policy (2026-06-12)
//
// The decode dual-lane MECHANISM already exists: `BASLLMExtractionEngine.extract(preset:)` (and the
// other LLM call sites) take a per-call `BASOrganPreset`, so a host can already elect greedy vs
// sampling per turn. What was missing is the PRINCIPLED chooser — this encodes the doctrine as callable
// code so hosts stop scattering preset literals.
//
// ## The two lanes
//
// - `.greedy` → `.greedyDeterministic` (temperature 0). ENGAGES the certified speculative decoder
//   (the gate requires temp==0) when the model has a curated draft pairing — **+31% decode, and the
//   output is byte-reproducible** (token-identical to greedy single-model; SPEC_DECODE_CERT_RESULTS.md).
//   Use for reproducible / deterministic / replay-spine / factual-extraction turns.
// - `.sampling` → `.core` (temperature 0.7). Single-model, diverse output. Use for creative /
//   user-facing generation where output variety matters more than speed/reproducibility.
//
// ## NOT an automatic change (ADR-014)
//
// This is a host-electable POLICY, not a default flip. Existing call sites keep their current presets
// until a host opts a turn into a lane — so adopting it changes no bytes by default. The runner's
// `BAS_GREEDY_SPEC_LANE` (Tranche A1) is the device-measurement first caller of the greedy lane.

import Foundation

/// A decode lane = a (preset, speculation-intent) choice for one turn.
public enum BASDecodeLane: String, Sendable, Equatable, Codable, CaseIterable {
    /// temp 0 → engages spec-decode (+31%), byte-reproducible.
    case greedy
    /// temp 0.7 → single-model, diverse.
    case sampling
    /// temp 0.1 → single-model, the historical low-commitment SCOUT default. Lets the policy NAME the preset
    /// every current default call site already uses, so a default can route THROUGH the policy byte-equal.
    case scout

    /// The `BASOrganPreset` a call site passes to realize this lane.
    public var preset: BASOrganPreset {
        switch self {
        case .greedy: return .greedyDeterministic
        case .sampling: return .core
        case .scout: return .scout
        }
    }

    /// True when this lane's output is byte-reproducible (greedy is; sampling/scout are not).
    public var isReproducible: Bool { self == .greedy }

    /// True when this lane's preset (temp 0) satisfies the adapter's downstream speculative-decode eligibility
    /// gate (`MLXOrganAdapter.requestEligibleForSpeculation`, which requires `preset.temperature == 0`). This is
    /// the BASOrgan-side end of the doctrine→mechanism contract: only `.greedy` engages spec-decode.
    public var engagesSpeculativeDecode: Bool { self == .greedy }
}

/// The principled greedy-vs-sampling chooser. Host elects per turn by its purpose.
public enum BASDecodeLanePolicy {

    /// What a turn needs from decode — the host classifies its turn into one of these.
    public enum Purpose: String, Sendable, Equatable, Codable, CaseIterable {
        /// Replay-spine / reproducible / deterministic turns — MUST be byte-reproducible.
        case deterministic
        /// Structured extraction / verification — benefits from greedy reproducibility + speed.
        case factual
        /// User-facing creative generation — output diversity matters more than speed.
        case creative
        /// The historical default for a call site that has NOT (yet) elected a lane — maps to `.scout`, so the
        /// policy can express "today's default" as a first-class purpose. Routing a default THROUGH this is
        /// byte-equal (ADR-014); flipping a call site from `.scoutDefault` to `.factual` is the separate,
        /// evidence-gated behavioral change (the certified greedy lane in production).
        case scoutDefault
    }

    /// Map a turn's purpose to its decode lane. `deterministic` + `factual` → greedy (eat the +31%
    /// + reproducibility); `creative` → sampling (diversity); `scoutDefault` → scout (today's byte-equal
    /// default). The single doctrine point — every preset-choosing call site resolves here.
    public static func lane(for purpose: Purpose) -> BASDecodeLane {
        switch purpose {
        case .deterministic, .factual: return .greedy
        case .creative: return .sampling
        case .scoutDefault: return .scout
        }
    }

    /// Convenience: the preset for a purpose (`lane(for:).preset`).
    public static func preset(for purpose: Purpose) -> BASOrganPreset {
        lane(for: purpose).preset
    }
}
