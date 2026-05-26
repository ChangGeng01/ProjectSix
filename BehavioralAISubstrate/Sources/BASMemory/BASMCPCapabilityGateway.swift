// MARK: - BASMCPCapabilityGateway
// chapter 九百七十六 / M3585 — Phase 7 ch1:MCP adapter
//
// User design Section 3 + plan PHASE 7 ch1:Model Context
// Protocol (MCP) is the standard for external tool / data /
// prompt / resource adapters。 The Capability Gateway is the
// substrate's single point of entry for MCP-returned outputs。
//
// CRITICAL invariant per plan + ch 944 H2:
//
//   MCP server outputs MUST pass through provenance seal +
//   risk scan + prompt-injection scan BEFORE becoming legal
//   state objects。
//
//   Never let MCP-returned content directly write into shared
//   state graph。
//
// ## Pipeline
//
//   MCPInvocation
//      ↓
//   [Step 1] Envelope validation — non-empty server/tool/
//            invocation IDs
//      ↓
//   [Step 2] Tool-domain scope check — server MUST be in
//            caller's allowedToolDomains + permitID non-empty
//      ↓
//   [Step 3] Tool-injection scan — reuse ch 971
//            BASToolInjectionWatcher pattern set
//      ↓
//   [Step 4] Trust-threshold check — reject below 0.25
//      ↓
//   [Step 5] Provenance seal — tag every accepted output with
//            origin MCP server / tool / invocation / permit IDs
//            + trust score + audit notes
//      ↓
//   [Step 6] Sanitization — strip injection markers from low-
//            trust outputs (trust < 0.5 → sanitize;trust ≥ 0.5
//            → pass-through)
//
// chapter 九百八十一.5 USER-PASS-7 DH6 doc-fix:step labels
// normalized to monotonic 1-6 sequence。 Previously the header
// used 1-4 but the implementation comments labeled them
// 0/4/2/2.5/1/3 which contradicted the CHANGELOG and confused
// trace replay attribution。
//      ↓
//   Accepted output → caller can proceed
//   Rejected → return rejection reason + audit trail
//
// ## Pure-fn discipline
//
// Same as ch 957-975 — pure functions,no actor,no I/O。
// Caller invokes synchronously。 MCP transport (the actual
// network call to the MCP server) is OUTSIDE this gateway's
// scope — caller does that,then submits the result through
// the gateway for sealing + scanning。
//
// ## What this gateway is NOT
//
// - NOT the MCP TRANSPORT (caller handles network)
// - NOT the MCP SERVER (caller manages server lifecycle)
// - NOT the state-graph writer (caller's skill agent does
//   that AFTER gateway acceptance,via the normal Phase 1-5
//   pipeline)
//
// The gateway is a PURE-FN VALIDATOR + SEAL APPLICATOR。

import Foundation

// MARK: - MCP invocation envelope

/// Caller-supplied bundle for an MCP tool invocation。 Caller
/// (typically a `BASSkillAgent`'s tool harness) constructs this
/// AFTER making the MCP call and BEFORE handing the output to
/// the substrate state-graph pipeline。
public struct BASMCPInvocation:
    Sendable, Equatable, Hashable, Codable
{
    /// MCP server identifier (e.g. "mcp.filesystem" / "mcp.calendar")。
    /// Caller's responsibility to use a stable ID per server。
    public let mcpServerID: String
    /// Tool ID within that server (e.g. "read-file" /
    /// "list-events")。
    public let toolID: String
    /// Unique invocation ID per call。 Used for trace replay。
    public let invocationID: String
    /// The MCP server's raw output。 Treated as untrusted input
    /// until the gateway runs all 4 pipeline steps。
    public let rawOutput: String
    /// Caller's BASActionPermit identifier (tool-domain scope)。
    /// Empty = no permit declared (will be rejected by Step 2)。
    public let permitID: String
    /// Calling skill-agent's allowedToolDomains (from
    /// `BASSkillAgentDescriptor`)。 If mcpServerID not in this
    /// list,gateway rejects。
    public let allowedToolDomains: [String]
    /// Monotonic timestamp for audit trail。
    public let nowNanos: Int64

    public init(
        mcpServerID: String,
        toolID: String,
        invocationID: String,
        rawOutput: String,
        permitID: String = "",
        allowedToolDomains: [String] = [],
        nowNanos: Int64 = 0
    ) {
        self.mcpServerID = mcpServerID
        self.toolID = toolID
        self.invocationID = invocationID
        self.rawOutput = rawOutput
        self.permitID = permitID
        self.allowedToolDomains =
            allowedToolDomains.sorted()
        self.nowNanos = nowNanos
    }
}

// MARK: - Provenance seal

/// Provenance metadata attached to every accepted MCP output。
/// External consumers (downstream seats) check this seal to
/// know an output came from MCP + which server + via which
/// permit。 The seal becomes part of the state-graph object
/// payload when the caller eventually persists it。
public struct BASMCPProvenanceSeal:
    Sendable, Equatable, Hashable, Codable
{
    public let mcpServerID: String
    public let toolID: String
    public let invocationID: String
    public let permitID: String
    public let sealedAtNanos: Int64
    /// 0.0-1.0 trust score。 Gateway computes from:
    ///   - 1.0 if no injection markers found
    ///   - drops by 0.25 per category of finding
    ///   - 0.0 if any veto-level finding
    public let trustScore: Double
    /// Sorted audit notes for trace replay — what the gateway
    /// did during pipeline (sealed / scanned / etc.)
    public let auditNotes: [String]

    public init(
        mcpServerID: String,
        toolID: String,
        invocationID: String,
        permitID: String,
        sealedAtNanos: Int64,
        trustScore: Double,
        auditNotes: [String] = []
    ) {
        self.mcpServerID = mcpServerID
        self.toolID = toolID
        self.invocationID = invocationID
        self.permitID = permitID
        self.sealedAtNanos = sealedAtNanos
        self.trustScore = max(0.0, min(1.0, trustScore))
        self.auditNotes = auditNotes.sorted()
    }
}

// MARK: - Gateway result

public struct BASMCPGatewayResult:
    Sendable, Equatable, Hashable, Codable
{
    /// True if the invocation passed all 4 pipeline steps。
    public let accepted: Bool
    /// Provenance seal IF accepted。 Nil when rejected。
    public let seal: BASMCPProvenanceSeal?
    /// Sealed output payload (== rawOutput when trust ≥ 0.5,
    /// otherwise a sanitized version where injection markers
    /// are stripped)。 Nil when rejected。
    public let sealedOutput: String?
    /// Watcher hints emitted during the scan step。 Caller
    /// surfaces these to the L14 audit ledger via
    /// `BASAgentWatcherAggregator.aggregate(...)` if non-empty。
    public let watcherHints: [BASAgentWatcherHint]
    /// Rejection reason code if `accepted == false`。
    public let rejectReason: String?

    public init(
        accepted: Bool,
        seal: BASMCPProvenanceSeal? = nil,
        sealedOutput: String? = nil,
        watcherHints:
            [BASAgentWatcherHint] = [],
        rejectReason: String? = nil
    ) {
        self.accepted = accepted
        self.seal = seal
        self.sealedOutput = sealedOutput
        self.watcherHints = watcherHints
        self.rejectReason = rejectReason
    }
}

// MARK: - Gateway

public enum BASMCPCapabilityGateway {

    /// Trust threshold below which the output is REJECTED
    /// outright (vs sanitized + sealed at low trust)。 Per
    /// plan ch 944 H2 + Phase 7 sovereignty:trust < this
    /// = sovereign-significant threat,reject。
    public static let rejectTrustThreshold: Double = 0.25

    /// Run the 4-step pipeline。 Pure function。 Returns
    /// `BASMCPGatewayResult` with seal + sealed output OR
    /// rejection reason + watcher hints。
    public static func invoke(
        _ inv: BASMCPInvocation
    ) -> BASMCPGatewayResult {
        // Step 1:envelope validation
        if inv.mcpServerID.isEmpty {
            return BASMCPGatewayResult(
                accepted: false,
                rejectReason: "mcp.invalid-envelope:" +
                    "empty-server-id")
        }
        if inv.toolID.isEmpty {
            return BASMCPGatewayResult(
                accepted: false,
                rejectReason: "mcp.invalid-envelope:" +
                    "empty-tool-id")
        }
        if inv.invocationID.isEmpty {
            return BASMCPGatewayResult(
                accepted: false,
                rejectReason: "mcp.invalid-envelope:" +
                    "empty-invocation-id")
        }

        // Step 2:tool-domain scope check (caller's
        // allowedToolDomains MUST contain mcpServerID)
        if !inv.allowedToolDomains.contains(inv.mcpServerID) {
            return BASMCPGatewayResult(
                accepted: false,
                rejectReason:
                    "mcp.scope-violation:server " +
                    "'\(inv.mcpServerID)' not in caller's " +
                    "allowedToolDomains")
        }
        if inv.permitID.isEmpty {
            return BASMCPGatewayResult(
                accepted: false,
                rejectReason: "mcp.no-permit:empty-permit-id")
        }

        // Step 3:tool-injection scan via ch 971 watcher。
        // Build a synthetic observation containing the MCP
        // output as a pressure signal,then route through the
        // tool-injection watcher's pattern set。
        var seq = 0
        let obs = BASAgentWatcherObservation(
            turnID: "mcp.\(inv.invocationID)",
            scout: BASScoutInput(
                pressureSignals: [inv.rawOutput]),
            nowNanos: inv.nowNanos)
        let injHints = BASToolInjectionWatcher.observe(
            obs, seq: &seq)

        // Compute trust score: start at 1.0,subtract by
        // hint severity
        var trust = 1.0
        var auditNotes: [String] = []
        for hint in injHints {
            switch hint.severity {
            case .info:
                trust -= 0.05
            case .watch:
                trust -= 0.15
            case .alert:
                trust -= 0.50
            case .veto:
                trust -= 1.0
            }
            auditNotes.append(
                "mcp.scan.\(hint.severity.rawValue):" +
                "\(hint.category)")
        }
        trust = max(0.0, trust)

        // Step 4:trust-threshold check — reject if below 0.25
        if trust < rejectTrustThreshold {
            return BASMCPGatewayResult(
                accepted: false,
                watcherHints: injHints,
                rejectReason:
                    "mcp.injection-detected:trust=" +
                    String(format: "%.3f", trust))
        }

        // Step 5:provenance seal
        let seal = BASMCPProvenanceSeal(
            mcpServerID: inv.mcpServerID,
            toolID: inv.toolID,
            invocationID: inv.invocationID,
            permitID: inv.permitID,
            sealedAtNanos: inv.nowNanos,
            trustScore: trust,
            auditNotes: auditNotes +
                ["mcp.sealed=\(inv.mcpServerID)"])

        // Step 6:sanitize if trust low-but-acceptable (between
        // rejectTrustThreshold and 0.5),sanitize output by
        // stripping markers。 At trust ≥ 0.5,pass-through。
        let sealedOutput: String
        if trust < 0.5 {
            sealedOutput = sanitize(
                inv.rawOutput,
                markers:
                    BASToolInjectionWatcher
                        .injectionMarkers)
        } else {
            sealedOutput = inv.rawOutput
        }

        return BASMCPGatewayResult(
            accepted: true,
            seal: seal,
            sealedOutput: sealedOutput,
            watcherHints: injHints,
            rejectReason: nil)
    }

    /// Strip known injection markers from output。 Markers
    /// are replaced with `[REDACTED-MARKER]` so trace replay
    /// can see what was stripped。
    public static func sanitize(
        _ output: String,
        markers: [String]
    ) -> String {
        var result = output
        for marker in markers {
            // Case-insensitive replace via range lookup
            while let range = result.range(
                of: marker,
                options: .caseInsensitive)
            {
                result.replaceSubrange(
                    range,
                    with: "[REDACTED-MARKER]")
            }
        }
        return result
    }
}
