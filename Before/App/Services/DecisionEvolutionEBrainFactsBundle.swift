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
    let courtLine: String?
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
    let governanceLine: String?
    let versionTreeLine: String?
    let retractionLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
    let morphLine: String?
    let hotColdLine: String?
    let precisionLine: String?
    let organPackageLine: String?
    let lungLine: String?
    let organDeltaLine: String?
    let thermalExchangeLine: String?
    let schedulerLine: String?
    let integrityWeaveLine: String?
    let resumeLine: String?
    let rollbackLine: String?
    let sovereignBridgeLine: String?
    let layerStackLines: [String]

    var windGateLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L11 wind gate") })
    }
}

struct DecisionEvolutionReplayCheckpointFacts: Equatable, Sendable {
    let budgetLine: String
    let pressureLine: String
    let taskLine: String?
    let windGateLine: String?
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

    static func furnaceContributionLines(
        layerStackLines: [String],
        temporalLine: String? = nil,
        governanceLine: String? = nil,
        versionTreeLine: String? = nil,
        retractionLine: String? = nil,
        sovereignBridgeLine: String? = nil
    ) -> [String] {
        orderedUniqueNonEmpty([
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L8 temporal field"]
            ) ?? temporalLine,
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L7-L9 cognition"]
            ),
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L9 dream loop"]
            ),
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L10-L12 adjudication"]
            ),
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L11 wind gate"]
            ),
            governanceLine,
            versionTreeLine,
            retractionLine,
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L14 sovereign"]
            ),
            sovereignBridgeLine
        ])
    }

    static func foldedLungLines(
        layerStackLines: [String],
        lungLine: String? = nil,
        morphLine: String? = nil,
        hotColdLine: String? = nil,
        precisionLine: String? = nil,
        organPackageLine: String? = nil,
        organDeltaLine: String? = nil,
        schedulerLine: String? = nil,
        thermalExchangeLine: String? = nil,
        integrityWeaveLine: String? = nil,
        resumeLine: String? = nil,
        rollbackLine: String? = nil
    ) -> [String] {
        orderedUniqueNonEmpty([
            firstLayerStackLine(
                in: layerStackLines,
                prefixes: ["L3 compression runtime"]
            ),
            lungLine,
            morphLine,
            hotColdLine,
            precisionLine,
            organPackageLine,
            organDeltaLine,
            schedulerLine,
            thermalExchangeLine,
            integrityWeaveLine,
            resumeLine,
            rollbackLine
        ])
    }

    static func orderedUniqueNonEmpty(
        _ values: [String?]
    ) -> [String] {
        values.reduce(into: [String]()) { uniqueValues, value in
            guard let trimmedValue = value?.evolutionTrimmedNonEmpty,
                  !uniqueValues.contains(trimmedValue) else {
                return
            }
            uniqueValues.append(trimmedValue)
        }
    }

    private static func firstLayerStackLine(
        in layerStackLines: [String],
        prefixes: [String]
    ) -> String? {
        layerStackLines.first { line in
            prefixes.contains { prefix in
                line.hasPrefix(prefix)
            }
        }
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

    static func contextPresenceLayerStackLine(
        sceneType: String?,
        roleRelationClass: String?,
        powerDirection: String?,
        powerStrengthPercent: Int?,
        urgencyPercent: Int?,
        routeMode: String?,
        guardRequired: Bool?,
        continuityArc: String?
    ) -> String? {
        let segments = [
            sceneType?.evolutionTrimmedNonEmpty.map { "scene \(taskTitle($0))" },
            roleRelationClass?.evolutionTrimmedNonEmpty.map { "role \($0)" },
            formattedPowerSegment(
                direction: powerDirection,
                strengthPercent: powerStrengthPercent
            ),
            urgencyPercent.map { "urgency \($0)%" },
            routeMode?.evolutionTrimmedNonEmpty.map { "route \($0)" },
            guardRequired == true ? "guard on" : nil,
            continuityArc?.evolutionTrimmedNonEmpty.map { "continuity \($0)" }
        ]
        .compactMap { $0 }

        guard segments.isEmpty == false else {
            return nil
        }

        return DecisionEvolutionNarrativeFormattingSupport.joined(
            ["L6 presence"] + segments
        )
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

    static func fallbackContextPresenceLayerStackLine(
        taskType: String
    ) -> String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "L6 presence",
            "scene \(fallbackSceneTitle(taskType: taskType))"
        ])
    }

    private static func fallbackSceneTitle(taskType: String) -> String {
        let normalizedTaskType = taskType
            .replacingOccurrences(of: "_", with: "")
            .lowercased()

        switch normalizedTaskType {
        case "highpressure", "highpressureconflict":
            return "high pressure conflict"
        case "highconsequence", "highconsequencedecision":
            return "high consequence decision"
        default:
            return taskTitle(taskType)
        }
    }

    private static func formattedPowerSegment(
        direction: String?,
        strengthPercent: Int?
    ) -> String? {
        let directionText = direction?
            .replacingOccurrences(of: "_", with: " ")
            .evolutionTrimmedNonEmpty

        switch (directionText, strengthPercent) {
        case let (.some(directionText), .some(strengthPercent)):
            return "power \(directionText) \(strengthPercent)%"
        case let (.some(directionText), nil):
            return "power \(directionText)"
        case let (nil, .some(strengthPercent)):
            return "power \(strengthPercent)%"
        default:
            return nil
        }
    }

    static func cognitionLayerStackLine(
        factCount: Int,
        goalCount: Int,
        claimCount: Int? = nil,
        unknownCount: Int,
        contradictionCount: Int,
        pressureSummary: String? = nil,
        manipulationSummary: String? = nil,
        boundarySummary: String? = nil,
        mirrorModeID: String? = nil,
        routeHint: String? = nil,
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
            claimCount.map { "claims \($0)" },
            "unknowns \(unknownCount)",
            "contradictions \(contradictionCount)",
            pressureSummary?.evolutionTrimmedNonEmpty.map { "pressures \(taskTitle($0))" },
            manipulationSummary?.evolutionTrimmedNonEmpty.map { "manipulation \(taskTitle($0))" },
            boundarySummary?.evolutionTrimmedNonEmpty.map { "boundaries \(taskTitle($0))" },
            mirrorModeID?.evolutionTrimmedNonEmpty.map { "mirror \(taskTitle($0))" },
            routeHint?.evolutionTrimmedNonEmpty.map { "route \(taskTitle($0))" },
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
            courtLine: courtLine,
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
            governanceLine: governanceLine,
            versionTreeLine: versionTreeLine,
            retractionLine: retractionLine,
            activeKillSwitchesLine: activeKillSwitchesLine,
            killSwitchesLine: killSwitchesLine,
            morphLine: morphLine,
            hotColdLine: hotColdLine,
            precisionLine: precisionLine,
            organPackageLine: organPackageLine,
            lungLine: lungLine,
            organDeltaLine: organDeltaLine,
            thermalExchangeLine: thermalExchangeLine,
            schedulerLine: schedulerLine,
            integrityWeaveLine: integrityWeaveLine,
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

    func displayPresenceLine(prefix: String = "Presence") -> String? {
        guard let presencePayload = layerStackPresencePayload else {
            return nil
        }
        return "\(prefix) \(presencePayload)"
    }

    func sessionCheckpointPresenceFactLine(prefix: String = "eBrain presence:") -> String? {
        guard let presencePayload = layerStackPresencePayload else {
            return nil
        }
        return "\(prefix) \(presencePayload)"
    }

    var consoleRuntimeSummaryAdditions: [String] {
        DecisionEvolutionEBrainPresentationSupport.orderedUniqueNonEmpty(
            [
            runtimeSummaryLine,
            riskFactorsLine,
            reasonCodesLine,
            courtLine,
            executionCapabilityLine,
            horizonLine,
            temporalLine,
            evidenceLine,
            persistenceLine,
            pressureLine,
            governanceLine,
            versionTreeLine,
            retractionLine
        ] + furnaceContributionLines.map(Optional.some))
    }

    var consoleBrainSummaryAddition: String {
        brainSummaryLine
    }

    var dataLayerSignals: [String] {
        DecisionEvolutionEBrainPresentationSupport.orderedUniqueNonEmpty(
            [
            summaryLine,
            budgetLine,
            displayPresenceLine(),
            pressureLine,
            taskLine,
            governanceLine,
            versionTreeLine,
            retractionLine,
            riskFactorsLine,
            reasonCodesLine,
            courtLine,
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
            organPackageLine,
            organDeltaLine,
            resumeLine,
            thermalExchangeLine,
            schedulerLine,
            rollbackLine,
            integrityWeaveLine,
            sovereignBridgeLine
        ] + furnaceContributionLines.map(Optional.some))
    }

    var furnaceContributionLines: [String] {
        DecisionEvolutionEBrainPresentationSupport.furnaceContributionLines(
            layerStackLines: layerStackLines,
            temporalLine: temporalLine,
            governanceLine: governanceLine,
            versionTreeLine: versionTreeLine,
            retractionLine: retractionLine,
            sovereignBridgeLine: sovereignBridgeLine
        )
    }

    private var layerStackPresencePayload: String? {
        layerStackLines
            .first(where: { $0.hasPrefix("L6 presence") })?
            .droppingKnownPrefix("L6 presence • ")
            .evolutionTrimmedNonEmpty
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

    var replayCheckpointWindGateLine: String? {
        layerStackLines.first(where: { $0.hasPrefix("L11 wind gate") })
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
            contextPresenceLayerStackLine,
            cognitionLayerStackLine,
            adjudicationLayerStackLine,
            riskClimateLayerStackLine,
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

    private var contextPresenceLayerStackLine: String? {
        DecisionEvolutionEBrainPresentationSupport.contextPresenceLayerStackLine(
            sceneType: contextFrame.sceneType.rawValue,
            roleRelationClass: contextFrame.roleGeometry?.relationClass,
            powerDirection: contextFrame.powerGradient?.direction,
            powerStrengthPercent: contextFrame.powerGradient.map { Int(($0.strength * 100).rounded()) },
            urgencyPercent: contextFrame.urgencyTruth.map { Int(($0.statedUrgency * 100).rounded()) },
            routeMode: contextFrame.routeHint?.preferredMode,
            guardRequired: contextFrame.routeHint?.needGuard,
            continuityArc: contextFrame.continuityAnchor?.sceneArc
        )
    }

    private var cognitionLayerStackLine: String {
        DecisionEvolutionEBrainPresentationSupport.cognitionLayerStackLine(
            factCount: decomposeFrame.facts.count,
            goalCount: decomposeFrame.goals.count,
            claimCount: decomposeFrame.claimShards.isEmpty ? nil : decomposeFrame.claimShards.count,
            unknownCount: decomposeFrame.unknowns.count,
            contradictionCount: decomposeFrame.contradictions.count,
            pressureSummary: decomposeFrame.pressureVectors.isEmpty
                ? nil
                : decomposeFrame.pressureVectors.map { $0.kind.rawValue }.joined(separator: ", "),
            manipulationSummary: decomposeFrame.manipulationPatterns.isEmpty
                ? nil
                : decomposeFrame.manipulationPatterns.map { $0.kind.rawValue }.joined(separator: ", "),
            boundarySummary: decomposeFrame.boundaryTouches.isEmpty
                ? nil
                : decomposeFrame.boundaryTouches.map { "\($0.domain.rawValue):\($0.level.rawValue)" }.joined(separator: ", "),
            mirrorModeID: decomposeFrame.mirrorDraft?.mode.rawValue,
            routeHint: decomposeFrame.canonicalFrame?.routeHint,
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

    private var riskClimateLayerStackLine: String? {
        let decisionPackage = riskDecisionPackage
        let surfaceGuide = renderedOutput.surfaceGuide
        let stackedModes = decisionPackage?.actionModeDecision.stackedModes
            ?? surfaceGuide?.stackedModes
            ?? actionPermit.stackedModes
        let stackedModeNames = stackedModes.map(\.rawValue)
        let allowedDomains = decisionPackage?.actionPermit.allowedDomains
            ?? surfaceGuide?.boundary.allowedDomains
            ?? actionPermit.allowedDomains
        let blockedDomains = decisionPackage?.actionPermit.blockedDomains
            ?? surfaceGuide?.boundary.blockedDomains
            ?? actionPermit.blockedDomains
        let toolScope = surfaceGuide?.boundary.toolScope ?? actionPermit.toolScope
        let memoryScope = surfaceGuide?.boundary.memoryScope ?? actionPermit.memoryScope
        let delayType = decisionPackage?.delayReservation?.delayType
            ?? surfaceGuide?.delayReservation?.delayType
            ?? surfaceGuide?.delayWindow
            ?? actionPermit.delayWindow
        let substituteType = decisionPackage?.protectiveSubstitute?.substituteType
            ?? surfaceGuide?.protectiveSubstitute?.substituteType
            ?? riskCard.substituteType
        let sovereignHint = decisionPackage?.sovereignEscalationHint?.urgency
            ?? surfaceGuide?.sovereignEscalationHint?.urgency
            ?? riskCard.sovereignHintLevel
            ?? surfaceGuide?.boundary.escalationHintRef
            ?? actionPermit.escalationHintRef
        let assertionCeiling = surfaceGuide?.disclosure.assertionCeiling ?? actionPermit.assertionCeiling

        return DecisionEvolutionNarrativeFormattingSupport.joined([
            "L11 wind gate",
            "primary \(actionPermit.mode.rawValue)",
            stackedModeNames.isEmpty ? nil : "stacked \(Array(stackedModeNames.prefix(3)).joined(separator: ", "))",
            "assert \(assertionCeiling)",
            "tool \(toolScope)",
            "memory \(memoryScope)",
            surfaceGuide?.agency.requiresSecondCheck == true ? "second check" : nil,
            allowedDomains.isEmpty ? nil : "allow \(Array(allowedDomains.prefix(3)).joined(separator: ", "))",
            blockedDomains.isEmpty ? nil : "block \(Array(blockedDomains.prefix(3)).joined(separator: ", "))",
            delayType.map { "delay \($0)" },
            substituteType.map { "substitute \($0)" },
            sovereignHint.map { "sovereign \($0)" }
        ].compactMap { $0 }).evolutionTrimmedNonEmpty
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
        let verdictDetail = sovereignVerdictLevelID.map { "verdict \($0)" }
        let tokenScopes = sovereignTokenScopeIDs
        let warrantScopes = sovereignWarrantScopeIDs
        let lockDetail = sovereignLockScopeID.map { "lock \($0)" }
        let quarantineZones = sovereignQuarantineZoneIDs
        let auditDetail = (sovereignAuditRuleIDs.first ?? sovereignAuditEntryID).map {
            "audit \($0)"
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
            warrantScopes.isEmpty ? nil : "warrants \(Array(warrantScopes.prefix(3)).joined(separator: ", "))",
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
            windGateLine: factsBundle.windGateLine ?? replayCheckpointWindGateLine,
            layerStackLines: factsBundle.layerStackLines
        )
    }

    var sessionCheckpointFacts: DecisionEvolutionSessionCheckpointFacts {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()
        let foldedLung = DecisionFoldedLungCoordinator.snapshot(for: self)
        let decisionPackage = riskDecisionPackage
        let resolvedProtectiveSurfaceMode = protectiveSurfaceMode?.rawValue ?? actionPermit.mode.rawValue
        let usesProtectiveSurfaceGuidance = hasProtectiveSurfaceGuidance
        let activeKillSwitches = runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKillSwitches = runtimeTrace.recommendedKillSwitches.map(\.rawValue)
        let stackedModes = (decisionPackage?.actionModeDecision.stackedModes ?? actionPermit.stackedModes)
            .map(\.rawValue)
        let allowedDomains = decisionPackage?.actionPermit.allowedDomains ?? actionPermit.allowedDomains
        let blockedDomains = decisionPackage?.actionPermit.blockedDomains ?? actionPermit.blockedDomains
        let delayType = decisionPackage?.delayReservation?.delayType
            ?? actionPermit.delayWindow
            ?? riskCard.delayType
        let substituteType = decisionPackage?.protectiveSubstitute?.substituteType
            ?? riskCard.substituteType
        let sovereignHintLevel = decisionPackage?.sovereignEscalationHint?.urgency
            ?? actionPermit.escalationHintRef
            ?? riskCard.sovereignHintLevel
        let openTaskLines = DecisionEvolutionEBrainPresentationSupport.checkpointOpenTaskLines(
            reviewDirectiveLine: primaryReviewDirectiveLine,
            firstTicketSummary: updateTickets.first?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            protectivePermitMode: resolvedProtectiveSurfaceMode,
            isProtective: usesProtectiveSurfaceGuidance
        )

        var eBrainAnchor = DecisionSessionCheckpointEBrainAnchor(
            sessionID: runtimeTrace.sessionID,
            thoughtFoldChecksum: String(thoughtFold.checksum.prefix(12)),
            riskLevel: riskCard.riskLevel.rawValue,
            permitMode: actionPermit.mode.rawValue,
            hostGatePercent: Int((hostGateValue * 100).rounded()),
            reviewDirectiveLine: primaryReviewDirectiveLine,
            riskFactorsLine: factsBundle.riskFactorsLine,
            reasonCodesLine: factsBundle.reasonCodesLine,
            courtLine: factsBundle.courtLine,
            versionTreeLine: factsBundle.versionTreeLine,
            retractionLine: factsBundle.retractionLine,
            stackedModes: stackedModes,
            assertionCeiling: decisionPackage?.actionPermit.assertionCeiling ?? actionPermit.assertionCeiling,
            allowedDomains: allowedDomains,
            blockedDomains: blockedDomains,
            delayType: delayType,
            substituteType: substituteType,
            sovereignHintLevel: sovereignHintLevel,
            sovereignVerdictLine: factsBundle.sovereignVerdictLine,
            sovereignAuthorityLine: factsBundle.sovereignAuthorityLine,
            sovereignAuditLine: factsBundle.sovereignAuditLine,
            morphGraph: foldedLung.morphGraph,
            hotColdMap: foldedLung.hotColdMap,
            precisionProfile: foldedLung.precisionProfile,
            lungState: foldedLung.lungState,
            thermalExchange: foldedLung.thermalExchange,
            breathScheduler: foldedLung.breathScheduler,
            integrityWeave: foldedLung.integrityWeave,
            organPackages: foldedLung.organPackages,
            organDeltaPlan: foldedLung.organDeltaPlan,
            resumeFrame: foldedLung.resumeFrame,
            rollbackAnchor: foldedLung.rollbackAnchor,
            sovereignBridgeResult: foldedLung.sovereignBridgeResult
        )
        eBrainAnchor.presenceLine = factsBundle.sessionCheckpointPresenceFactLine()

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
            shouldUseReviewMode: usesProtectiveSurfaceGuidance,
            eBrainAnchor: eBrainAnchor
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
            courtLine: courtLine,
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
            governanceLine: governanceLine,
            versionTreeLine: replaySummary.versionTreeLine,
            retractionLine: replaySummary.retractionLine,
            activeKillSwitchesLine: replaySummary.activeKillSwitchesLine,
            killSwitchesLine: replaySummary.killSwitchesLine,
            morphLine: replaySummary.morphLine,
            hotColdLine: replaySummary.hotColdLine,
            precisionLine: replaySummary.precisionLine,
            organPackageLine: replaySummary.organPackageLine,
            lungLine: replaySummary.lungLine,
            organDeltaLine: replaySummary.organDeltaLine,
            thermalExchangeLine: replaySummary.thermalExchangeLine,
            schedulerLine: replaySummary.schedulerLine,
            integrityWeaveLine: replaySummary.integrityWeaveLine,
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
