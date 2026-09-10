// MARK: - BASFrameContext — chapter 四百三 / M953 — 系统熵 reduction
//
// Phase 2 (entropy-restructured) 第一刀:typed value type that
// carries the (sessionID, turnID, emittedAt) triplet which today
// gets threaded through 12 `withDerived*ObservationBundle(turnID:
// sessionID:emittedAt:)` call sites in `EBrainRuntimeCoordinator
// .runTurn(_:)`。Single typed surface ⇒ one-arg threading instead
// of three-arg threading,drift between sessionID/turnID
// derivation formulas locked at one source of truth。
//
// ## Why this exists (system entropy framing)
//
// Per the chapter 四百三 entropy audit (M952 close-out + post-Phase-1
// audit on `next-next-gen-architecture-sweep`):
//
//   - **Threading entropy**: 12 call sites in runTurn pass
//     `(turnID, sessionID, emittedAt)` as separate args
//   - **Derivation entropy**: same `derivedSessionID` /
//     `derivedTurnID` formula could be re-implemented at any
//     observation site,causing drift
//   - **Audit-projection entropy**: 67 `*ForAudit` / `*ForGate`
//     locals re-thread the same triplet for audit emission
//
// `BASFrameContext` collapses all three by:
//
//   1. Holding the triplet as one immutable value type
//   2. Pinning the derivation formula as one named typed
//      constructor (chapter 二百一一 single-source-of-truth)
//   3. Letting future runTurn rewrites pass ONE context arg to
//      every layer instead of unwrapping three fields per site
//
// ## What this ships
//
//   - `BASFrameContext` Codable Sendable Hashable Equatable
//     value type with three required fields
//   - `init(hostID:taskTypeRaw:runModeRaw:recordedAt:)`
//     convenience that pins the runTurn derivation formula
//     verbatim (chapter 三百九二 replay-determinism — same input
//     always produces same context)
//   - `recordedAtMs` accessor for downstream consumers that need
//     UNIX millis,not Date
//
// ## Doctrine pins held
//
//   - 不变量 #1 / #2 / #3 — context is observation plumbing
//   - 红线 7 hint-only — context is identity,not decision
//   - chapter 一百八十五 anti-magic-number — sessionID separator
//     ("|") and turnID separator ("#") pinned as named typed
//     constants
//   - chapter 二百一一 single-source-of-truth — ONE derivation
//     formula。Drift detected → fail loudly via M950-style
//     reflection test。
//   - chapter 三百九二 replay-determinism — same `(hostID,
//     taskTypeRaw, runModeRaw, recordedAt)` → same context
//   - ADR-014 OPT-IN → existing `(turnID, sessionID, emittedAt)`
//     threading still works;`BASFrameContext` is purely
//     additive。Phase-2 V2 actor adopts it natively;V1 stays
//     legacy。

import Foundation

// MARK: - Frame context

public struct BASFrameContext:
    Codable, Equatable, Hashable, Sendable
{

    // MARK: - chapter 一百八十五 anti-magic-number — separators

    /// Separator joining hostID + taskType + runMode into the
    /// derived sessionID。Pinned constant — drift triggers the
    /// M950 doctrine guardrail (BAS211 single-source-of-truth)。
    public static let sessionIDSeparator: String = "|"

    /// Separator joining sessionID + recordedAt timestamp into
    /// the derived turnID。Pinned constant per chapter 一百八十五。
    public static let turnIDSeparator: String = "#"

    // MARK: - Required identity

    /// Stable session identifier for the current turn。Per the
    /// runTurn derivation formula (chapter 二百一一):
    /// `[hostID, taskType.rawValue, runMode.rawValue]
    ///  .joined(separator: sessionIDSeparator)`
    public let sessionID: String

    /// Stable turn identifier。Per the runTurn derivation formula:
    /// `"\(sessionID)\(turnIDSeparator)\(recordedAt.timeIntervalSinceReferenceDate)"`
    public let turnID: String

    /// Wall-clock at frame emission (the request's recordedAt for
    /// per-turn replay-determinism)。
    public let emittedAt: Date

    // MARK: - Init

    /// Direct init when sessionID + turnID are already derived
    /// elsewhere (e.g. legacy callers that built the formula
    /// inline)。
    public init(
        sessionID: String,
        turnID: String,
        emittedAt: Date
    ) {
        self.sessionID = sessionID
        self.turnID = turnID
        self.emittedAt = emittedAt
    }

    /// Canonical convenience init that pins the runTurn
    /// derivation formula。Same `(hostID, taskTypeRaw,
    /// runModeRaw, recordedAt)` → same context (chapter 三百九二
    /// replay-determinism)。
    public init(
        hostID: String,
        taskTypeRaw: String,
        runModeRaw: String,
        recordedAt: Date
    ) {
        let sid = [
            hostID,
            taskTypeRaw,
            runModeRaw
        ].joined(separator: BASFrameContext.sessionIDSeparator)
        let tid = sid +
            BASFrameContext.turnIDSeparator +
            "\(recordedAt.timeIntervalSinceReferenceDate)"
        self.sessionID = sid
        self.turnID = tid
        self.emittedAt = recordedAt
    }

    // MARK: - Convenience accessors

    /// `emittedAt` as UNIX millis (Int64)。Useful for downstream
    /// event-log consumers that index by ms。
    public var recordedAtMs: Int64 {
        Int64(emittedAt.timeIntervalSince1970 * 1000)
    }

    /// `emittedAt` as seconds since reference date。Mirrors the
    /// turnID formula — useful for tests asserting derivation
    /// equality。
    public var recordedAtTimeIntervalSinceReferenceDate: Double {
        emittedAt.timeIntervalSinceReferenceDate
    }
}
