// BASConsoleView — audit M-o MED-2.
//
// Extracted from BASAdmin/AdminCore.swift into its own BASAdminUI target so
// the substrate-core BASAdmin module — and every HEADLESS host that depends
// on it transitively (BASBrainCLI, BASJournalCLI via BASHostKit) — no longer
// links SwiftUI just to satisfy a gate the module boundary couldn't see. UI
// hosts depend on BASAdminUI explicitly; core stays SwiftUI-free.
import SwiftUI
import BASAdmin

public struct BASConsoleView: View {
    private let snapshot: BASConsoleSnapshot

    public init(snapshot: BASConsoleSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Substrate console")
                .font(.headline)

            Text(snapshot.overallSummary)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let runtimeSummary = snapshot.displayRuntimeSummary {
                Text(runtimeSummary)
                    .font(.subheadline.weight(.medium))

                if let killSwitchSummary = runtimeKillSwitchSummary(from: runtimeSummary) {
                    Text("Kill switches: \(killSwitchSummary)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !snapshot.effectiveLayerStackLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.layerStackTitle)
                        .font(.caption.weight(.semibold))
                    ForEach(snapshot.effectiveLayerStackLines, id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let brainSummary = snapshot.brainSummary {
                platformSelectableBrainSummary(brainSummary)
            }

            ForEach(snapshot.reports) { report in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(report.kind.title)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(report.health.title)
                            .font(.caption2)
                            .foregroundStyle(report.health == .healthy ? .secondary : .primary)
                    }

                    Text(report.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !report.blockers.isEmpty {
                        Text(report.blockers.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !snapshot.blockerSummary.isEmpty {
                Text(snapshot.blockerSummary.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let inspectionBundle = snapshot.inspectionBundle {
                Divider()

                Text("Runtime audit")
                    .font(.caption.weight(.semibold))

                Text(inspectionBundle.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Release \(inspectionBundle.releaseDecision.kind.rawValue) • \(inspectionBundle.releaseDecision.reason)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Replay \(inspectionBundle.replayFingerprint.value.prefix(12))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(
                    inspectionBundle.replayDisposition.isAvailable
                    ? "Replay available"
                    : "Replay blocked • \(inspectionBundle.replayDisposition.reason ?? "revoked")"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

                if !inspectionBundle.replayDisposition.vaultOutOfSyncDeviceIDs.isEmpty {
                    Text(
                        "Vault out-of-sync devices • \(inspectionBundle.replayDisposition.vaultOutOfSyncDeviceIDs.joined(separator: ", "))"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if let migrationTarget = inspectionBundle.replayDisposition.vaultMigrationTargetDeviceID {
                    Text("Vault migration target • \(migrationTarget)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let calibration = inspectionBundle.calibration {
                    Text("Calibration \(calibration.status) • alerts \(calibration.alertCount)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !inspectionBundle.anomalySignals.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audit findings")
                            .font(.caption2.weight(.medium))
                        ForEach(inspectionBundle.anomalySignals, id: \.id) { signal in
                            Text("\(signal.severity.uppercased()) • \(signal.kind) • \(signal.message)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let capabilityCoverage = snapshot.capabilityCoverage {
                Divider()

                Text("Capability coverage")
                    .font(.caption.weight(.semibold))

                Text("Coverage score \(capabilityCoverage.overallScore)/100")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let horizonCoverage = capabilityCoverage.horizonCoverage {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Horizon coverage")
                            .font(.caption2.weight(.medium))

                        ForEach(horizonCoverage.summaryLines, id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(capabilityCoverage.sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))

                        Text(section.headline)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ForEach(section.items) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.title)
                                        .font(.caption2.weight(.medium))
                                    Spacer()
                                    Text(item.status.title)
                                        .font(.caption2)
                                        .foregroundStyle(item.status == .ready ? .secondary : .primary)
                                }

                                Text(item.summary)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                if !item.evidence.isEmpty {
                                    Text(item.evidence.joined(separator: " • "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            let blueprint = snapshot.architectureBlueprint

            Text(blueprint.headline)
                .font(.caption.weight(.semibold))

            Text(blueprint.promise)
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Stack")
                    .font(.caption.weight(.semibold))

                ForEach(blueprint.stackLayers) { layer in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(layer.kind.title)
                                .font(.caption2.weight(.medium))
                            Spacer()
                            Text(layer.health.title)
                                .font(.caption2)
                                .foregroundStyle(layer.health == .healthy ? .secondary : .primary)
                        }

                        Text(layer.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if !layer.evidence.isEmpty {
                            Text(layer.evidence.joined(separator: " • "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Control Loops")
                    .font(.caption.weight(.semibold))

                ForEach(blueprint.controlLoops) { loop in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loop.kind.title)
                            .font(.caption2.weight(.medium))
                        Text(loop.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(loop.anchors.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Truth Planes")
                    .font(.caption.weight(.semibold))

                ForEach(blueprint.truthPlanes) { plane in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plane.kind.title)
                            .font(.caption2.weight(.medium))
                        Text(plane.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Execution Lanes")
                    .font(.caption.weight(.semibold))

                ForEach(blueprint.executionLanes) { lane in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lane.kind.title)
                            .font(.caption2.weight(.medium))
                        Text(lane.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !blueprint.innovationThesis.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Innovation Thesis")
                        .font(.caption.weight(.semibold))

                    ForEach(blueprint.innovationThesis, id: \.self) { thesis in
                        Text(thesis)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            let executionBlueprint = snapshot.currentProgramExecutionBlueprint
            let physiologyLayers = executionBlueprint.layers.filter { $0.kind.track == .physiology }
            let cognitionLayers = executionBlueprint.layers.filter { $0.kind.track == .cognition }
            let infrastructurePackages = executionBlueprint.workPackages.filter { $0.ownedLayers.isEmpty }
            let firstBatchPackages = executionBlueprint.workPackages.filter { $0.deliveryBatch == .first }

            Text(executionBlueprint.title)
                .font(.caption.weight(.semibold))

            Text(executionBlueprint.summary)
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Execution Summary")
                    .font(.caption.weight(.semibold))

                Text("Layers: \(executionBlueprint.layers.count) total • \(physiologyLayers.count) physiology • \(cognitionLayers.count) cognition")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Work packages: \(executionBlueprint.workPackages.count) total • \(firstBatchPackages.count) first batch • \(infrastructurePackages.count) infrastructure")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("Milestones: \(executionBlueprint.milestones.count) • Governed schemas: \(executionBlueprint.governedSchemas.count) • Red lines: \(executionBlueprint.hardRedLines.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Critical Path")
                    .font(.caption.weight(.semibold))

                ForEach(firstBatchPackages.prefix(8)) { workPackage in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(workPackage.id) • \(workPackage.title)")
                            .font(.caption2.weight(.medium))
                        Text(workPackage.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Duration \(workPackage.schedule.duration) • milestones \(workPackage.schedule.milestoneIDs.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Milestones")
                    .font(.caption.weight(.semibold))

                ForEach(executionBlueprint.milestones) { milestone in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(milestone.id) • \(milestone.title)")
                            .font(.caption2.weight(.medium))
                        Text(milestone.summary)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Schema Governance")
                    .font(.caption.weight(.semibold))

                Text(schemaGovernanceSummary(for: executionBlueprint))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(executionBlueprint.governedSchemas) { schema in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(schema.objectID) • v\(schema.currentVersion)")
                            .font(.caption2.weight(.medium))
                        Text("Compatibility \(schema.compatibilityWindow) • tests \(schema.migrationTestIDs.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hard Red Lines")
                    .font(.caption.weight(.semibold))

                ForEach(executionBlueprint.hardRedLines.prefix(5), id: \.self) { line in
                    Text(line)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func platformSelectableBrainSummary(_ summary: String) -> some View {
        // watchOS was dropped at ch1040 (Package.swift = iOS + macOS only),
        // so the former `#if os(watchOS)` branch was dead. iOS/macOS path only.
        Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
    }

    private func runtimeKillSwitchSummary(from runtimeSummary: String) -> String? {
        let marker = " • kill "
        guard let range = runtimeSummary.range(of: marker) else {
            return nil
        }

        let summary = runtimeSummary[range.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return summary.isEmpty ? nil : summary
    }

    private func schemaGovernanceSummary(for blueprint: BASProgramExecutionBlueprint) -> String {
        let versionSummary = blueprint.governedSchemas
            .map(\.currentVersion)
            .removingDuplicates()
            .joined(separator: ", ")
        let migrationTestCount = blueprint.governedSchemas
            .map(\.migrationTestIDs.count)
            .reduce(0, +)

        return "Schemas \(blueprint.governedSchemas.count) • versions \(versionSummary) • migration tests \(migrationTestCount) • appendices \(blueprint.requiredAppendices.count)"
    }
}

// audit M-o MED-2 — private copy for THIS module (the BASAdmin original at
// AdminCore.swift stays there for its own non-UI caller; a `private`
// extension is module-scoped so there is no cross-module clash).
private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}

// Relocated from BASHostKit/HostKitCore.swift:736 (audit M-o MED-2): the
// BASConsoleView re-export lives with the view in the UI target, keeping it
// OUT of the headless BASHostKit core.
public typealias BASHostConsoleView = BASConsoleView
