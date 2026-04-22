import Foundation
import BASRuntimeCore

/// M77 — per-turn organ routing at the Qinao boundary.
///
/// Today `QinaoLoop.generateCandidates` forwards each `CandidateSeed`'s
/// `role` verbatim to the organ endpoint, and the built-in
/// `BASOrganRegistryEndpoint` maps that role to a fixed preset
/// (`.scout` = temp 0.1 / 192 tokens / deterministic; `.core` =
/// temp 0.7 / 1024 tokens / non-deterministic). That ignores the
/// routed `BASBudgetFrame` — so when L1's thermal twin is screaming
/// `.emergency`, the loop still happily asks for 1024 core-temp
/// tokens.
///
/// M77 closes that gap without touching the substrate:
///
/// 1. `QinaoOrganRoutingPolicy` is a public value type a host can
///    inject to nudge routing (e.g. "force scout under throttle",
///    "cool the temperature by 0.2 under emergency"). Defaults
///    preserve pre-M77 behavior so existing call sites stay
///    byte-compatible.
/// 2. `QinaoOrganRoutingDecision` is a public value the routing
///    decision function produces — role, temperature,
///    `maxOutputTokens`, `deterministic` flag, and reason codes
///    explaining why the decision is what it is. It's `Codable` so
///    hosts can log / diff / replay routing decisions.
/// 3. `QinaoOrganRouting.decide(budget:seedRole:policy:)` is a pure
///    static function that maps `(budget, seedRole, policy) →
///    decision`. No actor, no side effects, fully testable.
///
/// The decision function only consults
/// `budget.thermalGuardLevel` and `budget.precisionProfile` — it
/// deliberately *does not* read `budget.runMode` because the run-mode
/// type name contains a redaction-forbidden substring ("EBrain")
/// and would have to be mirrored. The two fields it does read are
/// already on the Qinao public boundary via M66 / M67 lifecycle
/// plumbing, so exposing them here adds zero new redaction surface.
///
/// # Public surface
///
/// - `QinaoOrganRoutingPolicy` — policy value (defaults preserve
///   pre-M77 behavior).
/// - `QinaoOrganRoutingDecision` — per-seed decision value.
/// - `QinaoOrganRouting.decide(...)` — static pure decision.
///
/// Neither `BASBudgetFrame` nor `BASThermalGuardLevel` /
/// `BASPrecisionProfile` need to be mirrored — they're already on
/// the Qinao public boundary via `QinaoLifecycle.currentReading()` +
/// `QinaoRuntime.prepareBudgetForTurn(_:)` (M66 / M67 / M69).
public extension QinaoLoop {

    /// Host-adjustable knobs for the routing decision. Defaults
    /// reproduce pre-M77 behavior (scout→scout preset / core→core
    /// preset / no thermal reshaping). Hosts can inject a custom
    /// policy to tighten or relax specific axes without editing the
    /// decision function.
    ///
    /// All fields are `Sendable` value types so the policy can be
    /// shared across actors and serialized to audit logs.
    struct QinaoOrganRoutingPolicy: Sendable, Equatable, Codable {
        /// Base temperature for scout role under nominal thermal.
        /// Default 0.1 matches `BASOrganPreset.scout`.
        public let scoutBaseTemperature: Double
        /// Base temperature for core role under nominal thermal.
        /// Default 0.7 matches `BASOrganPreset.core`.
        public let coreBaseTemperature: Double
        /// Default max output tokens for scout role. Default 192
        /// matches `BASOrganPreset.scout`.
        public let scoutMaxOutputTokens: Int
        /// Default max output tokens for core role. Default 1024
        /// matches `BASOrganPreset.core`.
        public let coreMaxOutputTokens: Int
        /// When true (default), thermal `.emergency` forces role to
        /// `.scout` regardless of the seed's requested role. This is
        /// the most protective setting; set false to let hosts keep
        /// core-role generation even under thermal emergency (at the
        /// caller's own heat risk).
        public let forceScoutUnderEmergency: Bool
        /// When true (default), thermal `.throttle` pins
        /// `deterministic = true` so hot-path re-runs converge. This
        /// keeps UI from showing variant outputs on a hot device.
        public let forceDeterministicUnderThrottle: Bool
        /// Temperature delta applied under thermal `.emergency`.
        /// Default `-0.20` cools the sampler; a positive value would
        /// heat it (not recommended).
        public let emergencyTemperatureDelta: Double
        /// Fraction of max-output-tokens to keep under `.minimal`
        /// precision profile. Default 0.5 halves tokens under the
        /// tightest budget. Clamped to `[0.1, 1.0]` by `decide(...)`.
        public let minimalPrecisionTokenFraction: Double

        public static let `default` = QinaoOrganRoutingPolicy(
            scoutBaseTemperature: 0.1,
            coreBaseTemperature: 0.7,
            scoutMaxOutputTokens: 192,
            coreMaxOutputTokens: 1024,
            forceScoutUnderEmergency: true,
            forceDeterministicUnderThrottle: true,
            emergencyTemperatureDelta: -0.20,
            minimalPrecisionTokenFraction: 0.5)

        public init(
            scoutBaseTemperature: Double,
            coreBaseTemperature: Double,
            scoutMaxOutputTokens: Int,
            coreMaxOutputTokens: Int,
            forceScoutUnderEmergency: Bool,
            forceDeterministicUnderThrottle: Bool,
            emergencyTemperatureDelta: Double,
            minimalPrecisionTokenFraction: Double
        ) {
            self.scoutBaseTemperature = scoutBaseTemperature
            self.coreBaseTemperature = coreBaseTemperature
            self.scoutMaxOutputTokens = scoutMaxOutputTokens
            self.coreMaxOutputTokens = coreMaxOutputTokens
            self.forceScoutUnderEmergency = forceScoutUnderEmergency
            self.forceDeterministicUnderThrottle =
                forceDeterministicUnderThrottle
            self.emergencyTemperatureDelta = emergencyTemperatureDelta
            self.minimalPrecisionTokenFraction =
                minimalPrecisionTokenFraction
        }
    }

    /// Output of `QinaoOrganRouting.decide(...)`. Carries the routed
    /// role (which may differ from the seed's requested role when
    /// thermal forces a downgrade), the chosen sampling parameters,
    /// and a `reasonCodes` array explaining every non-trivial
    /// adjustment made relative to the seed role's baseline.
    ///
    /// Reason-code vocabulary (stable, UI-keyable):
    /// - `"budget-absent"` — no routed budget; defaults used
    ///   verbatim.
    /// - `"thermal-emergency-forces-scout"` — seed requested core
    ///   but thermal `.emergency` triggered the policy's
    ///   `forceScoutUnderEmergency` to downgrade to scout.
    /// - `"thermal-emergency-cools-temperature"` — base temperature
    ///   was reduced by `policy.emergencyTemperatureDelta`.
    /// - `"thermal-throttle-forces-deterministic"` —
    ///   `deterministic` set to `true` due to thermal `.throttle`.
    /// - `"precision-minimal-reduces-tokens"` — `maxOutputTokens`
    ///   multiplied by `policy.minimalPrecisionTokenFraction` under
    ///   the `.minimal` precision profile.
    /// - `"seed-role-preserved"` — seed role used verbatim (no
    ///   thermal downgrade triggered); always emitted when budget
    ///   was present and thermal didn't force a downgrade.
    struct QinaoOrganRoutingDecision: Sendable, Equatable, Codable {
        public let role: OrganRole
        public let temperature: Double
        public let maxOutputTokens: Int
        public let deterministic: Bool
        public let reasonCodes: [String]

        public init(
            role: OrganRole,
            temperature: Double,
            maxOutputTokens: Int,
            deterministic: Bool,
            reasonCodes: [String]
        ) {
            self.role = role
            self.temperature = temperature
            self.maxOutputTokens = maxOutputTokens
            self.deterministic = deterministic
            self.reasonCodes = reasonCodes
        }
    }

    /// Namespace for the pure routing decision function. Static
    /// methods only — no state, no actor. `QinaoLoop` calls
    /// `decide(...)` once per seed inside `generateCandidates`; the
    /// resulting decision drives preset selection in the built-in
    /// `BASOrganRegistryEndpoint` (which conforms to
    /// `QinaoBudgetAwareOrganEndpoint`) or is ignored by endpoints
    /// that don't care (which only see `decision.role`).
    enum QinaoOrganRouting {

        /// Pure decision function. Given a routed budget (or nil),
        /// the seed's requested role, and a policy, return the
        /// decision that routes the organ call.
        ///
        /// Decision order of operations (each adds its own reason
        /// code when it fires):
        ///
        /// 1. If `budget == nil`, return defaults for `seedRole`
        ///    with reason `["budget-absent"]`. The scout/core
        ///    baseline matches pre-M77 behavior exactly.
        /// 2. Resolve role: `seedRole`, unless thermal is
        ///    `.emergency` and policy enables the force-scout
        ///    protection. Emits `"thermal-emergency-forces-scout"`
        ///    when the downgrade fires.
        /// 3. Pick base temperature for the resolved role.
        /// 4. Apply `emergencyTemperatureDelta` under `.emergency`.
        ///    Emits `"thermal-emergency-cools-temperature"`.
        /// 5. Pick `maxOutputTokens` from policy defaults for the
        ///    role; scale by `minimalPrecisionTokenFraction` when
        ///    `precisionProfile == .minimal`. Emits
        ///    `"precision-minimal-reduces-tokens"` when scaling
        ///    fires. Final value is `max(32, scaled)` to preserve a
        ///    sane minimum.
        /// 6. Pick `deterministic`: scout → `true` (scouts are
        ///    determinism-preferred), core → `false` by default,
        ///    overridden to `true` under `.throttle` when policy
        ///    enables the pinning protection. Emits
        ///    `"thermal-throttle-forces-deterministic"` when the
        ///    pin fires on core.
        /// 7. If nothing above forced a change (role preserved), add
        ///    `"seed-role-preserved"` so the decision always carries
        ///    at least one reason code.
        ///
        /// Final temperature is clamped to `[0, 2]` to match
        /// `BASOrganPreset`'s own clamping contract.
        public static func decide(
            budget: BASBudgetFrame?,
            seedRole: OrganRole,
            policy: QinaoOrganRoutingPolicy = .default
        ) -> QinaoOrganRoutingDecision {
            guard let budget = budget else {
                return Self.defaultDecision(
                    for: seedRole, policy: policy)
            }

            var reasonCodes: [String] = []

            // Step 2: resolve role
            let isEmergency = budget.thermalGuardLevel == .emergency
            let resolvedRole: OrganRole
            if isEmergency
                && policy.forceScoutUnderEmergency
                && seedRole == .core {
                resolvedRole = .scout
                reasonCodes.append("thermal-emergency-forces-scout")
            } else {
                resolvedRole = seedRole
            }

            // Step 3: base temperature for resolved role
            var temperature: Double = resolvedRole == .scout
                ? policy.scoutBaseTemperature
                : policy.coreBaseTemperature

            // Step 4: apply emergency delta
            if isEmergency {
                temperature += policy.emergencyTemperatureDelta
                reasonCodes.append(
                    "thermal-emergency-cools-temperature")
            }
            temperature = Self.clampTemperature(temperature)

            // Step 5: max output tokens
            let baseMax: Int = resolvedRole == .scout
                ? policy.scoutMaxOutputTokens
                : policy.coreMaxOutputTokens
            var maxOutputTokens = baseMax
            if budget.precisionProfile == .minimal {
                let fraction = Self.clampFraction(
                    policy.minimalPrecisionTokenFraction)
                maxOutputTokens = max(
                    32, Int(Double(baseMax) * fraction))
                reasonCodes.append(
                    "precision-minimal-reduces-tokens")
            }

            // Step 6: deterministic flag
            var deterministic = resolvedRole == .scout
            let isThrottle = budget.thermalGuardLevel == .throttle
            if isThrottle
                && policy.forceDeterministicUnderThrottle
                && resolvedRole == .core {
                deterministic = true
                reasonCodes.append(
                    "thermal-throttle-forces-deterministic")
            }

            // Step 7: preserved-role marker
            if resolvedRole == seedRole {
                reasonCodes.append("seed-role-preserved")
            }

            return QinaoOrganRoutingDecision(
                role: resolvedRole,
                temperature: temperature,
                maxOutputTokens: maxOutputTokens,
                deterministic: deterministic,
                reasonCodes: reasonCodes)
        }

        /// Fallback when no budget is routed. Uses policy defaults
        /// verbatim — scout/core baselines and role from seed. The
        /// resulting decision matches pre-M77 behavior so existing
        /// `generateCandidates(sessionID:seeds:)` callers stay
        /// byte-compatible.
        static func defaultDecision(
            for role: OrganRole,
            policy: QinaoOrganRoutingPolicy
        ) -> QinaoOrganRoutingDecision {
            let temperature: Double = role == .scout
                ? policy.scoutBaseTemperature
                : policy.coreBaseTemperature
            let maxOutputTokens: Int = role == .scout
                ? policy.scoutMaxOutputTokens
                : policy.coreMaxOutputTokens
            let deterministic = role == .scout
            return QinaoOrganRoutingDecision(
                role: role,
                temperature: Self.clampTemperature(temperature),
                maxOutputTokens: maxOutputTokens,
                deterministic: deterministic,
                reasonCodes: ["budget-absent"])
        }

        /// Clamp to `[0, 2]` matching `BASOrganPreset`'s own clamp
        /// contract. Keeps the decision's temperature feedable into
        /// a `BASOrganPreset(temperature:)` initializer without
        /// drift.
        static func clampTemperature(_ t: Double) -> Double {
            min(max(t, 0), 2)
        }

        /// Clamp token-fraction to `[0.1, 1.0]`. Below 0.1 we'd hit
        /// the 32-token floor anyway; above 1.0 makes no sense.
        static func clampFraction(_ f: Double) -> Double {
            min(max(f, 0.1), 1.0)
        }
    }
}

/// Protocol refinement: endpoints that want to honor the routing
/// decision (temperature / tokens / determinism) in addition to the
/// role should conform to this protocol. Endpoints that don't care
/// about per-turn routing (e.g. a simple host-supplied stub) can
/// stay on the base `QinaoOrganEndpoint` protocol and the loop will
/// pass them `decision.role` only.
///
/// The loop dispatches at call time via `as? QinaoBudgetAwareOrganEndpoint`,
/// so conformance is fully opt-in without breaking the existing
/// protocol contract.
public protocol QinaoBudgetAwareOrganEndpoint: QinaoOrganEndpoint {
    /// Produce a single draft body using the routed decision. The
    /// endpoint is free to pick how it applies `temperature`,
    /// `maxOutputTokens`, and `deterministic` — a CoreML-backed
    /// adapter will honor all three; a remote-LLM adapter with a
    /// fixed config might honor only `role` and ignore the rest;
    /// either way the `decision.reasonCodes` are available for
    /// logging / traces.
    func produceBody(
        prompt: String,
        context: [String],
        sessionID: String,
        decision: QinaoLoop.QinaoOrganRoutingDecision
    ) async throws -> QinaoLoop.OrganResponse
}
