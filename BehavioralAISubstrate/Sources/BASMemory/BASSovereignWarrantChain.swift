// MARK: - BASSovereignWarrantChain
// chapter 九百八十一.7 / M3610.7 — ARC FINALIZE deferred item #5
//
// Per `Docs/ARC_SEAL_953_981.md` deferred item #5:Sovereign
// warrant infrastructure for `.collaborator` external tier。
// Ch 977 currently auto-downgrades declared `.collaborator`
// external agents → `.advisor` because there was no warrant
// chain to authorize the upgrade。 This module ships the
// missing chain。
//
// ## Sovereignty discipline (CRITICAL)
//
// Per Root Law 4 (单主权) + ch 977 HIGH-risk discipline:
//   - External agents are NEVER trusted by default
//   - The substrate's defense is to DEGRADE every external
//     agent to proposal-only with all 12 state-graph domains
//     forbidden
//   - The `.collaborator` tier (proposals + memory anchor
//     channel) is sovereign-significant — granting it implies
//     the host trusts this external party with memory-bundle-
//     adjacent influence
//
// To upgrade to `.collaborator`,the host MUST issue a chain
// of warrants signed by:
//   1. The host constitution (root warrant — "this host
//      authorizes collaborator tier for some external agents")
//   2. The specific external agent ID (per-agent warrant)
//   3. An expiration timestamp (no perpetual warrants)
//
// Without ALL THREE,the external agent stays at `.advisor`。
//
// ## Pure-fn discipline
//
// Same as ch 977 — pure functions,no actor,no I/O。 The
// host's signing infrastructure (cryptographic signature
// over the warrant payload) is OUT OF SCOPE here。 This
// module just validates STRUCTURE — the host's signature
// verification (matching warrant against the host
// constitution's signing key) happens at the host layer
// before submitting to this gateway。
//
// Per ch 944 H2 + ch 977 defense-in-depth:structural
// validation is the substrate's responsibility;cryptographic
// validation is the host's responsibility。 The two layers
// compose defense-in-depth。

import Foundation

// MARK: - Warrant chain

/// A 3-stage warrant chain authorizing collaborator tier
/// upgrade for a specific external agent。 Per discipline
/// above,all 3 stages MUST be present + valid for the
/// gateway to honor the declared `.collaborator` tier。
public struct BASSovereignWarrantChain:
    Sendable, Equatable, Hashable, Codable
{
    /// Root warrant — host constitution authorizes
    /// collaborator tier for SOME external agents in this
    /// session。 Format suggestion:
    /// `host-warrant:<hostID>:<sessionID>:<expires-at>`
    public let hostRootWarrantID: String
    /// Per-agent warrant — host explicitly authorizes THIS
    /// external agent (by externalAgentID) for collaborator
    /// tier。 Format:`per-agent:<externalAgentID>:<scope>`
    public let perAgentWarrantID: String
    /// Expiration timestamp in nanos。 Gateway rejects
    /// warrants expired against the current turn's nowNanos。
    public let expiresAtNanos: Int64
    /// External agent this chain authorizes (must match the
    /// external ref's `externalAgentID` at gateway time)。
    public let externalAgentID: String
    /// Reason for the upgrade — caller-supplied,used in the
    /// audit ledger via reserved prefix
    /// `agentExternal.warrant:`。
    public let reason: String

    public init(
        hostRootWarrantID: String,
        perAgentWarrantID: String,
        expiresAtNanos: Int64,
        externalAgentID: String,
        reason: String = ""
    ) {
        self.hostRootWarrantID = hostRootWarrantID
        self.perAgentWarrantID = perAgentWarrantID
        self.expiresAtNanos = max(0, expiresAtNanos)
        self.externalAgentID = externalAgentID
        self.reason = reason
    }
}

// MARK: - Warrant validation

public struct BASWarrantValidationResult:
    Sendable, Equatable, Hashable, Codable
{
    public let valid: Bool
    /// Sorted audit notes for L14 ledger via reserved prefix
    /// `agentExternal.warrant:`。 Examples:
    ///   agentExternal.warrant:granted:<chainID>
    ///   agentExternal.warrant:rejected:expired
    ///   agentExternal.warrant:rejected:identity-mismatch
    public let auditRefs: [String]

    public init(
        valid: Bool,
        auditRefs: [String] = []
    ) {
        self.valid = valid
        self.auditRefs = auditRefs.sorted()
    }
}

// MARK: - Warrant chain validator

public enum BASSovereignWarrantValidator {

    /// Validate a warrant chain for a specific external agent
    /// at a specific turn time。 Pure function。
    ///
    /// Rules (all 5 must pass for valid==true):
    ///   1. `hostRootWarrantID` non-empty
    ///   2. `perAgentWarrantID` non-empty
    ///   3. `externalAgentID` matches the supplied ref's ID
    ///      (identity match)
    ///   4. `expiresAtNanos` > 0 (not corrupted — ch 981.8
    ///      MED-corruption fix)
    ///   5. `expiresAtNanos` > `nowNanos` (not expired) — only
    ///      checked when `nowNanos > 0`
    ///
    /// chapter 九百八十一.8 USER-PASS-9 HIGH-4 + DH1 fix:
    /// audit ref format normalized to `<status>:<detail>`。
    /// Previously emitted TWO refs on grant (`granted:<id>`
    /// + `per-agent:<id>`),the second breaking the documented
    /// format (per-agent is a stage marker,not a status)。
    /// Now emits a SINGLE granted ref with combined detail:
    /// `agentExternal.warrant:granted:host-root=<id>:per-agent=<id>`。
    ///
    /// chapter 九百八十一.8 USER-PASS-9 MED-corruption fix:
    /// added Rule 4 explicit check that `expiresAtNanos > 0`
    /// — defends against corrupted snapshots that bypass
    /// expiration check when `nowNanos == 0` (caller skips
    /// age check)。
    public static func validate(
        chain: BASSovereignWarrantChain,
        forExternalAgentID externalID: String,
        nowNanos: Int64
    ) -> BASWarrantValidationResult {
        var refs: [String] = []

        // Rule 1: host root non-empty
        if chain.hostRootWarrantID.isEmpty {
            refs.append(
                "agentExternal.warrant:rejected:" +
                "empty-host-root")
            return BASWarrantValidationResult(
                valid: false, auditRefs: refs)
        }

        // Rule 2: per-agent non-empty
        if chain.perAgentWarrantID.isEmpty {
            refs.append(
                "agentExternal.warrant:rejected:" +
                "empty-per-agent")
            return BASWarrantValidationResult(
                valid: false, auditRefs: refs)
        }

        // Rule 3 (ch 981.9 USER-PASS-10 MED2-fix:moved
        // BEFORE identity check):corruption detection。
        // expiresAtNanos == 0 is either uninitialized or
        // zeroed,both indicate corruption。 Per defense-in-
        // depth discipline,corruption is more fundamental
        // than an identity mismatch — a corrupted warrant
        // alongside an identity mismatch should surface the
        // corruption signal (most-fundamental defect first)
        // rather than mask it behind identity-mismatch。
        if chain.expiresAtNanos == 0 {
            refs.append(
                "agentExternal.warrant:rejected:" +
                "corrupted-expires-at-zero")
            return BASWarrantValidationResult(
                valid: false, auditRefs: refs)
        }

        // Rule 4: identity match (chain's externalAgentID
        // must equal the supplied ref's ID — defends against
        // an attacker submitting a valid warrant for agent A
        // alongside a proposal from agent B)
        if chain.externalAgentID != externalID {
            refs.append(
                "agentExternal.warrant:rejected:" +
                "identity-mismatch")
            return BASWarrantValidationResult(
                valid: false, auditRefs: refs)
        }

        // Rule 5: not expired
        if nowNanos > 0 &&
           chain.expiresAtNanos <= nowNanos
        {
            refs.append(
                "agentExternal.warrant:rejected:" +
                "expired:expires-at=" +
                "\(chain.expiresAtNanos):now=\(nowNanos)")
            return BASWarrantValidationResult(
                valid: false, auditRefs: refs)
        }

        // Granted — emit SINGLE audit ref matching the
        // documented <status>:<detail> format。
        //
        // chapter 九百八十一.9 USER-PASS-10 C1 fix:warrant
        // IDs are caller-supplied opaque strings that CAN
        // contain `:` (e.g. `host-warrant:hostA:sess1:expires`
        // per the documented format on lines 60-65)。
        // Round 6's "single-ref" fix used `=` + `:` as field
        // separators which were AMBIGUOUS — a parser could
        // not unambiguously locate the per-agent boundary
        // when warrant IDs contained colons。 Round 7 caught
        // that the fix reintroduced the very class of
        // ambiguity it claimed to fix。
        //
        // Final fix:use U+001F unit-separator (control
        // character that no caller can produce in a warrant
        // ID per the format spec) as the field separator。
        // Matches the ch 964.5 sentinel TURN-LOCKDOWN
        // discipline that solved an identical class of issue。
        // L14 parser splits the ref on `\u{001F}` to recover
        // the host-root and per-agent values verbatim,no
        // ambiguity regardless of `:` content in IDs。
        let unitSep = "\u{001F}"
        refs.append(
            "agentExternal.warrant:granted:" +
            "host-root=\(chain.hostRootWarrantID)" +
            "\(unitSep)" +
            "per-agent=\(chain.perAgentWarrantID)")
        return BASWarrantValidationResult(
            valid: true, auditRefs: refs)
    }
}

// MARK: - Gateway extension

public extension BASExternalAgentGateway {

    /// Effective tier with warrant chain support。 Mirrors the
    /// existing `effectiveTier(for:)` but allows the host's
    /// validated warrant chain to HONOR a declared
    /// `.collaborator` tier。 Without a valid chain,falls
    /// back to the original (non-optional) downgrade rules。
    ///
    /// Per ch 981.7 ARC FINALIZE deferred item #5:this closes
    /// the gap noted in ch 977 between "external agent
    /// declared collaborator" and "host actually warranted
    /// collaborator"。
    ///
    /// - Parameters:
    ///   - ref: external agent ref
    ///   - warrantChain: optional sovereign warrant chain
    ///     (nil = use existing non-optional downgrade)
    ///   - nowNanos: monotonic timestamp for expiration check
    /// - Returns: (effective tier, validation result with
    ///   audit refs for the L14 ledger)
    static func effectiveTierWithWarrant(
        for ref: BASExternalAgentRef,
        warrantChain: BASSovereignWarrantChain?,
        nowNanos: Int64
    ) -> (BASExternalSandboxTier,
          BASWarrantValidationResult) {
        // Step 1:start with the existing downgrade rules
        let baseTier = effectiveTier(for: ref)

        // Step 2:if no warrant or declared tier is not
        // .collaborator,just use base tier。
        //
        // chapter 九百八十一.8 USER-PASS-9 HIGH-3 fix:audit
        // ref now distinguishes between "no warrant supplied"
        // and "warrant supplied but tier is not collaborator
        // so no warrant needed"。 Previously both paths emitted
        // `none-supplied` which lied to the L14 ledger when a
        // warrant WAS supplied alongside a non-collaborator
        // tier。
        if warrantChain == nil {
            return (baseTier,
                BASWarrantValidationResult(
                    valid: false,
                    auditRefs: [
                        "agentExternal.warrant:none-supplied",
                    ]))
        }
        if ref.sandboxTier != .collaborator {
            return (baseTier,
                BASWarrantValidationResult(
                    valid: false,
                    auditRefs: [
                        "agentExternal.warrant:" +
                        "not-applicable:tier=" +
                        "\(ref.sandboxTier.rawValue)",
                    ]))
        }
        let chain = warrantChain!

        // Step 3:validate the warrant chain
        let result =
            BASSovereignWarrantValidator.validate(
                chain: chain,
                forExternalAgentID: ref.externalAgentID,
                nowNanos: nowNanos)

        if result.valid {
            // Warrant honored → upgrade to .collaborator
            return (.collaborator, result)
        } else {
            // Warrant invalid → stay at base tier (.advisor
            // per the unattested + collaborator-claim
            // downgrade rules)
            return (baseTier, result)
        }
    }
}
