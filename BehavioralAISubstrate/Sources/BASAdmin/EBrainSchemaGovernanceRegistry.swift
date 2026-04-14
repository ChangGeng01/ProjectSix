import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public enum BASEBrainSchemaGovernanceRegistry {
    public static let governedSchemas: [BASSchemaGovernanceEntry] = [
        entry(
            "DeviceState",
            versionedType: BASDeviceState.self,
            tests: ["schema.device.current", "schema.device.backward"]
        ),
        entry(
            "BudgetFrame",
            versionedType: BASBudgetFrame.self,
            tests: ["schema.budget.current", "schema.budget.backward"]
        ),
        entry(
            "HostProfile",
            versionedType: BASHostProfile.self,
            tests: ["schema.host.current", "schema.host.backward"]
        ),
        entry(
            "HostVersion",
            versionedType: BASHostVersion.self,
            tests: ["schema.host_version.current", "schema.host_version.backward"]
        ),
        entry(
            "MemoryAtom",
            versionedType: BASMemoryAtom.self,
            tests: ["schema.memory.current", "schema.memory.backward"]
        ),
        entry(
            "MemoryBundle",
            versionedType: BASMemoryBundle.self,
            tests: ["schema.memory_bundle.current", "schema.memory_bundle.backward"]
        ),
        entry(
            "RuleCandidate",
            versionedType: BASRuleCandidate.self,
            tests: ["schema.rule.current", "schema.rule.backward"]
        ),
        entry(
            "ContextFrame",
            versionedType: BASContextFrame.self,
            tests: ["schema.context.current", "schema.context.backward"]
        ),
        entry(
            "DecomposeFrame",
            versionedType: BASDecomposeFrame.self,
            tests: ["schema.decompose.current", "schema.decompose.backward"]
        ),
        entry(
            "CandidatePath",
            versionedType: BASCandidatePath.self,
            tests: ["schema.candidate.current", "schema.candidate.backward"]
        ),
        entry(
            "ForecastItem",
            versionedType: BASForecastItem.self,
            tests: ["schema.forecast.current", "schema.forecast.backward"]
        ),
        entry(
            "CritiqueItem",
            versionedType: BASCritiqueItem.self,
            tests: ["schema.critique.current", "schema.critique.backward"]
        ),
        entry(
            "ThoughtFrame",
            versionedType: BASThoughtFrame.self,
            tests: ["schema.thought.current", "schema.thought.backward"]
        ),
        entry(
            "ThoughtFold",
            versionedType: BASThoughtFold.self,
            tests: ["schema.fold.current", "schema.fold.backward"]
        ),
        entry(
            "TriSelfScore",
            versionedType: BASTriSelfScore.self,
            tests: ["schema.triself.current", "schema.triself.backward"]
        ),
        entry(
            "MergedChoice",
            versionedType: BASMergedChoice.self,
            tests: ["schema.choice.current", "schema.choice.backward"]
        ),
        entry(
            "RenderedOutput",
            versionedType: BASRenderedOutput.self,
            tests: ["schema.output.current", "schema.output.backward"]
        ),
        entry(
            "RiskCard",
            versionedType: BASRiskCard.self,
            tests: ["schema.risk.current", "schema.risk.backward"]
        ),
        entry(
            "ActionPermit",
            versionedType: BASActionPermit.self,
            tests: ["schema.permit.current", "schema.permit.backward"]
        ),
        entry(
            "UpdateTicket",
            versionedType: BASUpdateTicket.self,
            tests: ["schema.ticket.current", "schema.ticket.backward"]
        ),
        entry(
            "EvolutionLineageSummary",
            versionedType: BASEvolutionLineageSummary.self,
            tests: ["schema.lineage.current", "schema.lineage.backward"]
        ),
        entry(
            "RuntimeTrace",
            versionedType: BASRuntimeTrace.self,
            tests: ["schema.trace.current", "schema.trace.backward"]
        ),
        entry(
            "EvalSample",
            versionedType: BASEvalSample.self,
            tests: ["schema.eval.current", "schema.eval.backward"]
        ),
        entry(
            "ModelArtifact",
            versionedType: BASModelArtifact.self,
            tests: ["schema.model.current", "schema.model.backward"]
        ),
        entry(
            "FeedbackEvent",
            versionedType: BASFeedbackEvent.self,
            tests: ["schema.feedback.current", "schema.feedback.backward"]
        )
    ]

    public static func entry(
        for objectID: String
    ) -> BASSchemaGovernanceEntry? {
        governedSchemas.first(where: { $0.objectID == objectID })
    }

    private static func entry<T: BASSchemaVersioned>(
        _ objectID: String,
        versionedType: T.Type,
        tests migrationTests: [String]
    ) -> BASSchemaGovernanceEntry {
        BASSchemaGovernanceEntry(
            objectID: objectID,
            currentVersion: versionedType.currentSchemaVersion,
            compatibilityWindow: "2 minor versions",
            deprecationPolicy: "Mark deprecated for one milestone before removal.",
            migrationTestIDs: migrationTests,
            rollbackPolicy: "Rehydrate the previous schema snapshot and preserve replay fidelity."
        )
    }
}
