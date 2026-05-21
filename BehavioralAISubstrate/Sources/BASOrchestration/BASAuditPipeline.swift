// MARK: - BASAuditPipeline
// chapter 八百十五 / M2726-M2730 — audit-pipeline composition root
//
// Convenience composition seam that bundles the 4 chapters
// 七百九十八 → 八百一 recorders + their store conformers into a
// single per-turn entry point。 Lets hosts opt into the FULL
// audit pipeline with one struct instead of wiring 4 separate
// recorder calls per turn。
//
// ## Doctrine
//
// 「依旧 不删除 只 comment」 — the 4 recorders are not replaced。
// `BASAuditPipeline` is a thin orchestrator that DELEGATES to
// the individual recorders。 Hosts that want fine-grained
// control still call them directly。
//
// ADR-014 OPT-IN — the pipeline is opt-in。 Substrate default
// behavior is unchanged。
//
// ## What this saves
//
// Without pipeline,a host wires:
//
//   let presenceStore = ...
//   let unknownStore  = ...
//   let contradictionStore = ...
//   let atomStore = ...
//   let versionStore = ...
//   let _ = try await BASRoutedPresenceFusion.fuseAndRecord(...)
//   let _ = try await BASRoutedMirrorBladeRecording.recordUnknownSet(...)
//   let _ = try await BASRoutedMirrorBladeRecording.recordContradictions(...)
//   let _ = try await BASRoutedAtomLifecycleRecording.recordTransition(...)
//   let _ = try await BASRoutedHostConstitutionRecording.recordVersion(...)
//
// With pipeline:
//
//   let pipeline = BASAuditPipeline(stores: ..., ...)
//   try await pipeline.recordTurn(input: turnInput)
//
// The pipeline takes responsibility for routing each part of
// the input to the right recorder + store。 Errors propagate
// up — there is NO partial-success semantic across stores
// (e.g。 if the L7 write fails after L6 succeeded,callers
// see the throw + must handle store-level consistency
// themselves)。

import Foundation
import CryptoKit
import BASMemory
import BASSovereign

public struct BASAuditPipeline: Sendable {

    // MARK: - Stores (host-supplied)

    public let presenceStore: BASPresenceObservationStore
    public let unknownStore: BASUnknownLedgerStore
    public let contradictionStore: BASContradictionLedgerStore
    public let atomLifecycleStore: BASAtomLifecycleStore
    public let versionTreeStore: BASHostConstitutionVersionTreeStore

    public init(
        presenceStore: BASPresenceObservationStore,
        unknownStore: BASUnknownLedgerStore,
        contradictionStore: BASContradictionLedgerStore,
        atomLifecycleStore: BASAtomLifecycleStore,
        versionTreeStore: BASHostConstitutionVersionTreeStore
    ) {
        self.presenceStore = presenceStore
        self.unknownStore = unknownStore
        self.contradictionStore = contradictionStore
        self.atomLifecycleStore = atomLifecycleStore
        self.versionTreeStore = versionTreeStore
    }

    // MARK: - Per-turn input

    /// One turn's worth of audit input。 Every field is OPTIONAL
    /// — hosts only fill the parts that make sense for the turn。
    /// E.g。 a「pure thought」 turn may have presence + unknowns
    /// but no atom transition;a「commit constitution edit」 turn
    /// may have only versionRecord。
    public struct PerTurnInput: Sendable {
        public var sessionID: String
        public var turnID: String
        public var nowMs: Int64
        public var eventIDPrefix: String

        public var observations: [BASChannelObservationInput]?
        public var unknownSet: BASUnknownSet?
        public var contradictions: [BASContradictionRecord]?
        public var atomTransition: AtomTransitionInput?
        public var versionRecord: VersionRecordInput?

        public init(
            sessionID: String,
            turnID: String,
            nowMs: Int64,
            eventIDPrefix: String,
            observations: [BASChannelObservationInput]? = nil,
            unknownSet: BASUnknownSet? = nil,
            contradictions: [BASContradictionRecord]? = nil,
            atomTransition: AtomTransitionInput? = nil,
            versionRecord: VersionRecordInput? = nil
        ) {
            self.sessionID = sessionID
            self.turnID = turnID
            self.nowMs = nowMs
            self.eventIDPrefix = eventIDPrefix
            self.observations = observations
            self.unknownSet = unknownSet
            self.contradictions = contradictions
            self.atomTransition = atomTransition
            self.versionRecord = versionRecord
        }
    }

    public struct AtomTransitionInput: Sendable {
        public let atomID: String
        public let fromPhaseByte: UInt8
        public let toPhaseByte: UInt8
        public let actionByte: UInt8
        public let outcome: Int32
        public let actorRef: String?
        public init(
            atomID: String,
            fromPhaseByte: UInt8,
            toPhaseByte: UInt8,
            actionByte: UInt8,
            outcome: Int32,
            actorRef: String? = nil
        ) {
            self.atomID = atomID
            self.fromPhaseByte = fromPhaseByte
            self.toPhaseByte = toPhaseByte
            self.actionByte = actionByte
            self.outcome = outcome
            self.actorRef = actorRef
        }
    }

    public struct VersionRecordInput: Sendable {
        public let versionID: String
        public let vaultID: String
        public let parentVersionID: String?
        public let canonicalBytes: Data
        public let isRollbackPoint: Bool
        public let mergedFromVersionIDs: [String]?
        public init(
            versionID: String,
            vaultID: String,
            parentVersionID: String? = nil,
            canonicalBytes: Data,
            isRollbackPoint: Bool = false,
            mergedFromVersionIDs: [String]? = nil
        ) {
            self.versionID = versionID
            self.vaultID = vaultID
            self.parentVersionID = parentVersionID
            self.canonicalBytes = canonicalBytes
            self.isRollbackPoint = isRollbackPoint
            self.mergedFromVersionIDs = mergedFromVersionIDs
        }
    }

    // MARK: - Per-turn recording

    /// Returned by `recordTurn`。 Each field is non-nil iff the
    /// corresponding input was supplied and the recorder ran。
    public struct PerTurnOutput: Sendable, Equatable {
        public var fusedPresence: Double?
        public var unknownRecords: [BASUnknownLedgerRecord]?
        public var contradictionRecords: [BASContradictionLedgerRecord]?
        public var atomEvent: BASAtomLifecycleEvent?
        public var versionRecord: BASHostConstitutionVersionRecord?
    }

    /// Route the per-turn input through all 4 recorders。 The
    /// order is fixed:presence → unknowns → contradictions →
    /// atom → version (deterministic for replay)。 Errors
    /// propagate immediately — there is no automatic rollback
    /// across stores。 Hosts that need cross-store atomicity
    /// must implement their own checkpoint/rollback above this
    /// layer。
    public func recordTurn(
        input: PerTurnInput
    ) async throws -> PerTurnOutput {
        var output = PerTurnOutput()

        // L6 presence
        if let observations = input.observations,
           !observations.isEmpty {
            output.fusedPresence = try await BASRoutedPresenceFusion
                .fuseAndRecord(
                    observations: observations,
                    sessionID: input.sessionID,
                    turnID: input.turnID,
                    store: presenceStore,
                    eventIDPrefix: "\(input.eventIDPrefix)-p",
                    nowMs: input.nowMs)
        }

        // L7 unknowns
        if let unknownSet = input.unknownSet,
           unknownSet.hasAny {
            output.unknownRecords = try await BASRoutedMirrorBladeRecording
                .recordUnknownSet(
                    unknownSet,
                    sessionID: input.sessionID,
                    turnID: input.turnID,
                    store: unknownStore,
                    eventIDPrefix: "\(input.eventIDPrefix)-u",
                    nowMs: input.nowMs)
        }

        // L7 contradictions
        if let contradictions = input.contradictions,
           !contradictions.isEmpty {
            output.contradictionRecords = try await BASRoutedMirrorBladeRecording
                .recordContradictions(
                    contradictions,
                    sessionID: input.sessionID,
                    turnID: input.turnID,
                    store: contradictionStore,
                    eventIDPrefix: "\(input.eventIDPrefix)-c",
                    nowMs: input.nowMs)
        }

        // L8 atom lifecycle
        if let atom = input.atomTransition {
            output.atomEvent = try await BASRoutedAtomLifecycleRecording
                .recordTransition(
                    eventID: "\(input.eventIDPrefix)-a",
                    atomID: atom.atomID,
                    sessionID: input.sessionID,
                    fromPhaseByte: atom.fromPhaseByte,
                    toPhaseByte: atom.toPhaseByte,
                    actionByte: atom.actionByte,
                    outcome: atom.outcome,
                    store: atomLifecycleStore,
                    nowMs: input.nowMs,
                    actorRef: atom.actorRef)
        }

        // L5 constitution version
        if let version = input.versionRecord {
            output.versionRecord = try await BASRoutedHostConstitutionRecording
                .recordVersion(
                    versionID: version.versionID,
                    vaultID: version.vaultID,
                    parentVersionID: version.parentVersionID,
                    canonicalBytes: version.canonicalBytes,
                    createdAtMs: input.nowMs,
                    isRollbackPoint: version.isRollbackPoint,
                    mergedFromVersionIDs: version.mergedFromVersionIDs,
                    store: versionTreeStore)
        }

        return output
    }
}
