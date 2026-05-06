// MARK: - EBrainL3L12RenderingCore — chapter 二百八十 / M767
//
// Phase Alpha 第六刀(final cut):从 EBrainCognitionPlaneCore.swift
// 抽出 L3 whitepaper §6 alias + L12 whitepaper §5 rendering
// cluster — 让 god file 从 ~690 LOC 收口到 ≤30 LOC (仅 imports +
// extraction comment markers)。chapter 二百七十五 始的 god file
// deconstruction Phase Alpha 全完。
//
// 本 file 抽出的 types / extensions:
//   - extension `BASThoughtFold.hostModSummary` (M108 L3 §6
//     `host_mod_summary` whitepaper-literal alias forwarding to
//     `hostEffectSummary`)
//   - L12 rendered guide quad: `BASRenderedBoundaryGuide` /
//     `BASRenderedAgencyGuide` / `BASRenderedDisclosureGuide` /
//     `BASRenderedSurfaceGuide`
//   - L12 §5 surface vocab: `BASOutputSurfaceType` (8-case) /
//     `BASBoundaryScriptType` (6-case)
//   - L12 §5 whitepaper-parity 13 typed renders:
//     `BASRenderFrame` (§5.1) / `BASOutputSurface` (§5.2) /
//     `BASToneWeaveProfile` (§5.3) / `BASForceCurve` (§5.4) /
//     `BASMirrorResponse` (§5.5) / `BASBoundaryScript` (§5.6) /
//     `BASComparePanel` (§5.7) / `BASStepBundle` (§5.8) /
//     `BASDelayPacket` (§5.9) / `BASAgencyHandle` (§5.11) /
//     `BASDisclosureProfile` (§5.12) / `BASSilentStub` (§5.13) /
//     `BASRenderedOutput` (legacy whitepaper-bridge composer)
//
// **0 behavior change**:types / extension literal-identical to
// pre-extraction versions。Module DAG 不变(BASOrchestration
// internal split,仍可被同 module 其他 file 引用,无需 import)。
//
// Doctrine pins:
//   - 不变量 #1 / #2 / #3 全保:纯 file org 重构
//   - 红线 7 watcher hint only:render frame 是 surface composition
//     不是 verdict 决策
//   - chapter 二百十一 single-source-of-truth:每 type 仍只 owned
//     by one file (从原 god file 移到此 file)
//   - chapter 二百一(架构 guardrail)+ chapter 一百八十五
//     anti-magic-number doctrine:全保
//   - L12 whitepaper §5 13/13 parity 不变:M117 ship state 完整
//
// Dependencies (cross-module):
//   - `BASActionPermitMode` / `BASDelayReservation` /
//     `BASProtectiveSubstitute` / `BASSovereignEscalationHint`
//     来自 BASPolicy
//   - `BASSchemaVersioned` 来自 BASRuntimeCore
//   - `BASAgencyReservationMode` / `BASMirrorMode` /
//     `BASThoughtFold` 同 BASOrchestration module
//     (chapter 二百七十七 / chapter 二百七十九 抽出 file)

import Foundation
import BASPolicy
import BASRuntimeCore

// MARK: - M108 L3 whitepaper parity alias
//
// L3 whitepaper §6 ThoughtFold spec names the "host modulation
// summary" field `host_mod_summary`; the substrate implementation
// uses `hostEffectSummary` — semantically identical but a literal
// whitepaper-↔-code audit would flag it as a naming drift.
// `hostModSummary` is a zero-cost computed-property alias
// forwarding to `hostEffectSummary`; both names round-trip to the
// same storage so existing Codable payloads and 20+ production
// call sites stay byte-for-byte identical.
//
// Same approach as `.empty` baselines (M106 / M107): expose the
// whitepaper-literal name through a read-only computed surface
// without touching stored state. When a future schema bump (v1.8.0)
// is warranted, the stored property can be renamed and this alias
// retained as a deprecated-on-read helper.
extension BASThoughtFold {
    /// L3 whitepaper §6 `host_mod_summary` literal alias. Returns
    /// the same value as `hostEffectSummary`; they are the same
    /// semantic field under two naming conventions (internal
    /// "effect" vs whitepaper "mod"). Writable for symmetry — the
    /// setter forwards to the canonical stored property.
    public var hostModSummary: String {
        get { hostEffectSummary }
        set { hostEffectSummary = newValue }
    }
}

public struct BASRenderedBoundaryGuide: Codable, Equatable, Sendable {
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    public var toolScope: String
    public var memoryScope: String
    public var escalationHintRef: String?

    public init(
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        toolScope: String,
        memoryScope: String,
        escalationHintRef: String? = nil
    ) {
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.toolScope = toolScope
        self.memoryScope = memoryScope
        self.escalationHintRef = escalationHintRef
    }
}

public struct BASRenderedAgencyGuide: Codable, Equatable, Sendable {
    public var requiresCompare: Bool
    public var requiresSecondCheck: Bool
    public var delayAvailable: Bool
    public var chooseLaterAllowed: Bool
    public var prefersDraftOnly: Bool
    public var localOnlyPreferred: Bool
    public var reservationMode: BASAgencyReservationMode?
    public var reservationReasons: [String]?

    public init(
        requiresCompare: Bool,
        requiresSecondCheck: Bool,
        delayAvailable: Bool,
        chooseLaterAllowed: Bool,
        prefersDraftOnly: Bool,
        localOnlyPreferred: Bool,
        reservationMode: BASAgencyReservationMode? = nil,
        reservationReasons: [String]? = nil
    ) {
        self.requiresCompare = requiresCompare
        self.requiresSecondCheck = requiresSecondCheck
        self.delayAvailable = delayAvailable
        self.chooseLaterAllowed = chooseLaterAllowed
        self.prefersDraftOnly = prefersDraftOnly
        self.localOnlyPreferred = localOnlyPreferred
        self.reservationMode = reservationMode
        self.reservationReasons = reservationReasons
    }
}

public struct BASRenderedDisclosureGuide: Codable, Equatable, Sendable {
    public var assertionCeiling: String
    public var explanationCodes: [String]
    public var uncertaintyVisible: Bool
    public var requiredDisclosures: [String]?
    public var unresolvedCosts: [String]?
    public var remandTargets: [String]?

    public init(
        assertionCeiling: String,
        explanationCodes: [String] = [],
        uncertaintyVisible: Bool,
        requiredDisclosures: [String]? = nil,
        unresolvedCosts: [String]? = nil,
        remandTargets: [String]? = nil
    ) {
        self.assertionCeiling = assertionCeiling
        self.explanationCodes = explanationCodes
        self.uncertaintyVisible = uncertaintyVisible
        self.requiredDisclosures = requiredDisclosures
        self.unresolvedCosts = unresolvedCosts
        self.remandTargets = remandTargets
    }
}

public struct BASRenderedSurfaceGuide: Codable, Equatable, Sendable {
    public var stackedModes: [BASActionPermitMode]
    public var tonePolicy: String
    public var templatePolicy: String
    public var outputLengthCap: Int
    public var boundary: BASRenderedBoundaryGuide
    public var agency: BASRenderedAgencyGuide
    public var disclosure: BASRenderedDisclosureGuide
    public var delayWindow: String?
    public var delayReservation: BASDelayReservation?
    public var protectiveSubstitute: BASProtectiveSubstitute?
    public var sovereignEscalationHint: BASSovereignEscalationHint?

    public init(
        stackedModes: [BASActionPermitMode] = [],
        tonePolicy: String,
        templatePolicy: String,
        outputLengthCap: Int,
        boundary: BASRenderedBoundaryGuide,
        agency: BASRenderedAgencyGuide,
        disclosure: BASRenderedDisclosureGuide,
        delayWindow: String? = nil,
        delayReservation: BASDelayReservation? = nil,
        protectiveSubstitute: BASProtectiveSubstitute? = nil,
        sovereignEscalationHint: BASSovereignEscalationHint? = nil
    ) {
        self.stackedModes = stackedModes
        self.tonePolicy = tonePolicy
        self.templatePolicy = templatePolicy
        self.outputLengthCap = max(0, outputLengthCap)
        self.boundary = boundary
        self.agency = agency
        self.disclosure = disclosure
        self.delayWindow = delayWindow
        self.delayReservation = delayReservation
        self.protectiveSubstitute = protectiveSubstitute
        self.sovereignEscalationHint = sovereignEscalationHint
    }
}

// MARK: - M117 L12 whitepaper §5 parity

/// L12 whitepaper §5 `OutputSurface.surface_type` 8-case vocab.
/// Matches §5 exactly.
public enum BASOutputSurfaceType:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case answer
    case mirror
    case comparePanel
    case draftShell
    case localStep
    case boundaryScript
    case delayPacket
    case silentStub
}

// Note: L12 whitepaper §5 `MirrorResponse.mirror_mode` vocab
// matches the existing `BASMirrorMode` enum (silent / soft / hard)
// extracted to `EBrainL7MirrorBladeDecomposeCore.swift` (chapter
// 二百七十九). Reusing that enum below.

/// L12 whitepaper §5 `BoundaryScript.script_type` 6-case vocab.
public enum BASBoundaryScriptType:
    String, Codable, Sendable, Equatable, Hashable, CaseIterable
{
    case block
    case delay
    case localOnly
    case draftOnly
    case noEscalation
    case noTool
}

/// L12 whitepaper §5.1 `RenderFrame` — the aggregator that binds
/// every rendering decision for a turn (merged choice + permit +
/// agency + host style + situation + mirror + substitute +
/// sovereign surface + output surface + tone + force curve +
/// disclosure). All refs are String IDs matching whitepaper
/// literal shape.
public struct BASRenderFrame: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var frameID: String
    public var mergedChoiceRef: String?
    public var actionPermitRef: String?
    public var agencyReservationRef: String?
    public var hostStyleRef: String?
    public var situationRef: String?
    public var mirrorRef: String?
    public var substituteRef: String?
    public var sovereignSurfaceRef: String?
    public var outputSurfaceRef: String?
    public var toneProfileRef: String?
    public var forceCurveRef: String?
    public var disclosureProfileRef: String?

    public init(
        schemaVersion: String
            = BASRenderFrame.currentSchemaVersion,
        frameID: String,
        mergedChoiceRef: String? = nil,
        actionPermitRef: String? = nil,
        agencyReservationRef: String? = nil,
        hostStyleRef: String? = nil,
        situationRef: String? = nil,
        mirrorRef: String? = nil,
        substituteRef: String? = nil,
        sovereignSurfaceRef: String? = nil,
        outputSurfaceRef: String? = nil,
        toneProfileRef: String? = nil,
        forceCurveRef: String? = nil,
        disclosureProfileRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        let trim: (String) -> String = {
            $0.trimmingCharacters(
                in: .whitespacesAndNewlines)
        }
        self.frameID = trim(frameID)
        self.mergedChoiceRef = mergedChoiceRef.map(trim)
        self.actionPermitRef = actionPermitRef.map(trim)
        self.agencyReservationRef =
            agencyReservationRef.map(trim)
        self.hostStyleRef = hostStyleRef.map(trim)
        self.situationRef = situationRef.map(trim)
        self.mirrorRef = mirrorRef.map(trim)
        self.substituteRef = substituteRef.map(trim)
        self.sovereignSurfaceRef =
            sovereignSurfaceRef.map(trim)
        self.outputSurfaceRef = outputSurfaceRef.map(trim)
        self.toneProfileRef = toneProfileRef.map(trim)
        self.forceCurveRef = forceCurveRef.map(trim)
        self.disclosureProfileRef =
            disclosureProfileRef.map(trim)
    }
}

/// L12 whitepaper §5.2 `OutputSurface`.
public struct BASOutputSurface: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var surfaceID: String
    public var surfaceType: BASOutputSurfaceType
    public var channel: String
    public var interactionDepth: String

    public init(
        schemaVersion: String
            = BASOutputSurface.currentSchemaVersion,
        surfaceID: String,
        surfaceType: BASOutputSurfaceType,
        channel: String,
        interactionDepth: String = "standard"
    ) {
        self.schemaVersion = schemaVersion
        self.surfaceID = surfaceID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.surfaceType = surfaceType
        self.channel = channel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.interactionDepth = interactionDepth
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// L12 whitepaper §5.3 `ToneProfile` — 8-axis tone quantification.
/// Named `BASToneWeaveProfile` (not `BASToneProfile`) to avoid
/// collision with the existing `BASToneProfile` enum (categorical
/// tone classification) in `BASRuntimeCore/AdaptiveRuntimeCore`.
/// The "Weave" prefix matches L12 §4.2 "Tone Weave Loom" organ.
public struct BASToneWeaveProfile: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var warmth: Double
    public var firmness: Double
    public var distance: Double
    public var density: Double
    public var pace: Double
    public var explicitness: Double
    public var authority: Double
    public var tenderness: Double

    public init(
        schemaVersion: String
            = BASToneWeaveProfile.currentSchemaVersion,
        warmth: Double = 0.5,
        firmness: Double = 0.5,
        distance: Double = 0.5,
        density: Double = 0.5,
        pace: Double = 0.5,
        explicitness: Double = 0.5,
        authority: Double = 0.5,
        tenderness: Double = 0.5
    ) {
        self.schemaVersion = schemaVersion
        self.warmth = min(1, max(0, warmth))
        self.firmness = min(1, max(0, firmness))
        self.distance = min(1, max(0, distance))
        self.density = min(1, max(0, density))
        self.pace = min(1, max(0, pace))
        self.explicitness = min(1, max(0, explicitness))
        self.authority = min(1, max(0, authority))
        self.tenderness = min(1, max(0, tenderness))
    }
}

/// L12 whitepaper §5.4 `ForceCurve`.
public struct BASForceCurve: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var openingForce: Double
    public var middleForce: Double
    public var closingForce: Double
    public var pausePoints: [String]
    public var emphasisNodes: [String]
    public var boundaryAnchorStrength: Double

    public init(
        schemaVersion: String
            = BASForceCurve.currentSchemaVersion,
        openingForce: Double = 0.5,
        middleForce: Double = 0.5,
        closingForce: Double = 0.5,
        pausePoints: [String] = [],
        emphasisNodes: [String] = [],
        boundaryAnchorStrength: Double = 0.5
    ) {
        self.schemaVersion = schemaVersion
        self.openingForce = min(1, max(0, openingForce))
        self.middleForce = min(1, max(0, middleForce))
        self.closingForce = min(1, max(0, closingForce))
        self.pausePoints = pausePoints
        self.emphasisNodes = emphasisNodes
        self.boundaryAnchorStrength = min(
            1, max(0, boundaryAnchorStrength))
    }
}

/// L12 whitepaper §5.5 `MirrorResponse`.
public struct BASMirrorResponse: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var responseID: String
    public var mirrorMode: BASMirrorMode
    public var summary: String
    public var calibrationPoints: [String]
    public var emotionalLoad: Double
    public var nonInductiveGuard: Bool

    public init(
        schemaVersion: String
            = BASMirrorResponse.currentSchemaVersion,
        responseID: String,
        mirrorMode: BASMirrorMode = .soft,
        summary: String = "",
        calibrationPoints: [String] = [],
        emotionalLoad: Double = 0,
        nonInductiveGuard: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.responseID = responseID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.mirrorMode = mirrorMode
        self.summary = summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.calibrationPoints = calibrationPoints
        self.emotionalLoad = min(1, max(0, emotionalLoad))
        self.nonInductiveGuard = nonInductiveGuard
    }
}

/// L12 whitepaper §5.6 `BoundaryScript`.
public struct BASBoundaryScript: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var scriptID: String
    public var scriptType: BASBoundaryScriptType
    public var wording: String
    public var firmnessLevel: Double
    public var dignityGuard: Bool
    public var substituteRef: String?

    public init(
        schemaVersion: String
            = BASBoundaryScript.currentSchemaVersion,
        scriptID: String,
        scriptType: BASBoundaryScriptType,
        wording: String = "",
        firmnessLevel: Double = 0.5,
        dignityGuard: Bool = true,
        substituteRef: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.scriptID = scriptID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.scriptType = scriptType
        self.wording = wording
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.firmnessLevel = min(1, max(0, firmnessLevel))
        self.dignityGuard = dignityGuard
        self.substituteRef = substituteRef?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// L12 whitepaper §5.7 `ComparePanel`.
public struct BASComparePanel: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var panelID: String
    public var options: [String]
    public var differences: [String]
    public var sacrifices: [String]
    public var reversiblePoints: [String]
    public var chooseLaterAllowed: Bool

    public init(
        schemaVersion: String
            = BASComparePanel.currentSchemaVersion,
        panelID: String,
        options: [String] = [],
        differences: [String] = [],
        sacrifices: [String] = [],
        reversiblePoints: [String] = [],
        chooseLaterAllowed: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.panelID = panelID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.options = options
        self.differences = differences
        self.sacrifices = sacrifices
        self.reversiblePoints = reversiblePoints
        self.chooseLaterAllowed = chooseLaterAllowed
    }
}

/// L12 whitepaper §5.8 `StepBundle`.
public struct BASStepBundle: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var bundleID: String
    public var microSteps: [String]
    public var localOnly: Bool
    public var editable: Bool
    public var confirmNodes: [String]

    public init(
        schemaVersion: String
            = BASStepBundle.currentSchemaVersion,
        bundleID: String,
        microSteps: [String] = [],
        localOnly: Bool = true,
        editable: Bool = true,
        confirmNodes: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.bundleID = bundleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.microSteps = microSteps
        self.localOnly = localOnly
        self.editable = editable
        self.confirmNodes = confirmNodes
    }
}

/// L12 whitepaper §5.9 `DelayPacket`.
public struct BASDelayPacket: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var packetID: String
    public var delayWindow: String
    public var rationale: String
    public var allowedIntermediateActions: [String]
    public var reentryHint: String

    public init(
        schemaVersion: String
            = BASDelayPacket.currentSchemaVersion,
        packetID: String,
        delayWindow: String = "",
        rationale: String = "",
        allowedIntermediateActions: [String] = [],
        reentryHint: String = ""
    ) {
        self.schemaVersion = schemaVersion
        self.packetID = packetID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.delayWindow = delayWindow
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.rationale = rationale
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.allowedIntermediateActions =
            allowedIntermediateActions
        self.reentryHint = reentryHint
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// L12 whitepaper §5.11 `AgencyHandle`.
public struct BASAgencyHandle: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var handleID: String
    public var compareEnabled: Bool
    public var delayEnabled: Bool
    public var secondCheckRequired: Bool
    public var chooseLaterAllowed: Bool
    public var userFinalSay: Bool

    public init(
        schemaVersion: String
            = BASAgencyHandle.currentSchemaVersion,
        handleID: String,
        compareEnabled: Bool = true,
        delayEnabled: Bool = true,
        secondCheckRequired: Bool = false,
        chooseLaterAllowed: Bool = true,
        userFinalSay: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.handleID = handleID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.compareEnabled = compareEnabled
        self.delayEnabled = delayEnabled
        self.secondCheckRequired = secondCheckRequired
        self.chooseLaterAllowed = chooseLaterAllowed
        self.userFinalSay = userFinalSay
    }
}

/// L12 whitepaper §5.12 `DisclosureProfile`.
public struct BASDisclosureProfile: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var profileID: String
    public var revealItems: [String]
    public var suppressItems: [String]
    public var uncertaintyVisible: Bool
    public var sovereignMinimalMode: Bool
    public var chainOfThoughtHidden: Bool

    public init(
        schemaVersion: String
            = BASDisclosureProfile.currentSchemaVersion,
        profileID: String,
        revealItems: [String] = [],
        suppressItems: [String] = [],
        uncertaintyVisible: Bool = true,
        sovereignMinimalMode: Bool = false,
        chainOfThoughtHidden: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.profileID = profileID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.revealItems = revealItems
        self.suppressItems = suppressItems
        self.uncertaintyVisible = uncertaintyVisible
        self.sovereignMinimalMode = sovereignMinimalMode
        self.chainOfThoughtHidden = chainOfThoughtHidden
    }
}

/// L12 whitepaper §5.13 `SilentStub`.
public struct BASSilentStub: BASSchemaVersioned,
    Hashable, Sendable
{
    public static let currentSchemaVersion = "1.0.0"

    public var schemaVersion: String
    public var stubID: String
    public var minimalText: String
    public var surfaceMode: String
    public var dignityGuard: Bool
    public var noExtraLeak: Bool

    public init(
        schemaVersion: String
            = BASSilentStub.currentSchemaVersion,
        stubID: String,
        minimalText: String = "",
        surfaceMode: String = "stub",
        dignityGuard: Bool = true,
        noExtraLeak: Bool = true
    ) {
        self.schemaVersion = schemaVersion
        self.stubID = stubID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.minimalText = minimalText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.surfaceMode = surfaceMode
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.dignityGuard = dignityGuard
        self.noExtraLeak = noExtraLeak
    }
}

public struct BASRenderedOutput: BASSchemaVersioned {
    public static let currentSchemaVersion = "1.1.0"

    public var schemaVersion: String
    public var mode: BASActionPermitMode
    public var headline: String
    public var body: String
    public var alternativeActions: [String]
    public var explanationCodes: [String]
    public var surfaceGuide: BASRenderedSurfaceGuide?

    public init(
        schemaVersion: String = BASRenderedOutput.currentSchemaVersion,
        mode: BASActionPermitMode,
        headline: String,
        body: String,
        alternativeActions: [String] = [],
        explanationCodes: [String] = [],
        surfaceGuide: BASRenderedSurfaceGuide? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.mode = mode
        self.headline = headline
        self.body = body
        self.alternativeActions = alternativeActions
        self.explanationCodes = explanationCodes
        self.surfaceGuide = surfaceGuide
    }
}
