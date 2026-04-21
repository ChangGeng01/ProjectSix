import Foundation
import BASRuntimeCore
import BASSovereign
import BASWorldPrior

/// Thin integration bridge between `BASWorldPrior` (L4) and
/// `BASSovereign` (L14). Both underlying modules are strict leaves
/// — they don't know about each other. The bridge lives in
/// `BASOrchestration` because that is the first layer that depends
/// on both.
///
/// ## Why this exists
///
/// One of the public product promises is that the second brain
/// "懂世界也懂宿主" — it should refuse irreversible ethics-domain
/// actions without informed consent regardless of what the host
/// layer, the risk gate, or the prompt tries to justify. Before
/// this bridge, the world-prior vault existed but had no consumer:
/// `L4` was a queryable library and `L14` evaluated verdicts using
/// only soft signals and hard observations surfaced by other
/// subsystems. Nobody was asking the vault.
///
/// This bridge wires the vault into the verdict path:
///
/// 1. A caller proposes an intent tagged with the template ID it
///    believes the intent matches (in production this tagging
///    comes from L9 dream-loop projection; here it's explicit).
/// 2. The bridge queries the vault for a `BASWorldPriorRiskAssessment`.
/// 3. The assessment's `irreversibleHarmScore` is folded into the
///    soft signals the verdict engine already consumes.
/// 4. The assessment's `requiresConsent` elevates the operation
///    domain to `hostMutate` if the caller hasn't acknowledged
///    consent — this triggers the engine's evidence-insufficient
///    upgrade path when the L4 evidence level is below
///    `wellSupported`.
///
/// The bridge is intentionally narrow: it does not invent new
/// policy. Every knob it turns is a knob the verdict engine
/// already exposes.
public actor BASWorldAwareRiskBridge {
    public enum BridgeError: Error, Equatable, Sendable {
        case unknownTemplate(String)
    }

    private let worldVault: BASWorldPriorVault
    private let verdictEngine: BASSovereignVerdictEngine

    public init(
        worldVault: BASWorldPriorVault,
        verdictEngine: BASSovereignVerdictEngine
    ) {
        self.worldVault = worldVault
        self.verdictEngine = verdictEngine
    }

    /// A proposed intent, described in the terms the bridge needs
    /// to make a decision. `matchedTemplateID` comes from whatever
    /// upstream component routed this intent — L9 projection, a
    /// retrieval index, or an explicit policy rule.
    public struct ProposedIntent: Sendable, Equatable {
        public let sessionID: String
        public let turnID: String
        public let operation: BASSovereignVerdictEngine.OperationDomain
        /// Template ID the caller believes this intent matches.
        public let matchedTemplateID: String
        /// Caller-declared consent acknowledgement. For ethics
        /// templates with `requiresConsent == true`, the absence
        /// of this flag upgrades the verdict floor.
        public let consentAcknowledged: Bool
        /// Existing soft signals from other subsystems (risk gate,
        /// integrity sentinel). The bridge ADDS to these, never
        /// replaces them.
        public let baselineSignals: BASSovereignVerdictEngine.SoftSignals
        public let baselineObservations:
            BASSovereignVerdictEngine.HardObservations
        public let snapshotRef: String

        public init(
            sessionID: String,
            turnID: String,
            operation: BASSovereignVerdictEngine.OperationDomain,
            matchedTemplateID: String,
            consentAcknowledged: Bool = false,
            baselineSignals: BASSovereignVerdictEngine.SoftSignals = .calm,
            baselineObservations:
                BASSovereignVerdictEngine.HardObservations = .clean,
            snapshotRef: String = ""
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.operation = operation
            self.matchedTemplateID = matchedTemplateID
            self.consentAcknowledged = consentAcknowledged
            self.baselineSignals = baselineSignals
            self.baselineObservations = baselineObservations
            self.snapshotRef = snapshotRef
        }
    }

    /// Result bundle: the verdict plus the L4 assessment that
    /// shaped it. Exposed so tests / observability layers can
    /// prove "this verdict actually used world-prior knowledge".
    public struct Decision: Sendable, Equatable {
        public let verdict: BASSovereignVerdict
        public let assessment: BASWorldPriorRiskAssessment
    }

    /// Evaluate a proposed intent end-to-end: query L4, build
    /// enriched verdict context, run L14 verdict engine, return
    /// the decision bundle.
    public func evaluate(
        intent: ProposedIntent
    ) async throws -> Decision {
        guard
            let assessment = await worldVault.assessRisk(
                templateID: intent.matchedTemplateID)
        else {
            throw BridgeError.unknownTemplate(intent.matchedTemplateID)
        }

        // Fold world-prior harm score into the existing signal
        // surface using max(): the bridge only raises the floor,
        // never lowers it.
        let mergedSignals = merge(
            baseline: intent.baselineSignals,
            assessment: assessment
        )

        // If L4 says consent is required and caller didn't
        // acknowledge, the operation is effectively a host
        // mutation attempt — route it through the upgrade path.
        let effectiveOperation: BASSovereignVerdictEngine.OperationDomain = {
            if assessment.requiresConsent && !intent.consentAcknowledged {
                return .hostMutate
            }
            return intent.operation
        }()

        // Evidence sufficiency: AND the caller's existing
        // assumption with L4's view. Either side of "insufficient"
        // wins.
        let evidenceSufficient = assessment.evidenceSufficient

        let context = BASSovereignVerdictEngine.VerdictContext(
            sessionID: intent.sessionID,
            turnID: intent.turnID,
            operation: effectiveOperation,
            hardObservations: intent.baselineObservations,
            softSignals: mergedSignals,
            evidenceSufficient: evidenceSufficient,
            snapshotRef: intent.snapshotRef
        )

        let verdict = try await verdictEngine.evaluate(context)
        return Decision(verdict: verdict, assessment: assessment)
    }

    // MARK: - Signal merging

    private func merge(
        baseline: BASSovereignVerdictEngine.SoftSignals,
        assessment: BASWorldPriorRiskAssessment
    ) -> BASSovereignVerdictEngine.SoftSignals {
        let elevated = max(
            baseline.irreversibleHarm,
            assessment.irreversibleHarmScore
        )
        return BASSovereignVerdictEngine.SoftSignals(
            integrity: baseline.integrity,
            privilegeViolation: baseline.privilegeViolation,
            selfMod: baseline.selfMod,
            memoryContamination: baseline.memoryContamination,
            irreversibleHarm: elevated,
            runtimeInstability: baseline.runtimeInstability,
            manipulationIntrusion: baseline.manipulationIntrusion
        )
    }
}
