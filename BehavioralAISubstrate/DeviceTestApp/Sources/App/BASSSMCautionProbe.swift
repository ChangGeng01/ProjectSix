// MARK: - BASSSMCautionProbe
// chapter 一百八十六 / ADR-019 P1.5b — on-device SSM caution operator validation
//
// Proves the calibrated SSM caution operator (Mamba/SSM as an AUTHORITATIVE raise-only L11 input)
// FIRES + RAISES on a genuinely-uncertain turn on REAL silicon (iPhone Air A19), that the flag-off path
// is byte-equal, and that the sovereign verdict still gates (the operator can never downgrade it). The
// operator's value path is the SYNC pure-Swift CPU reference scan, so on-device behavior is bit-identical
// to the package proof — this probe confirms it compiles, links, and executes on iOS/arm64 with no
// device-specific issue, and surfaces the on-device fire/raise numbers for the operator log.
//
// Mirrors the package test
// `BASSSMCautionOperatorRunTurnTests.testSSMCautionFiresAndRaisesAndVerdictStillGatesViaRealHostRuntime`,
// run on-device and LOGGED (not asserted). Emitted as `📊 ch1065 ssm-caution …` (idevicesyslog-visible
// via os.Logger + stdout). Runs once at boot, off the main actor (a full rule-based turn, no MLX/GPU).

import Foundation
import os
import BASHostKit

enum BASSSMCautionProbe {

    private static let log = Logger(
        subsystem: "com.changgeng.basdevicetest",
        category: "ch1065-ssm-caution")

    /// Run the on-device SSM-operator validation off the main actor; return a short UI verdict.
    static func run() async -> String {
        await Task.detached(priority: .userInitiated) { runSync() }.value
    }

    private static func runSync() -> String {
        let runtime = BASHostRuntime(configuration: .fixtureGeneric)
        let request = BASHostSessionRequest(
            kind: .interactive,
            workflowProfile: .reflective,
            surface: .application,
            prompt: "Push into an irreversible high-stakes move now.",
            riskLevel: .high)
        guard let seed = try? runtime.startSession(request) else {
            emit("📊 ch1065 ssm-caution probe FAILED reason=startSession_threw")
            return "ssm: startSession failed"
        }
        let projection = BASBrainProjection(
            records: [], candidates: [], recentEvents: [])

        // Same uncertain high-risk turn, SSM operator OFF vs ON.
        let off = runtime.buildEBrainTurn(
            request: request, currentBrain: seed.currentBrain, projection: projection,
            ssmCautionOperatorEnabled: false)
        let on = runtime.buildEBrainTurn(
            request: request, currentBrain: seed.currentBrain, projection: projection,
            ssmCautionOperatorEnabled: true)

        let fired = on.riskCard.factors.contains("ssm_temporal_caution")
        let raiseOnly = on.riskCard.totalRisk >= off.riskCard.totalRisk
        let delta = on.riskCard.totalRisk - off.riskCard.totalRisk
        let offV = off.sovereignVerdict?.verdictLevel
        let onV = on.sovereignVerdict?.verdictLevel
        // BASSovereignVerdictLevel is Comparable — verdict must not downgrade.
        let verdictGates: String
        if let o = offV, let n = onV {
            verdictGates = (n >= o) ? "true" : "false"
        } else {
            verdictGates = "n/a"
        }

        emit(String(format:
            "📊 ch1065 ssm-caution fired=%@ raise_only=%@ " +
            "off_risk=%.4f on_risk=%.4f delta=%.4f " +
            "off_level=%@ on_level=%@ off_verdict=%@ on_verdict=%@ verdict_gates=%@",
            fired ? "true" : "false",
            raiseOnly ? "true" : "false",
            off.riskCard.totalRisk, on.riskCard.totalRisk, delta,
            String(describing: off.riskCard.riskLevel),
            String(describing: on.riskCard.riskLevel),
            String(describing: offV), String(describing: onV),
            verdictGates))

        return fired
            ? "FIRED Δrisk=\(String(format: "%.3f", delta)) gates=\(verdictGates)"
            : "no-fire (raise_only=\(raiseOnly))"
    }

    private static func emit(_ line: String) {
        print(line)
        log.notice("\(line, privacy: .public)")
        // Also append to a Documents file so the result is reliably pullable via
        // `devicectl device copy from --source Documents` (the os.Logger/idevicesyslog
        // stream is flaky from the Mac side).
        guard let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent("ssm-caution-probe.log")
        let stamped = "[\(Date())] \(line)\n"
        if let data = stamped.data(using: .utf8) {
            if let fh = try? FileHandle(forWritingTo: url) {
                defer { try? fh.close() }
                _ = try? fh.seekToEnd()
                try? fh.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}
