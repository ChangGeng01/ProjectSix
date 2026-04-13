import Foundation
import BASMemory
import BASObservability
import BASOrchestration
import BASPolicy
import BASRuntimeCore

public enum BASEBrainSchemaGovernanceRegistry {
    public static let governedSchemas: [BASSchemaGovernanceEntry] = [
        entry(
            "ContextFrame",
            versionedType: BASContextFrame.self,
            tests: ["schema.context.current", "schema.context.backward"]
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
            "HostProfile",
            versionedType: BASHostProfile.self,
            tests: ["schema.host.current", "schema.host.backward"]
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
            "UpdateTicket",
            versionedType: BASUpdateTicket.self,
            tests: ["schema.ticket.current", "schema.ticket.backward"]
        ),
        entry(
            "RuntimeTrace",
            versionedType: BASRuntimeTrace.self,
            tests: ["schema.trace.current", "schema.trace.backward"]
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
