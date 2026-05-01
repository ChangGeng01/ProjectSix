import Foundation

// 四十五.7+ — typed reference for honesty-board 四十五.2 三流
// model (cognition / permission / growth). Pure typed vocabulary
// — no I/O, no runtime contract beyond the enum identity.
//
// ## Why this exists
//
// Honesty-board 四十五.2 names three streams that span the system:
//
// - **认知流** input → loop → council → decision → surface
// - **权限流** neural intent → second-brain permit → SDK execute
// - **成长流** host feedback → SDK log → update ticket → shadow
//   trial → version delta
//
// Audit / instrumentation / dashboards reference these streams
// through string tags. Different callers naming the same stream
// differently is a slow drift bug. This file ships the typed
// vocabulary so all references go through one source of truth.
//
// ## Doctrine
//
// - **Streams are exhaustive partition of system flows** —
//   every meaningful system event lives in exactly one stream.
//   The three streams cover everything; if a flow doesn't fit,
//   either it's a bug or the stream taxonomy needs revision
//   (which would itself be a doctrine-level change registered
//   in honesty-board).
// - **Stages within streams are stable identifiers** —
//   audit / instrumentation can group events by stage and
//   trust the labels.
// - **stage → stream is a function** (each stage belongs to
//   exactly one stream) — pinned by tests.

public enum BASManifestStream:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    /// 认知流 — input flows through loop / council to decision
    /// and surface render.
    case cognition

    /// 权限流 — neural intent flows through second-brain permit
    /// to SDK execution. Doctrine D enforcement boundary.
    case permission

    /// 成长流 — host feedback flows through SDK logging to
    /// update tickets and version deltas. Doctrine A enforcement
    /// boundary (host-private content stops at SDK + L5).
    case growth
}

public enum BASManifestStreamStage:
    String, Sendable, Equatable, Hashable, Codable, CaseIterable
{
    // Cognition stages (5)
    case input
    case loopGenerate
    case councilDispatch
    case decision
    case surfaceRender

    // Permission stages (3)
    case neuralIntent
    case secondBrainPermit
    case sdkExecute

    // Growth stages (5)
    case hostFeedback
    case sdkLog
    case updateTicket
    case shadowTrial
    case versionDelta

    /// Which stream this stage belongs to. Function — every
    /// stage maps to exactly one stream.
    public var stream: BASManifestStream {
        switch self {
        case .input,
             .loopGenerate,
             .councilDispatch,
             .decision,
             .surfaceRender:
            return .cognition
        case .neuralIntent,
             .secondBrainPermit,
             .sdkExecute:
            return .permission
        case .hostFeedback,
             .sdkLog,
             .updateTicket,
             .shadowTrial,
             .versionDelta:
            return .growth
        }
    }
}

public extension BASManifestStream {
    /// All stages in this stream, in canonical flow order.
    var stages: [BASManifestStreamStage] {
        BASManifestStreamStage.allCases.filter {
            $0.stream == self
        }
    }
}
