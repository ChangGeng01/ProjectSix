import Foundation

// 五十一 — typed attestation binding envelope provenance to its
// authoring-session attained level.
//
// ## Why this exists
//
// M295.1 ship 了 `BASWorldPriorTemplateEnvelope` (envelope +
// provenance). M295.1.0 ship 了
// `BASWorldPriorTemplateAuthoringSession` (typed authoring
// lifecycle). 两者 **decoupled**：envelope.provenance 由 caller
// 任意标，authoring session.attainedProvenance 由 stage 决定。
//
// 这留下一个攻击面：caller 可以 wrap 一个 illustrative draft
// 内容标 `.axiomatic` envelope 直接送 production gate ——
// 绕 authoring lifecycle。M295.2 training filter 不会 catch 这条
// （filter 只看 envelope.provenance + input acceptance，不看
// session）。
//
// `BASWorldPriorTemplateAttestation` 把两者 typed-bind：每个
// production-grade envelope 必须配一个 authoring session，
// envelope 的 provenance 不能超过 session 的 attainedProvenance。
//
// ## Doctrine
//
// **Attestation 不变量**：
//
// 1. **Provenance attainment binding**：envelope.provenance ≤
//    session.attainedProvenance。Caller 可以 deliberate
//    downgrade（标 illustrative 即使 session axiomatized），但
//    NEVER 越级。
// 2. **Template ID binding**：envelope.input.templateID ==
//    session.templateID。两者必须指同一 template。
//
// 不变量违反 → `BASWorldPriorTemplateAttestationIssue` typed
// 列表，audit / production gate 可分支。
//
// ## What this is NOT
//
// - 不是密码学签名——provenance attainment 是 typed claim
//   binding，不防 in-process 攻击；in-process 信任由 dual-key
//   sovereign + sandbox 守。Attestation 锁的是 typed contract
//   一致性。
// - 不替代 M295.0 acceptance check / M295.2 training filter。
//   是 *additional* gate：envelope 想升级 production 必须过
//   M295.0 + M295.2 + 本节 Attestation 三个独立 check。

public struct BASWorldPriorTemplateAttestation:
    Sendable, Equatable, Hashable, Codable
{
    public let envelope: BASWorldPriorTemplateEnvelope
    public let authoringSession:
        BASWorldPriorTemplateAuthoringSession

    public init(
        envelope: BASWorldPriorTemplateEnvelope,
        authoringSession:
            BASWorldPriorTemplateAuthoringSession
    ) {
        self.envelope = envelope
        self.authoringSession = authoringSession
    }
}

public enum BASWorldPriorTemplateAttestationIssue:
    Sendable, Equatable, Hashable, Codable
{
    /// Envelope claims provenance higher than the authoring
    /// session has attained. Carries claimed vs attained for
    /// audit.
    case envelopeProvenanceExceedsSession(
        claimed: BASWorldPriorTemplateProvenance,
        attained: BASWorldPriorTemplateProvenance)

    /// `envelope.input.templateID` ≠ `session.templateID`.
    /// Attestation requires both to refer to the same template.
    case templateIDMismatch(
        envelopeID: String,
        sessionID: String)
}

public enum BASWorldPriorTemplateAttestationGate {

    /// Run all attestation invariants. Returns (possibly
    /// empty) typed issues. Empty = valid attestation.
    public static func validate(
        _ attestation: BASWorldPriorTemplateAttestation
    ) -> [BASWorldPriorTemplateAttestationIssue] {
        var issues: [
            BASWorldPriorTemplateAttestationIssue
        ] = []

        // Invariant 1: provenance attainment binding.
        if attestation.envelope.provenance
            > attestation.authoringSession
                .attainedProvenance
        {
            issues.append(
                .envelopeProvenanceExceedsSession(
                    claimed: attestation.envelope
                        .provenance,
                    attained: attestation
                        .authoringSession
                        .attainedProvenance))
        }

        // Invariant 2: template ID binding.
        if attestation.envelope.input.templateID
            != attestation.authoringSession.templateID
        {
            issues.append(
                .templateIDMismatch(
                    envelopeID: attestation.envelope
                        .input.templateID,
                    sessionID: attestation
                        .authoringSession.templateID))
        }

        return issues
    }

    /// Convenience — empty issues = valid.
    public static func isValid(
        _ attestation: BASWorldPriorTemplateAttestation
    ) -> Bool {
        validate(attestation).isEmpty
    }
}
