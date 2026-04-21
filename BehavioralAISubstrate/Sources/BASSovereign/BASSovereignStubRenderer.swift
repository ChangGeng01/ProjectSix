import Foundation
import BASRuntimeCore

/// `BR-09` StubRenderer — the sovereign placeholder renderer.
///
/// ## Role
///
/// When the sovereign loop denies a request — verdict is
/// `shadowLock` or harder, or a lock is active, or a permit is
/// missing — **something still has to be returned to the caller**.
/// Returning nothing leaks the internal wall; returning the real
/// internal error leaks sovereign reasoning.
///
/// StubRenderer produces a minimal, policy-compliant surface
/// response that:
///
/// - Tells the caller the request was not executed.
/// - Carries only an opaque audit reference for follow-up.
/// - Does **not** leak internal rule IDs, lock IDs, token IDs,
///   or quarantine details unless the verdict mode explicitly
///   allows a `.minimalReceipt`.
///
/// The three `BASSovereignUserStubMode` modes are honored literally:
///
/// - `.none`: no stub is produced (caller handles the refusal).
/// - `.minimalReceipt`: a single-line "not executed + audit ref".
/// - `.refusalOnly`: a fixed refusal phrase; no audit ref surfaced.
public actor BASSovereignStubRenderer {
    public struct StubOutput: Sendable, Equatable {
        /// The user-visible text. Safe to show in UI directly.
        public let body: String
        /// Audit reference the caller may log. Only populated when
        /// the mode is `.minimalReceipt`; empty string otherwise so
        /// that `.refusalOnly` cannot accidentally leak an id.
        public let auditRef: String
        /// Echo of the mode used. Diagnostic — the renderer's
        /// contract is that the body/auditRef already match the mode.
        public let mode: BASSovereignUserStubMode

        public init(body: String, auditRef: String, mode: BASSovereignUserStubMode) {
            self.body = body
            self.auditRef = auditRef
            self.mode = mode
        }
    }

    public struct RefusalPhrases: Sendable, Equatable {
        public let refusalOnly: String
        public let minimalReceiptPrefix: String

        public init(
            refusalOnly: String = "This request was not executed by policy.",
            minimalReceiptPrefix: String = "Not executed. Reference:"
        ) {
            self.refusalOnly = refusalOnly
            self.minimalReceiptPrefix = minimalReceiptPrefix
        }

        public static let builtIn = RefusalPhrases()
    }

    private let phrases: RefusalPhrases

    public init(phrases: RefusalPhrases = .builtIn) {
        self.phrases = phrases
    }

    // MARK: - Render

    /// Render a stub for a verdict. The verdict's `userStubMode`
    /// decides the shape; the caller-supplied `fallbackAuditRef`
    /// feeds the receipt in `.minimalReceipt` mode. In `.none`
    /// mode this returns `nil` — the caller is expected to handle
    /// the refusal itself.
    public func render(
        verdict: BASSovereignVerdict,
        fallbackAuditRef: String
    ) -> StubOutput? {
        render(mode: verdict.userStubMode, auditRef: fallbackAuditRef)
    }

    /// Lower-level form — used when the refusal origin is a permit
    /// miss or a lock, not a full verdict. The mode is picked by
    /// the caller (typically derived from current lock level via
    /// `defaultStubMode(for:)`).
    public func render(
        mode: BASSovereignUserStubMode,
        auditRef: String
    ) -> StubOutput? {
        switch mode {
        case .none:
            return nil
        case .refusalOnly:
            return StubOutput(
                body: phrases.refusalOnly,
                auditRef: "",
                mode: .refusalOnly
            )
        case .minimalReceipt:
            let ref = auditRef.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = ref.isEmpty
                ? phrases.refusalOnly
                : "\(phrases.minimalReceiptPrefix) \(ref)"
            return StubOutput(
                body: body,
                auditRef: ref,
                mode: .minimalReceipt
            )
        }
    }

    /// Recommend a stub mode given a verdict level. The sovereign
    /// loop uses this when a caller hasn't pre-decided a mode. The
    /// mapping is intentionally conservative:
    ///
    /// - `pass/throttle`: no stub needed (`.none`).
    /// - `shadowLock/toolCut/memoryFreeze/quarantine`: minimal
    ///   receipt — the caller has enough signal to debug through
    ///   the audit ledger.
    /// - `rollback/deadStop`: refusal only — we are in an integrity
    ///   or self-mutation posture where the less we say, the better.
    public static func defaultStubMode(
        for level: BASSovereignVerdictLevel
    ) -> BASSovereignUserStubMode {
        switch level {
        case .pass, .throttle:
            return .none
        case .shadowLock, .toolCut, .memoryFreeze, .quarantine:
            return .minimalReceipt
        case .rollback, .deadStop:
            return .refusalOnly
        }
    }

    // MARK: - Leak audit

    /// Cheap sanity check that a stub body doesn't contain any of the
    /// internal tokens that must never leak to the user surface. Used
    /// in tests and (optionally) as a final belt-and-suspenders check
    /// before the renderer hands the body over.
    public static let forbiddenTokens: [String] = [
        "BR-0", "BR-00",
        "verdict-", "verdictID", "verdictLevel",
        "sct-", "swt-",
        "ledger-", "auditID",
        "quarantine:", "lock-",
        "IntegritySentinel", "VerdictEngine", "TokenAuthority",
        "PrivilegeArbiter", "ContaminationGuard", "SnapshotManager",
        "SovereignLockManager", "StubRenderer",
        "BlackRing", "BAS"
    ]

    public static func leaks(_ body: String) -> [String] {
        forbiddenTokens.filter { body.contains($0) }
    }
}
