import Foundation
import BASHostKit

struct DecisionEvolutionEBrainFactsBundle: Equatable, Sendable {
    let sourceDescriptor: DecisionEvolutionSourceDescriptor
    let summaryLine: String
    let runtimeSummaryLine: String
    let brainSummaryLine: String
    let budgetLine: String?
    let pressureLine: String?
    let taskLine: String?
    let auditLine: String?
    let activeKillSwitchesLine: String?
    let killSwitchesLine: String?
}

struct DecisionEvolutionReplayCheckpointFacts: Equatable, Sendable {
    let budgetLine: String
    let pressureLine: String
    let taskLine: String?
}

struct DecisionEvolutionSessionCheckpointFacts: Equatable, Sendable {
    let budgetConstraintLine: String
    let routeConstraintLine: String
    let decisionFactLines: [String]
    let pressureFactLine: String?
    let auditFactLine: String?
    let activeKillSwitchesFactLine: String?
    let recommendedKillSwitchesFactLine: String?
    let openTaskLines: [String]
    let currentScope: [String]
    let shouldUseReviewMode: Bool
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
        "Review protective path:"
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

    static func riskPermitLine(
        riskLevel: String,
        permitMode: String
    ) -> String {
        "\(displayToken(riskLevel)) → \(displayToken(permitMode))"
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
            taskType.replacingOccurrences(of: "_", with: " ")
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
        firstTicketSummary: String?,
        protectivePermitMode: String,
        isProtective: Bool
    ) -> [String] {
        var lines: [String] = []

        if let firstTicketSummary, firstTicketSummary.isEmpty == false {
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
    let riskFactorsLine: String?
    let reasonCodesLine: String?
    let ticketSummary: String?
}

extension DecisionEvolutionEBrainFactsBundle {
    func sessionCheckpointPressureFactLine(prefix: String = "eBrain pressure:") -> String? {
        guard let pressureLine else { return nil }
        return "\(prefix) \(pressureLine.droppingKnownPrefix("Pressure "))"
    }

    var consoleRuntimeSummaryAdditions: [String] {
        [runtimeSummaryLine, pressureLine]
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
            auditLine,
            activeKillSwitchesLine,
            killSwitchesLine
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
            "decode \(budgetFrame.maxDecodeTokens)"
        ])
    }

    var replayCheckpointPressureLine: String {
        DecisionEvolutionNarrativeFormattingSupport.joined([
            "Pressure latency \(runtimeTrace.latencyBreakdownMs.values.reduce(0, +))/\(deviceState.latencyBudgetMs)ms",
            "power \(Int((runtimeTrace.powerEstimate * 100).rounded()))%",
            "cache \(Int((runtimeTrace.cacheHitRate * 100).rounded()))%",
            "thermal \((runtimeTrace.thermalTrace.isEmpty ? [deviceState.thermalLevel.rawValue] : runtimeTrace.thermalTrace).joined(separator: " -> "))"
        ])
    }

    var replayCheckpointTaskLine: String? {
        updateTickets.first.map { "Review: \($0.summary)" }
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
            hostText: DecisionEvolutionNarrativeFormattingSupport.joined([
                "Host gate \(Int((hostGateValue * 100).rounded()))%",
                "Fold \(thoughtFold.checksum.prefix(12))",
                "Device \(deviceState.thermalLevel.rawValue)/\(deviceState.memoryFreeMB)MB"
            ]),
            replayText: DecisionEvolutionNarrativeFormattingSupport.joined([
                "Replay session \(runtimeTrace.sessionID)",
                "Recorded \(runtimeTrace.recordedAt.formatted(date: .abbreviated, time: .shortened))"
            ]),
            auditLines: Array(runtimeTrace.guardrailFindings.prefix(4)).map { finding in
                "• \(finding.layerID) \(finding.code): \(finding.summary)"
            },
            activeKillSwitchesLine: DecisionEvolutionKillSwitchPresentationSupport.activeLine(
                killSwitches: activeKillSwitches
            ),
            recommendedKillSwitchesLine: DecisionEvolutionKillSwitchPresentationSupport.recommendedLine(
                killSwitches: recommendedKillSwitches
            ),
            riskFactorsLine: DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Factors",
                values: riskCard.factors
            ),
            reasonCodesLine: DecisionEvolutionNarrativeFormattingSupport.labeledLine(
                prefix: "Reason codes",
                values: actionPermit.reasonCodes
            ),
            ticketSummary: updateTickets.first?.summary
        )
    }

    var replayCheckpointFacts: DecisionEvolutionReplayCheckpointFacts {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()
        return DecisionEvolutionReplayCheckpointFacts(
            budgetLine: replayCheckpointBudgetLine,
            pressureLine: factsBundle.pressureLine ?? replayCheckpointPressureLine,
            taskLine: replayCheckpointTaskLine
        )
    }

    var sessionCheckpointFacts: DecisionEvolutionSessionCheckpointFacts {
        let factsBundle = DeveloperDecisionReplayEBrainSummary(turn: self).factsBundle()
        let activeKillSwitches = runtimeTrace.activeKillSwitches.map(\.rawValue)
        let recommendedKillSwitches = runtimeTrace.recommendedKillSwitches.map(\.rawValue)
        let openTaskLines = DecisionEvolutionEBrainPresentationSupport.checkpointOpenTaskLines(
            firstTicketSummary: updateTickets.first?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            protectivePermitMode: actionPermit.mode.rawValue,
            isProtective: actionPermit.mode.isProtective
        )

        return DecisionEvolutionSessionCheckpointFacts(
            budgetConstraintLine: DecisionEvolutionEBrainPresentationSupport.checkpointBudgetConstraintLine(
                runMode: budgetFrame.runMode.rawValue,
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
            shouldUseReviewMode: actionPermit.mode.isProtective
        )
    }

    private func readableReplayRunModeTitle(_ runMode: BASEBrainRunMode) -> String {
        switch runMode {
        case .guarded:
            return "GUARDED"
        default:
            return runMode.rawValue.uppercased()
        }
    }
}

extension DecisionEvolutionSessionCheckpointFacts {
    func applied(
        to draft: DecisionSessionCheckpointDraft
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
            budgetLine: replaySummary.budgetLine,
            pressureLine: replaySummary.pressureLine,
            taskLine: replaySummary.taskLine,
            auditLine: replaySummary.auditLine,
            activeKillSwitchesLine: replaySummary.activeKillSwitchesLine,
            killSwitchesLine: replaySummary.killSwitchesLine
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
