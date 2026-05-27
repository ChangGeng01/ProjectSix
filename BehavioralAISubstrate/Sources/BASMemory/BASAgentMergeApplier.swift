// MARK: - BASAgentMergeApplier
// chapter 九百五十六.5 / M3485.5 USER-PASS gap #2 fix
//
// User caught: "merge engine 现在只裁决 delta ID,还没有真正 apply
// patchJson 到 state graph"。 Previously `BASAgentMergeEngine.merge`
// returned `acceptedDeltaIDs` but never wrote the patches into the
// shared state graph — pure metadata shuffle。
//
// This module bridges the gap:given a merge result + accepted deltas
// + state graph + writer specs,it WRITES the patches via
// `BASSharedStateGraph.writeObject`,respecting both per-agent
// writeDomains AND the global single-writer registry (USER-PASS gap #1)。
//
// Pure-async function (no shared state beyond the supplied graph)。
// Returns a per-delta application result so caller can log per-delta
// outcome to the audit ledger。

import Foundation

public struct BASAgentDeltaApplicationOutcome:
    Sendable, Equatable, Hashable, Codable
{
    public let deltaID: String
    /// True = patch was written to state graph。 False = caller
    /// should consult `errorReason`。
    public let applied: Bool
    /// Reference to the written state object (when applied)。 Empty
    /// when application failed。
    public let writtenRef: String
    /// Reason if not applied — short code: "no-delta", "writer-not-found",
    /// "graph-error.unauthorizedWriter" / ".forbiddenDomain" / etc。
    public let errorReason: String

    public init(
        deltaID: String,
        applied: Bool,
        writtenRef: String,
        errorReason: String
    ) {
        self.deltaID = deltaID
        self.applied = applied
        self.writtenRef = writtenRef
        self.errorReason = errorReason
    }
}

public enum BASAgentMergeApplier {

    /// Apply the accepted deltas from a `BASAgentMergeResult` into the
    /// `BASSharedStateGraph`。 Per delta:looks up the originating
    /// agent spec,extracts target domain+objectID from
    /// `targetObjectRef`,writes the patch via
    /// `graph.writeObject(...)`。 Returns per-delta outcome list。
    ///
    /// Patch semantics per delta type:
    ///   - `.add`,`.replace`,`.merge`,`.annotate`:write
    ///      `patchJson` as the new payload。 The state-graph object's
    ///      payload becomes the patch (caller is responsible for
    ///      composing partial updates upstream when needed —
    ///      richer JSON-merge-patch semantics can land in a future
    ///      chapter without changing this signature)。
    ///   - `.remove`:writes an empty payload `""` to mark tombstone。
    ///      Future state-graph evolution can introduce explicit
    ///      `deleteObject` op,but for Phase 0 + Phase 1 a
    ///      tombstone-payload convention is sufficient for replay。
    ///
    /// Critical: this function does NOT re-run conflict resolution。
    /// It assumes `mergeResult` is the authoritative output of
    /// `BASAgentMergeEngine.merge`。 Callers MUST not pass deltas
    /// not in `mergeResult.acceptedDeltaIDs`。
    public static func apply(
        mergeResult: BASAgentMergeResult,
        deltas: [BASAgentDelta],
        agents: [String: BASAgentSpec],
        graph: BASSharedStateGraph
    ) async -> [BASAgentDeltaApplicationOutcome] {
        let deltaByID = Dictionary(
            uniqueKeysWithValues: deltas.map { ($0.deltaID, $0) })
        var outcomes: [BASAgentDeltaApplicationOutcome] = []
        // Strip "delta:" prefix used by mergeResult
        let acceptedIDs = mergeResult.acceptedDeltaIDs.map {
            $0.hasPrefix("delta:")
                ? String($0.dropFirst("delta:".count))
                : $0
        }
        for deltaID in acceptedIDs {
            guard let delta = deltaByID[deltaID] else {
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: false,
                        writtenRef: "",
                        errorReason: "no-delta"))
                continue
            }
            guard let agent = agents[delta.agentID] else {
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: false,
                        writtenRef: "",
                        errorReason: "writer-not-found"))
                continue
            }
            let parsed: (
                domain: BASStateDomain, objectID: String)
            do {
                parsed = try BASStateGraphObject.parse(
                    ref: delta.targetObjectRef)
            } catch {
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: false,
                        writtenRef: "",
                        errorReason:
                            "graph-error.malformedObjectRef"))
                continue
            }
            let payloadJson = effectivePayload(for: delta)
            do {
                let written = try await graph.writeObject(
                    domain: parsed.domain,
                    objectID: parsed.objectID,
                    payloadJson: payloadJson,
                    byAgent: agent)
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: true,
                        writtenRef: written.ref,
                        errorReason: ""))
            } catch let err as BASSharedStateGraphError {
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: false,
                        writtenRef: "",
                        errorReason:
                            "graph-error.\(errCode(err))"))
            } catch {
                outcomes.append(
                    BASAgentDeltaApplicationOutcome(
                        deltaID: deltaID,
                        applied: false,
                        writtenRef: "",
                        errorReason: "unknown-error"))
            }
        }
        return outcomes
    }

    /// Per-deltaType payload semantics。 See `apply(_:...)` doc。
    ///
    /// chapter 九百九十五.9 META-REVIEW Round-14 HIGH-1 doctrine:
    /// the applier intentionally collapses `.add` / `.replace` /
    /// `.merge` / `.annotate` into one identical branch (all
    /// return `delta.patchJson`)。 The deltaType is preserved in
    /// the delta itself + stored alongside the graph write as a
    /// SEMANTIC TAG consumed downstream by audit/replay/diff
    /// tooling — not a behavioral switch at apply time。 The
    /// applier's responsibility is "write the payload";
    /// type-distinction is consumer-side semantics。
    ///
    /// **✅ WIRED at ch 1002** per `Docs/SCAFFOLD_VS_WIRED.md`:
    /// the `.annotate` case is now emitted by `BASTraceAnnotatorSeat`
    /// (the audit-only "trace seat" anticipated by this comment)。
    /// All 5 deltaType cases are alive:
    ///   - `.add`:Planner + EvolutionShadow (new candidates)
    ///   - `.merge`:Scout + Memory + Critic + Risk + HostAlign
    ///   - `.replace`:Surface + SovereignSentinel
    ///   - `.remove`:tombstone path (`""` payload)
    ///   - `.annotate`:TraceAnnotator (new `.traceAnnotation`
    ///      domain;closes the ch 996 💀 DEAD entry)。
    private static func effectivePayload(
        for delta: BASAgentDelta
    ) -> String {
        switch delta.deltaType {
        case .remove:
            return ""   // tombstone convention
        case .add, .replace, .merge, .annotate:
            return delta.patchJson
        }
    }

    private static func errCode(
        _ err: BASSharedStateGraphError
    ) -> String {
        switch err {
        case .unauthorizedWriter: return "unauthorizedWriter"
        case .unauthorizedReader: return "unauthorizedReader"
        case .forbiddenDomain: return "forbiddenDomain"
        case .objectNotFound: return "objectNotFound"
        case .malformedObjectRef: return "malformedObjectRef"
        case .domainAlreadyClaimed: return "domainAlreadyClaimed"
        case .writerIdentityMismatch:
            return "writerIdentityMismatch"
        }
    }
}
