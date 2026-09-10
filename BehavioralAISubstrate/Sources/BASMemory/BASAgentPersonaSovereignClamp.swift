// MARK: - BASAgentPersonaSovereignClamp
// chapter 九百六十八 / M3545 — Phase 4 ch3:Sovereign sentinel clamping
//
// User design Section 11.4 + plan PHASE 4 ch3 + Phase 4 formula:
//
//   P_effective = Clamp(P_role ⊕ P_user ⊕ P_host, Risk, Sovereign)
//                                                        ^^^^^^^^^
//                                                        this ch
//
// Ch 966 shipped composition,ch 967 added Risk clamp,ch 968 adds
// the SOVEREIGN clamp — the rightmost + final arm。 After this,
// Phase 4 ch 969 ships the SDK surface that calls the full chain。
//
// ## What sovereign clamps
//
// Per plan PHASE 4 ch3 + Section 11.2 visibility tier rules:
//
//   - LOW-tier agents (SovereignSentinel / ActionPermit /
//     DeleteRollbackSeal / MemorySeal) — sovereign-sealed defaults
//     ALWAYS force back to the role template,UNLESS the host
//     supplies an explicit sovereign warrant token AND the
//     warrant grants the specific field override。
//
//   - Critical-state turns (heightened protection / boundary
//     touch in extreme severity / sovereign-locked axis touch)
//     — force ALL agents back to defensive defaults regardless
//     of tier (skepticism + guard at template floor or higher;
//     creativity + challenge capped at conservative ceilings)。
//
//   - HIGH-tier + MED-tier agents on non-critical turns:no
//     change (Risk arm already did its work in ch 967)。
//
// ## Sovereign warrant
//
// The plan says "host overlay STILL applies — but only because
// the host went through sovereign-authorized paths to set it"。
// Ch 966 currently allows ALL host overlays on LOW tier (deferred
// to ch 968 per plan)。 Ch 968 adds the warrant check:
//
//   - Without warrant:LOW-tier persona FORCE-DEFAULTS to template
//     regardless of any host overlay
//   - With warrant + matching field grant:host overlay survives
//     for that specific field only
//   - Warrant is INERT for HIGH/MED tier — those tiers don't
//     need it
//
// The warrant token format mirrors the L14 `BASSovereignWarrant`
// pattern (warrant_id + granted_fields + expires_at)。 Slim DTO
// here keeps BASMemory decoupled from BASSovereign。
//
// ## Pure-fn discipline + ordering
//
// Same as ch 957-967 — pure function。 Sovereign clamp runs AFTER
// Risk clamp per Phase 4 formula。 Caller (ch 969 SDK surface)
// chains:
//
//   resolved = BASAgentPersonaResolver.resolve(...)
//   (risked, _)   = BASAgentPersonaRiskClamp.apply(resolved, risk)
//   (sovereign,_) = BASAgentPersonaSovereignClamp.apply(
//                       risked, sovereignContext, template)
//
// Sovereign LAST per Root Law 4 (单主权) — sovereign always
// wins,never overruled。

import Foundation

// MARK: - Sovereign warrant

/// Slim warrant DTO。 Caller (host) supplies this when they want
/// to override LOW-tier persona fields。 Without a warrant the
/// LOW-tier fields force-default。 Empty warrant (no grants) =
/// same as no warrant — useful for callers who want to pass an
/// audit-marker warrant without granting any specific overrides。
public struct BASAgentPersonaSovereignWarrant:
    Sendable, Equatable, Hashable, Codable
{
    public let warrantID: String
    /// Field names the warrant grants override for (matches the
    /// `BASAgentPersonaSpec` field names exactly)。 Empty list =
    /// warrant-but-no-grants (still valid;just doesn't grant
    /// any overrides)。 Sorted by caller for deterministic
    /// fingerprint。
    public let grantedFields: [String]
    /// Reason the host invoked sovereign override (audit trail —
    /// e.g. "user-requested clinical persona for ward setting"
    /// + "operator: dr-smith")。
    public let reason: String

    public init(
        warrantID: String,
        grantedFields: [String] = [],
        reason: String = ""
    ) {
        self.warrantID = warrantID
        self.grantedFields = grantedFields.sorted()
        self.reason = reason
    }

    /// True if the warrant grants override for this field name。
    public func grants(_ field: String) -> Bool {
        grantedFields.contains(field)
    }
}

// MARK: - Sovereign context

/// Slim DTO carrying the sovereign turn state the persona clamp
/// needs。 Built by the coordinator adapter from L14
/// `BASSovereignVerdictEngine` state + ch 964 SovereignSentinel
/// emissions。
public struct BASAgentPersonaSovereignContext:
    Sendable, Equatable, Hashable, Codable
{
    /// True if THIS turn touched a sovereign-locked axis (the
    /// ch 964 sentinel emitted a lockdown verdict)。 If true,
    /// ALL agents force-default regardless of tier。
    public let lockdownTurn: Bool

    /// True if the host's heightened-protection mode is active
    /// (vulnerable / emergency / critical state per host
    /// constitution)。 If true,creativity + challenge are
    /// capped at conservative ceilings for ALL tiers。
    public let heightenedProtection: Bool

    /// Per-turn sovereign warrant from the host。 Nil = no
    /// warrant (LOW-tier overlay force-defaults)。
    public let warrant: BASAgentPersonaSovereignWarrant?

    /// Audit-only:source of this sovereign context for trace
    /// replay。 Format suggestion:
    /// `sovereignVerdict:<sessionID>:<turnID>`。
    public let sourceRef: String

    public init(
        lockdownTurn: Bool = false,
        heightenedProtection: Bool = false,
        warrant:
            BASAgentPersonaSovereignWarrant? = nil,
        sourceRef: String = ""
    ) {
        self.lockdownTurn = lockdownTurn
        self.heightenedProtection = heightenedProtection
        self.warrant = warrant
        self.sourceRef = sourceRef
    }

    /// Identity / "no-op" sovereign context — nothing triggered,
    /// no warrant。 Common case for routine turns。
    public static let identity =
        BASAgentPersonaSovereignContext()
}

// MARK: - Outcome

public struct BASAgentPersonaSovereignClampOutcome:
    Sendable, Equatable, Hashable, Codable
{
    public let didClamp: Bool
    /// Sorted audit notes for trace replay determinism。
    public let auditNotes: [String]
    /// True if the turn was lockdown — caller (SDK / surface)
    /// can use this to gate further actions (e.g. don't render
    /// at all,or show "sealed" indicator)。
    public let lockdownApplied: Bool

    public init(
        didClamp: Bool,
        auditNotes: [String] = [],
        lockdownApplied: Bool = false
    ) {
        self.didClamp = didClamp
        self.auditNotes = auditNotes
        self.lockdownApplied = lockdownApplied
    }

    public static let none =
        BASAgentPersonaSovereignClampOutcome(
            didClamp: false, lockdownApplied: false)
}

// MARK: - Sovereign clamp

public enum BASAgentPersonaSovereignClamp {

    /// Apply the Sovereign clamp arm of the Phase 4 formula。
    /// Pure function — returns clamped persona + audit outcome。
    ///
    /// - Parameters:
    ///   - persona: result of ch 966 resolver + ch 967 Risk clamp
    ///   - sovereign: sovereign turn context (use `.identity`
    ///     for routine turns)
    ///   - role: agent role,used to look up the LOW-tier
    ///     template for force-default
    /// - Returns: (clamped persona, audit outcome)
    public static func apply(
        to persona: BASAgentPersonaSpec,
        sovereign: BASAgentPersonaSovereignContext,
        role: BASAgentRole
    ) -> (BASAgentPersonaSpec,
          BASAgentPersonaSovereignClampOutcome) {
        // Fast path:identity context + non-LOW tier = no-op
        if sovereign == .identity &&
           persona.visibility != .low {
            return (persona, .none)
        }

        let template =
            BASAgentPersonaRoleTemplates.template(for: role)
        var notes: [String] = []
        var tone = persona.tone
        var warmth = persona.warmth
        var directness = persona.directness
        var skepticism = persona.skepticism
        var structureBias = persona.structureBias
        var creativityBias = persona.creativityBias
        var challengeIntensity = persona.challengeIntensity
        var comparisonBias = persona.comparisonBias
        var guardBias = persona.guardBias

        // Rule 1:LOCKDOWN — every agent regardless of tier
        // force-defaults to template (no agent can deviate when
        // sovereign verdict says lockdown)
        //
        // chapter 九百六十九.5 USER-PASS-6 H3 fix:emit per-field
        // notes for any value that actually CHANGED during the
        // lockdown force-default,plus the lockdown-scope marker。
        // Previously only the scope marker was emitted,so the
        // audit ledger couldn't tell which fields the host's
        // overlay had set vs which were already at template。
        if sovereign.lockdownTurn {
            if tone != template.tone {
                notes.append(formatForce(
                    field: "tone", to: template.tone))
            }
            (warmth, _) = lockdownForceNumeric(
                value: warmth,
                template: template.warmth,
                field: "warmth", notes: &notes)
            (directness, _) = lockdownForceNumeric(
                value: directness,
                template: template.directness,
                field: "directness", notes: &notes)
            (skepticism, _) = lockdownForceNumeric(
                value: skepticism,
                template: template.skepticism,
                field: "skepticism", notes: &notes)
            (structureBias, _) = lockdownForceNumeric(
                value: structureBias,
                template: template.structureBias,
                field: "structureBias", notes: &notes)
            (creativityBias, _) = lockdownForceNumeric(
                value: creativityBias,
                template: template.creativityBias,
                field: "creativityBias", notes: &notes)
            (challengeIntensity, _) = lockdownForceNumeric(
                value: challengeIntensity,
                template: template.challengeIntensity,
                field: "challengeIntensity", notes: &notes)
            (comparisonBias, _) = lockdownForceNumeric(
                value: comparisonBias,
                template: template.comparisonBias,
                field: "comparisonBias", notes: &notes)
            (guardBias, _) = lockdownForceNumeric(
                value: guardBias,
                template: template.guardBias,
                field: "guardBias", notes: &notes)
            tone = template.tone
            warmth = template.warmth
            directness = template.directness
            skepticism = template.skepticism
            structureBias = template.structureBias
            creativityBias = template.creativityBias
            challengeIntensity = template.challengeIntensity
            comparisonBias = template.comparisonBias
            guardBias = template.guardBias
            notes.append(
                "sovereign.lockdown:force-default-all")
        }

        // Rule 2:LOW tier WITHOUT warrant — force-default。
        // (LOW with warrant:caller's host overlay already
        // applied at ch 966 resolver;warrant decides whether
        // it SURVIVES here。 We use field-by-field grant.)
        //
        // chapter 九百六十九.5 USER-PASS-6 C1 fix:audit note
        // now emitted UNCONDITIONALLY for every LOW-tier field
        // that was RE-CHECKED (regardless of whether value
        // already matched template)。 Previously the audit
        // ledger had no record of which fields the sovereign
        // gate considered — a trace replay couldn't distinguish
        // "field happened to equal template" from "sovereign
        // chose to skip the field" — INV8 violation。 Now the
        // notes prefix `sovereign.check.<field>:<status>` for
        // every field iteration,with `<status>` = `forced`
        // (value changed) / `unchanged-but-checked` (value
        // already matched) / `granted` (warrant overrode)。
        if !sovereign.lockdownTurn &&
           persona.visibility == .low {
            let warrant = sovereign.warrant
            (tone, _) = forceFieldString(
                value: tone,
                template: template.tone,
                field: "tone",
                warrant: warrant,
                notes: &notes)
            (warmth, _) = forceFieldNumeric(
                value: warmth,
                template: template.warmth,
                field: "warmth",
                warrant: warrant,
                notes: &notes)
            (directness, _) = forceFieldNumeric(
                value: directness,
                template: template.directness,
                field: "directness",
                warrant: warrant,
                notes: &notes)
            (skepticism, _) = forceFieldNumeric(
                value: skepticism,
                template: template.skepticism,
                field: "skepticism",
                warrant: warrant,
                notes: &notes)
            (structureBias, _) = forceFieldNumeric(
                value: structureBias,
                template: template.structureBias,
                field: "structureBias",
                warrant: warrant,
                notes: &notes)
            (creativityBias, _) = forceFieldNumeric(
                value: creativityBias,
                template: template.creativityBias,
                field: "creativityBias",
                warrant: warrant,
                notes: &notes)
            (challengeIntensity, _) = forceFieldNumeric(
                value: challengeIntensity,
                template: template.challengeIntensity,
                field: "challengeIntensity",
                warrant: warrant,
                notes: &notes)
            (comparisonBias, _) = forceFieldNumeric(
                value: comparisonBias,
                template: template.comparisonBias,
                field: "comparisonBias",
                warrant: warrant,
                notes: &notes)
            (guardBias, _) = forceFieldNumeric(
                value: guardBias,
                template: template.guardBias,
                field: "guardBias",
                warrant: warrant,
                notes: &notes)
            if let w = warrant {
                notes.append(
                    "sovereign.warrant:\(w.warrantID)")
            } else {
                notes.append(
                    "sovereign.no-warrant:low-tier-force-default")
            }
        }

        // Rule 3:HEIGHTENED PROTECTION — cap creativity + challenge
        // for ALL tiers regardless of warrant
        if !sovereign.lockdownTurn &&
           sovereign.heightenedProtection {
            let creativityCeiling = 0.30
            let challengeCeiling = 0.30
            if creativityBias > creativityCeiling {
                notes.append(formatCap(
                    field: "creativity",
                    from: creativityBias,
                    to: creativityCeiling,
                    reason: "heightened-protection"))
                creativityBias = creativityCeiling
            }
            if challengeIntensity > challengeCeiling {
                notes.append(formatCap(
                    field: "challenge",
                    from: challengeIntensity,
                    to: challengeCeiling,
                    reason: "heightened-protection"))
                challengeIntensity = challengeCeiling
            }
        }

        let didClamp = !notes.isEmpty
        let clamped = BASAgentPersonaSpec(
            personaID: persona.personaID,
            agentID: persona.agentID,
            tone: tone,
            warmth: clamp01(warmth),
            directness: clamp01(directness),
            skepticism: clamp01(skepticism),
            structureBias: clamp01(structureBias),
            creativityBias: clamp01(creativityBias),
            challengeIntensity: clamp01(challengeIntensity),
            comparisonBias: clamp01(comparisonBias),
            guardBias: clamp01(guardBias),
            visibility: persona.visibility,
            hostConstraintsRef: persona.hostConstraintsRef,
            riskConstraintsRef: persona.riskConstraintsRef,
            sovereignConstraintsRef:
                persona.sovereignConstraintsRef,
            versionRef: persona.versionRef)

        return (clamped,
                BASAgentPersonaSovereignClampOutcome(
                    didClamp: didClamp,
                    auditNotes: notes.sorted(),
                    lockdownApplied:
                        sovereign.lockdownTurn))
    }

    // MARK: - Helpers

    private static func formatForce(
        field: String, to value: String
    ) -> String {
        "sovereign.force.\(field):template-default(\(value))"
    }

    private static func formatForceNumeric(
        field: String, to value: Double
    ) -> String {
        let v = String(format: "%.3f", value)
        return "sovereign.force.\(field):template-default(\(v))"
    }

    private static func formatCap(
        field: String, from old: Double,
        to new: Double, reason: String
    ) -> String {
        let oldStr = String(format: "%.3f", old)
        let newStr = String(format: "%.3f", new)
        return
            "sovereign.cap.\(field):\(oldStr)→\(newStr)" +
            "(\(reason))"
    }

    private static func clamp01(_ v: Double) -> Double {
        if v.isNaN { return 0.5 }
        return max(0.0, min(1.0, v))
    }

    // MARK: - LOW-tier force-default helpers (ch 969.5 C1 fix)

    /// String-field force-default helper for LOW-tier per ch
    /// 969.5 USER-PASS-6 C1 fix。 Emits audit note unconditionally
    /// for every field that was re-checked,with status `forced`
    /// / `unchanged-but-checked` / `granted`。 Returns the
    /// possibly-replaced value + whether it changed。
    private static func forceFieldString(
        value: String, template: String,
        field: String,
        warrant: BASAgentPersonaSovereignWarrant?,
        notes: inout [String]
    ) -> (String, Bool) {
        if warrant?.grants(field) == true {
            notes.append(
                "sovereign.check.\(field):granted")
            return (value, false)
        }
        if value != template {
            notes.append(formatForce(
                field: field, to: template))
            return (template, true)
        }
        notes.append(
            "sovereign.check.\(field):unchanged-but-checked")
        return (value, false)
    }

    /// Numeric-field force-default helper for LOW-tier per ch
    /// 969.5 C1 fix。
    private static func forceFieldNumeric(
        value: Double, template: Double,
        field: String,
        warrant: BASAgentPersonaSovereignWarrant?,
        notes: inout [String]
    ) -> (Double, Bool) {
        if warrant?.grants(field) == true {
            notes.append(
                "sovereign.check.\(field):granted")
            return (value, false)
        }
        if value != template {
            notes.append(formatForceNumeric(
                field: field, to: template))
            return (template, true)
        }
        notes.append(
            "sovereign.check.\(field):unchanged-but-checked")
        return (value, false)
    }

    /// Lockdown numeric-field force helper for ch 969.5 H3 fix。
    /// Lockdown ALWAYS forces (no warrant respect),so this is
    /// simpler than the LOW-tier per-field helper。 Audit note
    /// is emitted only when the value actually changed (lockdown
    /// audits are per-field-changed,not per-field-checked since
    /// the scope marker already says "all" in the same outcome)。
    private static func lockdownForceNumeric(
        value: Double, template: Double, field: String,
        notes: inout [String]
    ) -> (Double, Bool) {
        if value != template {
            notes.append(formatForceNumeric(
                field: field, to: template))
            return (template, true)
        }
        return (value, false)
    }
}
