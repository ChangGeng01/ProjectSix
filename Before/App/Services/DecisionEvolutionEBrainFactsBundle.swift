import Foundation
import BASHostKit

extension String {
    var evolutionTrimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum DecisionLayerStackPresentationSupport {
    static func displayLines(for lines: [String]) -> [String] {
        lines.map { line in
            let segments = sanitizedSegments(in: line)

            guard let header = segments.first else {
                return line
            }

            return ([header] + segments.dropFirst()).joined(separator: " • ")
        }
    }

    static func displaySupplementaryText(_ line: String) -> String {
        sanitizedSegments(in: line).joined(separator: " • ")
    }

    static func title(for lines: [String]) -> String {
        guard let firstRange = layerRange(for: lines.first),
              let lastRange = layerRange(for: lines.last) else {
            return "Layer stack"
        }

        let start = firstRange.lowerBound
        let end = lastRange.upperBound
        if start == end {
            return "Layer \(start)"
        }

        return "Layers \(start)-\(end)"
    }

    private static func layerRange(for line: String?) -> ClosedRange<Int>? {
        guard let line else { return nil }
        let prefix = line.components(separatedBy: " • ").first ?? line
        let pattern = #"^L(\d+)(?:-L?(\d+))?"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(prefix.startIndex..<prefix.endIndex, in: prefix)
        guard let match = regex.firstMatch(in: prefix, options: [], range: nsRange),
              let startRange = Range(match.range(at: 1), in: prefix),
              let start = Int(prefix[startRange]) else {
            return nil
        }

        if let endRange = Range(match.range(at: 2), in: prefix),
           let end = Int(prefix[endRange]) {
            return start...end
        }

        return start...start
    }

    private static func sanitizedSegments(in line: String) -> [String] {
        line
            .components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(sanitizedSegment(_:))
    }

    private static func sanitizedSegment(_ segment: String) -> String {
        if segment.hasPrefix("fold ") {
            return "fold active"
        }
        if segment.hasPrefix("restore ") {
            return "restore ready"
        }
        if segment.hasPrefix("host ") {
            return "host aligned"
        }
        if segment.hasPrefix("session ") {
            return "state restored"
        }
        if segment.hasPrefix("Fold ") {
            return "Fold active"
        }
        if segment.hasPrefix("Replay session ") {
            return "Replay state restored"
        }
        return segment
    }
}

struct DecisionEvolutionEBrainFactsBundle: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let summaryLine: String
    let runtimeSummaryLine: String
    let brainSummaryLine: String
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let executionCapabilityLine: String?
    let horizonLine: String?
    let temporalLine: String?
    let evidenceLine: String?
    let worldPriorContract: DecisionEBrainWorldPriorContract?
    let temporalKnowledgeContract: DecisionEBrainTemporalKnowledgeContract?
    let evidenceContract: DecisionEBrainEvidenceContract?
    let persistenceLine: String?
    let persistenceContract: DecisionEBrainPersistenceContract?
    let budgetLine: String?
    let pressureLine: String?
    let taskLine: String?
    let auditLine: String?
    let sovereignVerdictLine: String?
    let sovereignAuthorityLine: String?
    let sovereignAuditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let morphLine: String?
    let hotColdLine: String?
    let precisionLine: String?
    let lungLine: String?
    let schedulerLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let layerStackLines: [String]
}

struct DecisionEvolutionReplayCheckpointFacts: Equatable, Sendable {
    let budgetLine: String
    let pressureLine: String
    let taskLine: String?
    let layerStackLines: [String]
}

struct DecisionEvolutionSessionCheckpointFacts: Equatable, Sendable {
    let budgetConstraintLine: String
    let routeConstraintLine: String
    let decisionFactLines: [String]
    let pressureFactLine: String?
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let auditFactLine: String?
    let activeKillSwitchesFactLine: String?
    let recommendedKillSwitchesFactLine: String?
    let openTaskLines: [String]
    let currentScope: [String]
    let shouldUseReviewMode: Bool
    let eBrainAnchor: DecisionSessionCheckpointEBrainAnchor
}

enum DecisionEvolutionEBrainPresentationSupport {
    static let checkpointBudgetPrefix = "eBrain budget:"
    static let checkpointRoutePrefix = "eBrain route:"
    static let checkpointPressurePrefix = "eBrain pressure:"
    static let checkpointAuditPrefix = "eBrain audit findings:"
    static let checkpointActiveKillSwitchesPrefix = "eBrain active kill switches:"
    static let checkpointRecommendedKillSwitchesPrefix = "eBrain recommended kill switches:"
    static let checkpointTaskPrefixes = [
        "Review update ticket:",
        "Review:",
        "Review protective path:",
        "Review memory write:",
        "Review host change:",
        "Review rule candidate:",
        "Review ticket before promotion."
    ]

    static let checkpointDecisionBasePrefixes = [
        "eBrain risk:",
        "eBrain permit:",
        "eBrain host gate:",
        "eBrain fold:"
    ]

    static let checkpointDecisionPrefixes = checkpointDecisionBasePrefixes + [
        checkpointAuditPrefix
    ]

    static func displayToken(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    static func taskTitle(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(
                of: "([a-z0-9])([A-Z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: "([A-Z])([A-Z][a-z])",
                with: "$1 $2",
                options: .regularExpression
            )
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func riskPermitLine(
        riskLevel: String,
        permitMode: String
    ) -> String {
        "\(displayToken(riskLevel)) → \(displayToken(permitMode))"
    }

    static func contextLayerStackLine(
        taskType: String,
        emotionalLoadPercent: Int,
        timePressurePercent: Int,
        relationPattern: String,
        ambiguityPercent: Int,
        consequencePercent: Int,
        manipulationHintCount: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L6 context",
            "task \(taskTitle(taskType))",
            "load \(emotionalLoadPercent)%",
            "time \(timePressurePercent)%",
            "relation \(relationPattern)",
            "ambiguity \(ambiguityPercent)%",
            "consequence \(consequencePercent)%",
            "manipulation \(manipulationHintCount)"
        ])
    }

    static func fallbackContextLayerStackLine(
        taskType: String,
        sessionID: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L6 context",
            "task \(taskTitle(taskType))",
            "session \(sessionID)"
        ])
    }

    static func cognitionLayerStackLine(
        factCount: Int,
        goalCount: Int,
        unknownCount: Int,
        contradictionCount: Int,
        memoryAtomCount: Int,
        candidateCount: Int,
        forecastCount: Int,
        critiqueCount: Int,
        stopReasonID: String?
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L7-L9 cognition",
            "facts \(factCount)",
            "goals \(goalCount)",
            "unknowns \(unknownCount)",
            "contradictions \(contradictionCount)",
            "memory \(memoryAtomCount)",
            "candidates \(candidateCount)/forecasts \(forecastCount)/critiques \(critiqueCount)",
            stopReasonID.map { "stop \($0)" }
        ].compactMap { $0 })
    }

    static func fallbackCognitionLayerStackLine() -> String {
        "L7-L9 cognition • recovered checkpoint lineage"
    }

    static func neuralProjectionSummary(
        leadCandidateID: String?,
        forecastCount: Int,
        critiqueCount: Int
    ) -> String? {
        guard leadCandidateID?.evolutionTrimmedNonEmpty != nil || forecastCount > 0 || critiqueCount > 0 else {
            return nil
        }

        return "projection \((leadCandidateID?.evolutionTrimmedNonEmpty) ?? "none")/\(forecastCount)/\(critiqueCount)"
    }

    static func adjudicationLayerStackLine(
        triScoreCount: Int,
        vetoCount: Int,
        riskLevel: String,
        permitMode: String,
        gsiPercent: Int,
        alternativeActionCount: Int,
        emergencyBrakeLine: String?
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L10-L12 adjudication",
            "tri \(triScoreCount) scored/\(vetoCount) veto",
            riskPermitLine(riskLevel: riskLevel, permitMode: permitMode),
            "GSI \(gsiPercent)%",
            "alternatives \(alternativeActionCount)",
            emergencyBrakeLine
        ].compactMap { $0 })
    }

    static func fallbackAdjudicationLayerStackLine(
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        emergencyBrakeLine: String?
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L10-L12 adjudication",
            riskPermitLine(riskLevel: riskLevel, permitMode: permitMode),
            "host gate \(hostGatePercent)%",
            emergencyBrakeLine
        ].compactMap { $0 })
    }

    static func hostFoldLine(
        hostGatePercent: Int,
        foldChecksum: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Host gate \(hostGatePercent)%",
            "Fold \(foldChecksum)"
        ])
    }

    static func riskPermitHostLine(
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            riskPermitLine(riskLevel: riskLevel, permitMode: permitMode),
            "host gate \(hostGatePercent)%"
        ])
    }

    static func riskPermitHostFoldLine(
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        foldChecksum: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            riskPermitHostLine(
                riskLevel: riskLevel,
                permitMode: permitMode,
                hostGatePercent: hostGatePercent
            ),
            "fold \(foldChecksum)"
        ])
    }

    static func sessionHostFoldLine(
        sessionID: String,
        hostGatePercent: Int,
        foldChecksum: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Session \(sessionID)",
            hostFoldLine(hostGatePercent: hostGatePercent, foldChecksum: foldChecksum)
        ])
    }

    static func runtimeSummaryLine(
        sourceDescriptor: DecisionEvolutionSourceDescriptor,
        modeTitle: String? = nil,
        permitMode: String,
        riskLevel: String,
        foldChecksum: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            sourceDescriptor.kind == .checkpointRecovery ? "Recovered from checkpoint" : "Live runtime",
            modeTitle,
            "permit \(permitMode)",
            "risk \(riskLevel)",
            "fold \(foldChecksum)"
        ].compactMap { $0 })
    }

    static func brainSummaryLine(
        sourceTitle: String,
        sessionID: String,
        hostGatePercent: Int,
        ticketCount: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            sourceTitle,
            "session \(sessionID)",
            "host gate \(hostGatePercent)%",
            "\(ticketCount) tickets"
        ])
    }

    static func recoveredLineageNarrative(
        riskLevel: String,
        permitMode: String
    ) -> String {
        "Recovered \(riskLevel) risk lineage via \(permitMode)."
    }

    static func checkpointCalibrationSummary(
        riskLevel: String,
        permitMode: String
    ) -> String {
        "Checkpoint recovery for \(riskLevel) risk via \(permitMode)."
    }

    static func recoveredCheckpointTitle(modeTitle: String) -> String {
        "Recovered \(modeTitle) checkpoint"
    }

    static func recoveredCheckpointLineageTitle(modeTitle: String) -> String {
        "Recovered \(modeTitle) lineage"
    }

    static func recoveredPersistedCheckpointSubtitle(taskType: String) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Recovered from persisted checkpoint",
            taskTitle(taskType)
        ])
    }

    static func recoveredCheckpointInputSummary(
        modeTitle: String,
        checkpointID: String
    ) -> String {
        "Recovered \(modeTitle.lowercased()) checkpoint \(checkpointID)"
    }

    static func recoveredCheckpointReason(
        modeTitle: String,
        approvalStateRawValue: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Recovered from \(modeTitle) checkpoint",
            approvalStateRawValue
        ]) + "."
    }

    static func checkpointDecisionFactLines(
        riskLevel: String,
        permitMode: String,
        hostGatePercent: Int,
        foldChecksum: String
    ) -> [String] {
        [
            "eBrain risk: \(riskLevel)",
            "eBrain permit: \(permitMode)",
            "eBrain host gate: \(hostGatePercent)%",
            "eBrain fold: \(foldChecksum)"
        ]
    }

    static func checkpointDecisionLine(from confirmedFacts: [String]) -> String? {
        let orderedFacts = checkpointDecisionPrefixes.compactMap { prefix in
            confirmedFacts.first(where: { $0.hasPrefix(prefix) })
        }

        guard orderedFacts.isEmpty == false else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.joined(orderedFacts)
    }

    static func checkpointBudgetConstraintLine(
        runMode: String,
        maxLoops: Int,
        maxCandidates: Int,
        maxDecodeTokens: Int,
        thermalGuardLevel: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.prefixedLine(
            prefix: checkpointBudgetPrefix,
            values: [
                runMode,
                "loops \(maxLoops)",
                "candidates \(maxCandidates)",
                "decode \(maxDecodeTokens)",
                "thermal \(thermalGuardLevel)"
            ]
        ) ?? checkpointBudgetPrefix
    }

    static func checkpointRouteConstraintLine(
        deviceRoute: String,
        precisionProfile: String,
        retrievalDepth: Int
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.prefixedLine(
            prefix: checkpointRoutePrefix,
            values: [
                deviceRoute,
                "precision \(precisionProfile)",
                "retrieval \(retrievalDepth)"
            ]
        ) ?? checkpointRoutePrefix
    }

    static func checkpointAuditFactLine(count: Int) -> String {
        "\(checkpointAuditPrefix) \(count)"
    }

    static func checkpointKillSwitchFactLine(
        prefix: String,
        values: [String]
    ) -> String? {
        DecisionEvolutionNarrativeFormattingSupport.prefixedLine(
            prefix: prefix,
            values: values
        )
    }

    static func checkpointOpenTaskLines(
        reviewDirectiveLine: String?,
        firstTicketSummary: String?,
        protectivePermitMode: String,
        isProtective: Bool
    ) -> [String] {
        var lines: [String] = []

        if let reviewDirectiveLine = reviewDirectiveLine?.evolutionTrimmedNonEmpty {
            lines.append(reviewDirectiveLine)
        } else if let firstTicketSummary = firstTicketSummary?.evolutionTrimmedNonEmpty {
            lines.append("Review update ticket: \(firstTicketSummary)")
        }

        if isProtective {
            lines.append("Review protective path: \(protectivePermitMode)")
        }

        return lines
    }

    static func firstLine(
        withPrefix prefix: String,
        in values: [String]
    ) -> String? {
        values.first(where: { $0.hasPrefix(prefix) })
    }

    static func firstLine(
        matching prefixes: [String],
        in values: [String]
    ) -> String? {
        prefixes.compactMap { prefix in
            firstLine(withPrefix: prefix, in: values)
        }.first
    }

    static func checkpointKillSwitchesLine(from confirmedFacts: [String]) -> String? {
        let line = DecisionEvolutionNarrativeFormattingSupport.joined([
            firstLine(withPrefix: checkpointActiveKillSwitchesPrefix, in: confirmedFacts),
            firstLine(withPrefix: checkpointRecommendedKillSwitchesPrefix, in: confirmedFacts)
        ].compactMap { $0 })

        return line.isEmpty ? nil : line
    }
}

struct DecisionEvolutionTurnDiagnosticsSupport: Equatable, Sendable {
    let routeText: String
    let hostText: String
    let replayText: String
    let auditLines: [String]
    let activeKillSwitchesLine: String?
    let recommendedKillSwitchesLine: String?
    let layerStackLines: [String]
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let ticketSummary: String?
}

extension DecisionEvolutionEBrainFactsBundle {
    func applying(
        executionCapabilityFrame: DecisionEBrainExecutionCapabilityFrame?
    ) -> DecisionEvolutionEBrainFactsBundle {
        DecisionEvolutionEBrainFactsBundle(
            sourceDescriptor: sourceDescriptor,
            summaryLine: summaryLine,
            runtimeSummaryLine: runtimeSummaryLine,
            brainSummaryLine: brainSummaryLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            executionCapabilityLine: executionCapabilityLine ?? executionCapabilityFrame?.detailLine,
            horizonLine: horizonLine ?? executionCapabilityFrame?.horizonLine,
            temporalLine: temporalLine ?? executionCapabilityFrame?.temporalLine,
            evidenceLine: evidenceLine ?? executionCapabilityFrame?.evidenceLine,
            worldPriorContract: worldPriorContract ?? executionCapabilityFrame?.worldPriorContract,
            temporalKnowledgeContract: temporalKnowledgeContract ?? executionCapabilityFrame?.temporalKnowledgeContract,
            evidenceContract: evidenceContract ?? executionCapabilityFrame?.evidenceContract,
            persistenceLine: persistenceLine ?? executionCapabilityFrame?.persistenceLine,
            persistenceContract: persistenceContract ?? executionCapabilityFrame?.persistenceContract,
            budgetLine: budgetLine,
            pressureLine: pressureLine,
            taskLine: taskLine,
            auditLine: auditLine,
            sovereignVerdictLine: sovereignVerdictLine,
            sovereignAuthorityLine: sovereignAuthorityLine,
            sovereignAuditLine: sovereignAuditLine,
            activeKillSwitchesLine: activeKillSwitchesLine,
            killSwitchesLine: killSwitchesLine,
            morphLine: morphLine,
            hotColdLine: hotColdLine,
            precisionLine: precisionLine,
            lungLine: lungLine,
            schedulerLine: schedulerLine,
            resumeLine: resumeLine,
            rollbackLine: rollbackLine,
            sovereignBridgeLine: sovereignBridgeLine,
            layerStackLines: layerStackLines
        )
    }

    func sessionCheckpointPressureFactLine(prefix: String = "eBrain pressure:") -> String? {
        guard let pressureLine else { return nil }
        return "\(prefix) \(pressureLine.droppingKnownPrefix("Pressure "))"
    }

    var consoleRuntimeSummaryAdditions: [String] {
        [
            runtimeSummaryLine,
            riskFactorsLine,
            reasonCodesLine,
            executionCapabilityLine,
            horizonLine,
            temporalLine,
            evidenceLine,
            persistenceLine,
            pressureLine
        ]
            .compactMap { $0 }
    }

    var consoleBrainSummaryAddition: String {
        brainSummaryLine
    }

    var dataLayerSignals: [String] {
        [
            summaryLine,
            budgetLine,
            pressureLine,
            taskLine,
            riskFactorsLine,
            reasonCodesLine,
            executionCapabilityLine,
            horizonLine,
            temporalLine,
            evidenceLine,
            persistenceLine,
            auditLine,
            activeKillSwitchesLine,
            killSwitchesLine,
            lungLine,
            morphLine,
            hotColdLine,
            precisionLine,
            resumeLine,
            schedulerLine,
            rollbackLine,
            sovereignBridgeLine
        ]
        .compactMap { $0 }
    }
}

extension BASEBrainTurnResult {
    var replayCheckpointBudgetLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Budget \(readableReplayRunModeTitle(budgetFrame.runMode))",
            "route \(runtimeTrace.modelRoute)",
            "loops \(budgetFrame.maxLoops)",
            "candidates \(budgetFrame.maxCandidates)",
            "decode \(budgetFrame.maxDecodeTokens)",
            budgetFrame.leaseID.map { _ in "lease active" },
            budgetFrame.maintenanceClass == .none ? nil : "maintenance \(budgetFrame.maintenanceClass.rawValue)"
        ].compactMap { $0 })
    }

    var replayCheckpointPressureLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Pressure latency \(runtimeTrace.latencyBreakdownMs.values.reduce(0, +))/\(deviceState.latencyBudgetMs)ms",
            "power \(Int((runtimeTrace.powerEstimate * 100).rounded()))%",
            "cache \(Int((runtimeTrace.cacheHitRate * 100).rounded()))%",
            "thermal \((runtimeTrace.thermalTrace.isEmpty ? [deviceState.thermalLevel.rawValue] : runtimeTrace.thermalTrace).joined(separator: " -> "))",
            "vital \(Int((vitalState.stabilityScore * 100).rounded()))%",
            emergencyBrake.brakeLevel == .none ? nil : "brake \(emergencyBrake.brakeLevel.rawValue)"
        ].compactMap { $0 })
    }

    var replayCheckpointTaskLine: String? {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            primaryReviewDirectiveLine,
            wakeIntentLine,
            sovereignActuationLine
        ].compactMap { $0 }).evolutionTrimmedNonEmpty
            ?? updateTickets.first?.summary.evolutionTrimmedNonEmpty.map { "Review: \($0)" }
    }

    var primaryReviewDirectiveLine: String? {
        updateTickets.lazy.compactMap(\.reviewDirectiveLine).compactMap(\.evolutionTrimmedNonEmpty).first
    }

    var turnDiagnosticsSupport: DecisionEvolutionTurnDiagnosticsSupport {
        let activeKillSwitches = runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKillSwitches = runtimeTrace.recommendedKillSwitches.map(\.rawValue)

        return DecisionEvolutionTurnDiagnosticsSupport(
            routeText: DecisionEvolutionNarrativeFormattingSupport.joined([
                "Route: \(runtimeTrace.modelRoute)",
                "Loops: \(runtimeTrace.loopCount)",
                "Power: \(Int((runtimeTrace.powerEstimate * 100).rounded()))%"
            ]),
            hostText: DecisionLayerStackPresentationSupport.displaySupplementaryText(
                DecisionEvolutionNarrativeFormattingSupport.joined([
                    "Host gate \(Int((hostGateValue * 100).rounded()))%",
                    "Fold \(thoughtFold.checksum.prefix(12))",
                    "Device \(deviceState.thermalLevel.rawValue)/\(deviceState.memoryFreeMB)MB",
                    wakeIntentLine,
                    emergencyBrakeLine
                ].compactMap { $0 })
            ),
            replayText: DecisionLayerStackPresentationSupport.displaySupplementaryText(
                DecisionEvolutionNarrativeFormattingSupport.joined([
                    "Replay session \(runtimeTrace.sessionID)",
                    "Recorded \(runtimeTrace.recordedAt.formatted(date: .abbreviated, time: .shortened))",
                    runLeaseLine,
                    sovereignActuationLine
                ].compactMap { $0 })
            ),
            auditLines: Array(runtimeTrace.guardrailFindings.prefix(4)).map { finding in
                "• \(finding.layerID) \(finding.code): \(finding.summary)"
            },
            activeKillSwitchesLine: DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: activeKillSwitches
            ),
            recommendedKillSwitchesLine: DecisionEvolutionKillSwitchPresentationSupport.recommendedLine(
                killSwitches: recommendedKillSwitches
            ),
            layerStackLines: layerStackLines,
            riskFactorsLine: DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Factors",
                values: riskCard.factors
            ),
            reasonCodesLine: DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Reason codes",
                values: renderedOutput.explanationCodes
            ),
            ticketSummary: primaryReviewDirectiveLine ?? updateTickets.first?.summary.evolutionTrimmedNonEmpty
        )
    }

    var layerStackLines: [String] {
        DecisionLayerStackPresentationSupport.displayLines(
            for: [
            powerClockLayerStackLine,
            neuralCoreLayerStackLine,
            compressionRuntimeLayerStackLine,
            foundationLayerStackLine,
            hostProfileLayerStackLine,
            contextLayerStackLine,
            cognitionLayerStackLine,
            adjudicationLayerStackLine,
            evolutionLayerStackLine,
            sovereignLayerStackLine
        ]
        .compactMap { $0?.evolutionTrimmedNonEmpty }
        )
    }

    private var powerClockLayerStackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L1 power clock",
            "mode \(readableReplayRunModeTitle(budgetFrame.runMode))",
            wakeIntentLine,
            "route \(runtimeTrace.modelRoute)",
            "loops \(budgetFrame.maxLoops)",
            "candidates \(budgetFrame.maxCandidates)",
            "decode \(budgetFrame.maxDecodeTokens)",
            runLeaseLine,
            budgetFrame.maintenanceClass == .none ? nil : "maintenance \(budgetFrame.maintenanceClass.rawValue)"
        ].compactMap { $0 })
    }

    private var neuralCoreLayerStackLine: String {
        let organMap = thoughtFrame.organMap
        let activeOrgans = organMap?.activeOrgans.map(\.rawValue) ?? []
        let organSummary = activeOrgans.isEmpty
            ? "none"
            : Array(activeOrgans.prefix(4)).joined(separator: ", ")
        let headGuarantees = organMap?.headGuarantees ?? []
        let headSummary = headGuarantees.isEmpty
            ? "none"
            : Array(headGuarantees.prefix(3)).joined(separator: ", ")
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "L2 neural core",
            "morph \(organMap?.morph.rawValue ?? "none")",
            "organs \(organSummary)",
            "heads \(headSummary)",
            thoughtFrame.candidateFrontier.map { "frontier \($0.frontierWidth)" },
            thoughtFrame.riskBindings.map { "bindings \($0.count)" },
            DecisionEvolutionEBrainPresentationSupport.neuralProjectionSummary(
                leadCandidateID: thoughtFrame.candidates.first?.candidateID,
                forecastCount: thoughtFrame.forecasts.count,
                critiqueCount: thoughtFrame.critiques.count
            ),
            thoughtFrame.neuralLeaseReceipt?.degraded == true ? "stub ready" : nil,
            "route \(runtimeTrace.modelRoute)",
            "battery \(Int((deviceState.batteryLevel * 100).rounded()))%",
            "thermal \(deviceState.thermalLevel.rawValue)",
            "cpu \(Int((deviceState.cpuLoad * 100).rounded()))%",
            deviceState.npuAvailable ? "npu on" : "npu off"
        ].compactMap { $0 })
    }

    private var compressionRuntimeLayerStackLine: String {
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "L3 compression runtime",
            "fold \(String(thoughtFold.checksum.prefix(12)))",
            "slots \(thoughtFold.compactSlots.count)",
            "restore \(thoughtFold.restorePointer)"
        ])
    }

    private var foundationLayerStackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L4 foundation",
            "task \(DecisionEvolutionEBrainPresentationSupport.taskTitle(contextFrame.taskType.rawValue))",
            "goals \(decomposeFrame.goals.count)",
            "pressure \(decomposeFrame.pressureSignals.count)",
            "ambiguity \(Int((contextFrame.ambiguityScore * 100).rounded()))%"
        ])
    }

    private var hostProfileLayerStackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L5 host profile",
            "host \(hostContext.hostID)",
            "goals \(hostContext.longTermGoals.count)",
            "no-go \(hostContext.noGoZones.count)",
            "gate \(Int((hostGateValue * 100).rounded()))%"
        ])
    }

    private var contextLayerStackLine: String {
        DecisionEvolutionEBrainPresentationSupport.contextLayerStackLine(
            taskType: contextFrame.taskType.rawValue,
            emotionalLoadPercent: Int((contextFrame.emotionalLoad * 100).rounded()),
            timePressurePercent: Int((contextFrame.timePressure * 100).rounded()),
            relationPattern: contextFrame.relationPattern,
            ambiguityPercent: Int((contextFrame.ambiguityScore * 100).rounded()),
            consequencePercent: Int((contextFrame.consequenceLevel * 100).rounded()),
            manipulationHintCount: contextFrame.manipulationHints.count
        )
    }

    private var cognitionLayerStackLine: String {
        DecisionEvolutionEBrainPresentationSupport.cognitionLayerStackLine(
            factCount: decomposeFrame.facts.count,
            goalCount: decomposeFrame.goals.count,
            unknownCount: decomposeFrame.unknowns.count,
            contradictionCount: decomposeFrame.contradictions.count,
            memoryAtomCount: memoryBundle.atoms.count,
            candidateCount: thoughtFrame.candidates.count,
            forecastCount: thoughtFrame.forecasts.count,
            critiqueCount: thoughtFrame.critiques.count,
            stopReasonID: thoughtFrame.stopReason?.rawValue
        )
    }

    private var adjudicationLayerStackLine: String {
        DecisionEvolutionEBrainPresentationSupport.adjudicationLayerStackLine(
            triScoreCount: triScores.count,
            vetoCount: triScores.filter(\.veto).count,
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            gsiPercent: Int((riskCard.gsiScore * 100).rounded()),
            alternativeActionCount: renderedOutput.alternativeActions.count,
            emergencyBrakeLine: emergencyBrakeLine
        )
    }

    private var evolutionLayerStackLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L13 evolution",
            "\(updateTickets.count) tickets",
            primaryReviewDirectiveLine ?? updateTickets.first?.summary.evolutionTrimmedNonEmpty
        ].compactMap { $0 })
    }

    private var sovereignLayerStackLine: String? {
        let constraints = thoughtFrame.organMap?.sovereignConstraints ?? []
        let verdictDetail = sovereignVerdict.map { "verdict \($0.verdictLevel.rawValue)" }
        let tokenScopes = sovereignCommitTokens.map(\.scope.rawValue)
        let lockDetail = sovereignLock.map { "lock \($0.scope.rawValue)" }
        let quarantineZones = quarantineRecords.map(\.zone.rawValue)
        let auditDetail = sovereignAuditEntry.map {
            "audit \($0.ruleIDs.first ?? $0.auditID)"
        }
        let commandKinds = sovereignActuationCommands.map(\.kind.rawValue)
        let receiptKinds = sovereignExecutionReceipts.map {
            "\($0.kind.rawValue) \($0.latencyMs)ms"
        }
        let activeKills = runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKills = runtimeTrace.recommendedKillSwitches.map(\.rawValue)

        let details = [
            constraints.isEmpty ? nil : "constraints \(Array(constraints.prefix(3)).joined(separator: ", "))",
            verdictDetail,
            tokenScopes.isEmpty ? nil : "tokens \(Array(tokenScopes.prefix(3)).joined(separator: ", "))",
            lockDetail,
            quarantineZones.isEmpty ? nil : "quarantine \(Array(quarantineZones.prefix(2)).joined(separator: ", "))",
            auditDetail,
            commandKinds.isEmpty ? nil : "commands \(Array(commandKinds.prefix(3)).joined(separator: ", "))",
            receiptKinds.isEmpty ? nil : "executed \(Array(receiptKinds.prefix(2)).joined(separator: ", "))",
            activeKills.isEmpty ? nil : "active \(Array(activeKills.prefix(3)).joined(separator: ", "))",
            recommendedKills.isEmpty ? nil : "recommended \(Array(recommendedKills.prefix(3)).joined(separator: ", "))"
        ]
        .compactMap { $0 }

        guard details.isEmpty == false else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            ["L14 sovereign"] + details
        )
    }

    private var wakeIntentLine: String? {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "wake \(wakeIntent.intentLevel.rawValue)",
            "value \(Int((wakeIntent.estimatedValue * 100).rounded()))%",
            "risk \(Int((wakeIntent.estimatedRisk * 100).rounded()))%"
        ]).evolutionTrimmedNonEmpty
    }

    private var runLeaseLine: String? {
        guard let runLease else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "lease \(runLease.allowedMode.displayTitle.lowercased())",
            "loops \(runLease.maxLoops)",
            "heads \(runLease.validHeads.count)"
        ]).evolutionTrimmedNonEmpty
    }

    private var emergencyBrakeLine: String? {
        guard emergencyBrake.brakeLevel != .none else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "brake \(emergencyBrake.brakeLevel.rawValue)",
            emergencyBrake.forcedMode.map { "force \($0.displayTitle.lowercased())" }
        ].compactMap { $0 }).evolutionTrimmedNonEmpty
    }

    private var sovereignActuationLine: String? {
        guard sovereignActuationCommands.isEmpty == false else { return nil }
        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "sovereign",
            sovereignActuationCommands.map(\.kind.rawValue).joined(separator: ", ")
        ]).evolutionTrimmedNonEmpty
    }

    var replayCheckpointFacts: DecisionEvolutionReplayCheckpointFacts {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()
        return DecisionEvolutionReplayCheckpointFacts(
            budgetLine: replayCheckpointBudgetLine,
            pressureLine: factsBundle.pressureLine ?? replayCheckpointPressureLine,
            taskLine: replayCheckpointTaskLine,
            layerStackLines: factsBundle.layerStackLines
        )
    }

    var sessionCheckpointFacts: DecisionEvolutionSessionCheckpointFacts {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: self)
        let activeKillSwitches = runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKillSwitches = runtimeTrace.recommendedKillSwitches.map(\.rawValue)
        let openTaskLines = DecisionEvolutionEBrainPresentationSupport.checkpointOpenTaskLines(
            reviewDirectiveLine: primaryReviewDirectiveLine,
            firstTicketSummary: updateTickets.first?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            protectivePermitMode: actionPermit.mode.rawValue,
            isProtective: actionPermit.mode.isProtective
        )

        return DecisionEvolutionSessionCheckpointFacts(
            budgetConstraintLine: DecisionEvolutionEBrainPresentationSupport.checkpointBudgetConstraintLine(
                runMode: budgetFrame.runMode.displayTitle,
                maxLoops: budgetFrame.maxLoops,
                maxCandidates: budgetFrame.maxCandidates,
                maxDecodeTokens: budgetFrame.maxDecodeTokens,
                thermalGuardLevel: budgetFrame.thermalGuardLevel.rawValue
            ),
            routeConstraintLine: DecisionEvolutionEBrainPresentationSupport.checkpointRouteConstraintLine(
                deviceRoute: budgetFrame.deviceRoute.rawValue,
                precisionProfile: budgetFrame.precisionProfile.rawValue,
                retrievalDepth: budgetFrame.retrievalDepth
            ),
            decisionFactLines: DecisionEvolutionEBrainPresentationSupport.checkpointDecisionFactLines(
                riskLevel: riskCard.riskLevel.rawValue,
                permitMode: actionPermit.mode.rawValue,
                hostGatePercent: Int((hostGateValue * 100).rounded()),
                foldChecksum: String(thoughtFold.checksum.prefix(12))
            ),
            pressureFactLine: factsBundle.sessionCheckpointPressureFactLine(),
            riskFactorsLine: factsBundle.riskFactorsLine,
            reasonCodesLine: factsBundle.reasonCodesLine,
            auditFactLine: runtimeTrace.guardrailFindings.isEmpty
                ? nil
                : DecisionEvolutionEBrainPresentationSupport.checkpointAuditFactLine(
                    count: runtimeTrace.guardrailFindings.count
                ),
            activeKillSwitchesFactLine: DecisionEvolutionEBrainPresentationSupport.checkpointKillSwitchFactLine(
                prefix: DecisionEvolutionEBrainPresentationSupport.checkpointActiveKillSwitchesPrefix,
                values: activeKillSwitches
            ),
            recommendedKillSwitchesFactLine: DecisionEvolutionEBrainPresentationSupport.checkpointKillSwitchFactLine(
                prefix: DecisionEvolutionEBrainPresentationSupport.checkpointRecommendedKillSwitchesPrefix,
                values: recommendedKillSwitches
            ),
            openTaskLines: openTaskLines,
            currentScope: [
                "ebrain",
                contextFrame.taskType.rawValue,
                "run:\(budgetFrame.runMode.rawValue)"
            ],
            shouldUseReviewMode: actionPermit.mode.isProtective,
            eBrainAnchor: DecisionSessionCheckpointEBrainAnchor(
                sessionID: runtimeTrace.sessionID,
                thoughtFoldChecksum: String(thoughtFold.checksum.prefix(12)),
                riskLevel: riskCard.riskLevel.rawValue,
                permitMode: actionPermit.mode.rawValue,
                hostGatePercent: Int((hostGateValue * 100).rounded()),
                reviewDirectiveLine: primaryReviewDirectiveLine,
                riskFactorsLine: factsBundle.riskFactorsLine,
                reasonCodesLine: factsBundle.reasonCodesLine,
                sovereignVerdictLine: factsBundle.sovereignVerdictLine,
                sovereignAuthorityLine: factsBundle.sovereignAuthorityLine,
                sovereignAuditLine: factsBundle.sovereignAuditLine,
                lungState: foldedLung.lungState,
                breathScheduler: foldedLung.breathScheduler,
                resumeFrame: foldedLung.resumeFrame,
                rollbackAnchor: foldedLung.rollbackAnchor,
                sovereignBridgeResult: foldedLung.sovereignBridgeResult
            )
        )
    }

    private func readableReplayRunModeTitle(_ runMode: BASEBrainRunMode) -> String {
        switch runMode {
        case .deepLoop:
            return "DEEP LOOP"
        default:
            return runMode.displayTitle.uppercased()
        }
    }
}

extension DecisionEvolutionSessionCheckpointFacts {
    func applied(
        to draft: DecisionSessionCheckpointDraft,
        executionCapability: DecisionSessionCheckpointExecutionCapability? = nil
    ) -> DecisionSessionCheckpointDraft {
        var summary = draft.summary
        var runtimeState = draft.runtimeState

        appendUnique(budgetConstraintLine, to: &summary.acceptedConstraints)
        appendUnique(routeConstraintLine, to: &summary.acceptedConstraints)
        decisionFactLines.forEach {
            appendUnique($0, to: &summary.confirmedFacts)
        }
        if let pressureFactLine {
            appendUnique(pressureFactLine, to: &summary.confirmedFacts)
        }
        if let auditFactLine {
            appendUnique(auditFactLine, to: &summary.confirmedFacts)
        }
        if let activeKillSwitchesFactLine {
            appendUnique(activeKillSwitchesFactLine, to: &summary.confirmedFacts)
        }
        if let recommendedKillSwitchesFactLine {
            appendUnique(recommendedKillSwitchesFactLine, to: &summary.confirmedFacts)
        }
        openTaskLines.forEach {
            appendUnique($0, to: &summary.openTasks)
        }

        let resolvedAnchor = executionCapability.map {
            eBrainAnchor.merged(
                with: DecisionSessionCheckpointEBrainAnchor(executionCapability: $0)
            )
        } ?? eBrainAnchor

        runtimeState.eBrainAnchor = runtimeState.eBrainAnchor
            .map { $0.merged(with: resolvedAnchor) }
            ?? resolvedAnchor

        if shouldUseReviewMode {
            runtimeState.currentMode = .review
        }

        currentScope.forEach {
            appendUnique($0, to: &summary.currentScope)
        }

        return DecisionSessionCheckpointDraft(
            summary: summary,
            runtimeState: runtimeState
        )
    }

    private func appendUnique(_ value: String, to values: inout [String]) {
        guard !values.contains(value) else {
            return
        }
        values.append(value)
    }
}

extension DeveloperDecisionReplayEBrainSummary {
    func factsBundle(modeTitle: String? = nil) -> DecisionEvolutionEBrainFactsBundle {
        let replaySummary = replayRecoverySummary
        let runtimeSummaryLine = DecisionEvolutionEBrainPresentationSupport.runtimeSummaryLine(
            sourceDescriptor: sourceDescriptor,
            modeTitle: modeTitle,
            permitMode: permitMode,
            riskLevel: riskLevel,
            foldChecksum: thoughtFoldChecksum
        )
        let brainSummaryLine = DecisionEvolutionEBrainPresentationSupport.brainSummaryLine(
            sourceTitle: sourceDescriptor.title,
            sessionID: sessionID,
            hostGatePercent: hostGatePercent,
            ticketCount: updateTicketSummaries.count
        )

        return DecisionEvolutionEBrainFactsBundle(
            sourceDescriptor: sourceDescriptor,
            summaryLine: replaySummary.headlineLine,
            runtimeSummaryLine: runtimeSummaryLine,
            brainSummaryLine: brainSummaryLine,
            riskFactorsLine: riskFactorsLine,
            reasonCodesLine: reasonCodesLine,
            executionCapabilityLine: executionCapabilityLine,
            horizonLine: horizonLine,
            temporalLine: temporalLine,
            evidenceLine: evidenceLine,
            worldPriorContract: worldPriorContract,
            temporalKnowledgeContract: temporalKnowledgeContract,
            evidenceContract: evidenceContract,
            persistenceLine: persistenceLine,
            persistenceContract: persistenceContract,
            budgetLine: replaySummary.budgetLine,
            pressureLine: replaySummary.pressureLine,
            taskLine: replaySummary.taskLine,
            auditLine: replaySummary.auditLine,
            sovereignVerdictLine: replaySummary.sovereignVerdictLine,
            sovereignAuthorityLine: replaySummary.sovereignAuthorityLine,
            sovereignAuditLine: replaySummary.sovereignAuditLine,
            activeKillSwitchesLine: replaySummary.activeKillSwitchesLine,
            killSwitchesLine: replaySummary.killSwitchesLine,
            morphLine: replaySummary.morphLine,
            hotColdLine: replaySummary.hotColdLine,
            precisionLine: replaySummary.precisionLine,
            lungLine: replaySummary.lungLine,
            schedulerLine: replaySummary.schedulerLine,
            resumeLine: replaySummary.resumeLine,
            rollbackLine: replaySummary.rollbackLine,
            sovereignBridgeLine: replaySummary.sovereignBridgeLine,
            layerStackLines: layerStackLines
        )
    }
}

extension DecisionEvolutionLineageSnapshot {
    var factsBundle: DecisionEvolutionEBrainFactsBundle {
        eBrain.factsBundle(modeTitle: mode.shortTitle)
    }
}

private extension String {
    func droppingKnownPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}
