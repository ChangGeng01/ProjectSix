// MARK: - BASAgentPersonaResolver
// chapter 九百六十六 / M3535 — Phase 4 ch1:Persona Studio resolver
//
// User design Section 11 + plan PHASE 4:Persona Studio formula
//
//   P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)
//
// Phase 4 ch1 ships the composition half (P_role ⊕ P_user ⊕ P_host)
// WITHOUT Risk + Sovereign clamping。 Those land in:
//
//   - ch 967:Risk gate clamping (monotonic clamp01,never lower risk)
//   - ch 968:Sovereign sentinel clamping (LOW tier force-default)
//
// ## Composition order
//
// Per the formula left-to-right:start from role template,layer
// user overlay,then layer host overlay。 Each layer only ALTERS
// fields per its visibility-tier permission:
//
//   HIGH tier:
//     - P_role applies all 9 numeric biases + tone as defaults
//     - P_user can override ALL 9 biases + tone
//     - P_host can override ALL 9 biases + tone (host wins ties
//       since host is sovereign-authorized)
//
//   MED tier:
//     - P_role applies all 9 + tone as defaults
//     - P_user can ONLY override tone + warmth + directness
//       (style + cadence dimensions) — cognitive biases are
//       role-template fixed
//     - P_host can override all 9 + tone (host has stronger
//       authority than user)
//
//   LOW tier:
//     - P_role applies all 9 + tone as defaults
//     - P_user OVERLAY IGNORED ENTIRELY (sovereign-sealed)
//     - P_host can override but only fields the host's sovereign
//       warrant grants (Phase 4 ch 968 enforces the warrant check;
//       this ch allows host to override anything)
//
// ## Clamp invariant
//
// All numeric biases (warmth/directness/skepticism/structureBias/
// creativityBias/challengeIntensity/comparisonBias/guardBias) MUST
// land in [0.0, 1.0]。 Composition clamps at the boundary — overlays
// that exceed are pinned to the bound (NOT rejected — better to
// silently saturate than fail the resolve call,since per ch 956.11
// CR1 the persona resolver runs hot every turn and failing closed
// breaks the live session)。
//
// ## Determinism
//
// Same inputs → byte-equal output。 Critical for trace replay (ch
// 959 trace log) — replay must reproduce the persona used per turn。

import Foundation

public enum BASAgentPersonaResolver {

    // MARK: - Resolve

    /// Compose a fully-resolved `BASAgentPersonaSpec` for the given
    /// agent。 Pure function — no actor / no I/O。 Per ch 957-965
    /// seat discipline。
    ///
    /// - Parameters:
    ///   - agentSpec: identity + visibility (visibility drives
    ///     which fields userOverlay can change)
    ///   - userOverlay: caller-supplied persona biases the user
    ///     wants applied。 Nil = no user customization (template
    ///     + host only)。
    ///   - hostOverlay: host-supplied persona biases for sovereign-
    ///     authorized overrides。 Nil = no host overrides。
    ///   - hostConstraintsRef:`hostConstitution:...` ref written
    ///     into the resulting persona spec for downstream Risk +
    ///     Sovereign clamps (ch 967/968)
    ///   - riskConstraintsRef:`riskGate:...` ref written for the
    ///     ch 967 Risk-clamp lookup
    ///   - sovereignConstraintsRef:`sovereignSentinel:...` ref
    ///     for ch 968 Sovereign-clamp lookup
    ///   - personaID:caller-supplied unique persona ID
    ///   - versionRef:`personaVersion:...` ref for the persona
    ///     version tree (Phase 4 ch 969 store)
    /// - Returns: composed persona spec WITHOUT Risk/Sovereign
    ///   clamps (those land in ch 967/968)
    public static func resolve(
        agentSpec: BASAgentSpec,
        userOverlay: BASAgentPersonaSpec? = nil,
        hostOverlay: BASAgentPersonaSpec? = nil,
        hostConstraintsRef: String = "",
        riskConstraintsRef: String = "",
        sovereignConstraintsRef: String = "",
        personaID: String,
        versionRef: String = ""
    ) -> BASAgentPersonaSpec {
        // Step 1:P_role — load template for this role
        let template =
            BASAgentPersonaRoleTemplates.template(
                for: agentSpec.role)

        // Visibility comes from the AGENT SPEC,not the template —
        // an agent with .low visibility wins even if the template
        // would suggest .high (defensive against template drift)。
        let visibility = agentSpec.visibility

        // Step 2:start composed = P_role
        var composed = ComposedPersona(template: template)

        // Step 3:apply userOverlay per visibility tier
        if let user = userOverlay {
            applyUserOverlay(
                &composed,
                user: user,
                visibility: visibility)
        }

        // Step 4:apply hostOverlay (host has stronger authority,
        // so it overlays AFTER user — host wins ties)
        if let host = hostOverlay {
            applyHostOverlay(
                &composed,
                host: host,
                visibility: visibility)
        }

        // Step 5:clamp all numeric fields to [0.0, 1.0]
        composed.clampAll()

        // Step 6:emit final BASAgentPersonaSpec
        return BASAgentPersonaSpec(
            personaID: personaID,
            agentID: agentSpec.agentID,
            tone: composed.tone,
            warmth: composed.warmth,
            directness: composed.directness,
            skepticism: composed.skepticism,
            structureBias: composed.structureBias,
            creativityBias: composed.creativityBias,
            challengeIntensity: composed.challengeIntensity,
            comparisonBias: composed.comparisonBias,
            guardBias: composed.guardBias,
            visibility: visibility,
            hostConstraintsRef: hostConstraintsRef,
            riskConstraintsRef: riskConstraintsRef,
            sovereignConstraintsRef:
                sovereignConstraintsRef,
            versionRef: versionRef)
    }

    // MARK: - User overlay application per tier

    private static func applyUserOverlay(
        _ composed: inout ComposedPersona,
        user: BASAgentPersonaSpec,
        visibility: BASAgentVisibility
    ) {
        switch visibility {
        case .high:
            // Full override allowed — caller can change everything
            composed.tone = user.tone
            composed.warmth = user.warmth
            composed.directness = user.directness
            composed.skepticism = user.skepticism
            composed.structureBias = user.structureBias
            composed.creativityBias = user.creativityBias
            composed.challengeIntensity =
                user.challengeIntensity
            composed.comparisonBias = user.comparisonBias
            composed.guardBias = user.guardBias

        case .medium:
            // Style + cadence ONLY — tone + warmth + directness。
            // Cognitive biases stay role-template (per Section 11.2
            // partial customization rule)。
            composed.tone = user.tone
            composed.warmth = user.warmth
            composed.directness = user.directness
            // Other 6 biases intentionally NOT applied — MED-tier
            // discipline。

        case .low:
            // Sovereign-sealed — user overlay IGNORED entirely。
            // Per Root Law 4 (单主权) + plan ch 968 Phase 4
            // discipline:LOW-tier agents always force-default。
            // The hostOverlay can still override (it goes through
            // sovereign-authorized paths) but the user-facing
            // create / update API ENFORCES no-op for .low at the
            // SDK layer in ch 969。
            break  // explicit no-op
        }
    }

    // MARK: - Host overlay application per tier

    private static func applyHostOverlay(
        _ composed: inout ComposedPersona,
        host: BASAgentPersonaSpec,
        visibility: BASAgentVisibility
    ) {
        // Host has stronger authority than user — host can override
        // ALL fields for ALL tiers。 Per Root Law 1 (单宿主):the
        // host constitution is the sole source of truth for what
        // the host wants to enforce。
        //
        // For LOW tier:host overlay STILL applies — but only because
        // the host went through sovereign-authorized paths to set
        // it。 The ch 968 Sovereign-clamp step will additionally
        // pin LOW-tier fields back to template defaults UNLESS the
        // sovereign warrant explicitly grants the override。 So at
        // this layer the host-overlay-on-LOW just sets the field,
        // and the next clamp step decides whether it survives。
        composed.tone = host.tone
        composed.warmth = host.warmth
        composed.directness = host.directness
        composed.skepticism = host.skepticism
        composed.structureBias = host.structureBias
        composed.creativityBias = host.creativityBias
        composed.challengeIntensity = host.challengeIntensity
        composed.comparisonBias = host.comparisonBias
        composed.guardBias = host.guardBias
        _ = visibility  // unused at this layer — clamping ch 968
    }

    // MARK: - Composition workspace

    /// Internal mutable workspace for the resolve step。 NOT exposed
    /// publicly — the only public output is `BASAgentPersonaSpec`。
    private struct ComposedPersona {
        var tone: String
        var warmth: Double
        var directness: Double
        var skepticism: Double
        var structureBias: Double
        var creativityBias: Double
        var challengeIntensity: Double
        var comparisonBias: Double
        var guardBias: Double

        init(template: BASAgentPersonaRoleTemplate) {
            self.tone = template.tone
            self.warmth = template.warmth
            self.directness = template.directness
            self.skepticism = template.skepticism
            self.structureBias = template.structureBias
            self.creativityBias = template.creativityBias
            self.challengeIntensity =
                template.challengeIntensity
            self.comparisonBias = template.comparisonBias
            self.guardBias = template.guardBias
        }

        mutating func clampAll() {
            warmth = clamp01(warmth)
            directness = clamp01(directness)
            skepticism = clamp01(skepticism)
            structureBias = clamp01(structureBias)
            creativityBias = clamp01(creativityBias)
            challengeIntensity = clamp01(challengeIntensity)
            comparisonBias = clamp01(comparisonBias)
            guardBias = clamp01(guardBias)
        }

        private func clamp01(_ v: Double) -> Double {
            // Per ch 956.11 CR1:saturate at bound rather than
            // fail — failing closed breaks the live session for
            // an out-of-bounds persona overlay。 NaN policy:NaN
            // → 0.5 (neutral middle) since clamp(NaN) returns
            // NaN in Swift's max/min by default
            if v.isNaN { return 0.5 }
            return max(0.0, min(1.0, v))
        }
    }
}
